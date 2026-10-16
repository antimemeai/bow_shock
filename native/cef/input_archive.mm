#import "input_archive.h"
#import "extraction_workspace.h"

namespace {
id Snapshot(id value) {
  if ([value isKindOfClass:NSString.class]) {
    NSString* string = value;
    BOOL valid = YES;
    for (NSUInteger i = 0; i < string.length; ++i) {
      unichar c = [string characterAtIndex:i];
      if (c >= 0xd800 && c <= 0xdbff) {
        if (i+1 >= string.length) { valid = NO; break; }
        unichar next = [string characterAtIndex:++i];
        if (next < 0xdc00 || next > 0xdfff) { valid = NO; break; }
      } else if (c >= 0xdc00 && c <= 0xdfff) { valid = NO; break; }
    }
    if (valid) return [string copy];
    NSMutableData* raw = [NSMutableData dataWithLength:string.length * sizeof(uint16_t)];
    auto* units = static_cast<uint16_t*>(raw.mutableBytes);
    for (NSUInteger i = 0; i < string.length; ++i) units[i] = CFSwapInt16HostToLittle([string characterAtIndex:i]);
    return @{@"oxcart_utf16le":[raw copy]};
  }
  if ([value isKindOfClass:NSArray.class]) {
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:[value count]];
    for (id item in value) [array addObject:Snapshot(item)];
    return [array copy];
  }
  if ([value isKindOfClass:NSDictionary.class]) {
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:[value count]];
    for (NSString* key in value) dict[[key copy]] = Snapshot(value[key]);
    return [dict copy];
  }
  return [value copy];
}
}
@implementation OXInputArchive {
  dispatch_queue_t _worker;
  dispatch_source_t _timer;
  NSMutableArray* _pending;
  uint64_t _sequence, _chunk;
  BOOL _closed, _storageFailed;
}
- (instancetype)initWithRootURL:(NSURL*)root metadata:(NSDictionary*)metadata {
  self = [super init]; if (!self) return nil;
  _recordingID = NSUUID.UUID.UUIDString;
  _directoryURL = [root URLByAppendingPathComponent:_recordingID isDirectory:YES];
  _pending = [NSMutableArray array];
  _worker = dispatch_queue_create("oxcart.input.archive",
      DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
  NSDictionary* session = @{@"format":@"oxcart.input-recording",@"version":@1,
      @"id":_recordingID,@"created_at":NSDate.date,@"metadata":Snapshot(metadata),
      @"clock_note":@"Native event uptime, DOM timestamps/time origin and receipt uptime are separate clocks. IPC receipt order is not causal order.",
      @"retention_note":@"All received events retained; chunks flush at 128 records or 250ms. A crash may lose the pending tail. No total cap or expiry."};
  dispatch_async(_worker, ^{
    NSError* error = nil;
    NSData* bytes = [NSPropertyListSerialization dataWithPropertyList:session format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (!bytes || !OXWriteArtifact(bytes,[self.directoryURL URLByAppendingPathComponent:@"session.bplist"],&error))
      [self report:error];
  });
  _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,_worker);
  dispatch_source_set_timer(_timer,dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),250*NSEC_PER_MSEC,25*NSEC_PER_MSEC);
  __weak OXInputArchive* weakSelf = self;
  dispatch_source_set_event_handler(_timer,^{ [weakSelf flush]; });
  dispatch_resume(_timer);
  return self;
}
- (void)report:(NSError*)error {
  if (_storageFailed) return;
  // Publication may have succeeded before a later fsync failed. Never retry
  // under a new name and turn the uncertain write into duplicate event ranges.
  _storageFailed = YES;
  NSString* message = [NSString stringWithFormat:@"Input recording %@: %@",_directoryURL.path,error.localizedDescription ?: @"archive write failed"];
  dispatch_async(dispatch_get_main_queue(),^{ if (self.failed) self.failed(message); });
}
- (void)flush {
  if (!_pending.count || _storageFailed) return;
  NSError* error = nil;
  NSDictionary* chunk = @{@"format":@"oxcart.input-events",@"version":@1,@"recording_id":_recordingID,
      @"first_sequence":_pending.firstObject[@"sequence"],@"last_sequence":_pending.lastObject[@"sequence"],@"events":[_pending copy]};
  NSData* bytes = [NSPropertyListSerialization dataWithPropertyList:chunk format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
  NSURL* path = [[_directoryURL URLByAppendingPathComponent:@"events" isDirectory:YES]
      URLByAppendingPathComponent:[NSString stringWithFormat:@"%020llu-%@.bplist",(unsigned long long)_chunk,NSUUID.UUID.UUIDString]];
  if (!bytes || !OXWriteArtifact(bytes,path,&error)) { [self report:error]; return; }
  ++_chunk; [_pending removeAllObjects];
}
- (void)append:(NSString*)kind fields:(NSDictionary*)fields {
  // All callers provide immutable snapshots; do not retain a live NSEvent/V8 value.
  NSDictionary* snapshot = Snapshot(fields);
  NSDate* date = NSDate.date; double uptime = NSProcessInfo.processInfo.systemUptime;
  dispatch_async(_worker,^{
    if (self->_closed) return;
    [self->_pending addObject:@{@"sequence":@(++self->_sequence),@"kind":[kind copy],
        @"received_at":date,@"receipt_uptime_seconds":@(uptime),@"fields":snapshot}];
    if (self->_pending.count >= 128) [self flush];
  });
}
- (void)closeWithCompletion:(void (^)(void))completion {
  dispatch_async(_worker,^{
    if (!self->_closed) {
      dispatch_source_cancel(self->_timer); self->_timer = nil;
      [self flush]; self->_closed = YES;
    }
    dispatch_async(dispatch_get_main_queue(),completion);
  });
}
- (void)dealloc { if (_timer) dispatch_source_cancel(_timer); }
@end
