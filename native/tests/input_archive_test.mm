#import <Cocoa/Cocoa.h>
#import "../cef/input_archive.h"
#import "../cef/input_events.h"

static void Check(BOOL condition, NSString* message) {
  if (!condition) { fprintf(stderr,"FAIL: %s\n",message.UTF8String); exit(1); }
}
static void Wait(BOOL (^done)(void)) {
  NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:8];
  while (!done() && deadline.timeIntervalSinceNow > 0)
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];
  Check(done(),@"worker completion");
}
static id Read(NSURL* url) {
  NSPropertyListFormat format;
  id value = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:url] options:0 format:&format error:nil];
  Check(value && format == NSPropertyListBinaryFormat_v1_0,@"binary plist artifact"); return value;
}
int main(int argc, const char* argv[]) { @autoreleasepool {
  Check(argc == 2,@"artifact root argument");
  NSURL* root = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES];
  OXInputArchive* first = [[OXInputArchive alloc] initWithRootURL:root metadata:@{@"source":@"native archive check"}];
  OXInputArchive* second = [[OXInputArchive alloc] initWithRootURL:root metadata:@{}];
  __block BOOL failed = NO, finished = NO, finishedSecond = NO;
  first.failed = ^(NSString*) { failed = YES; };
  NSString* large = [@"😀\n" stringByPaddingToLength:1024*1024+29 withString:@"😀\n" startingAtIndex:0];
  unichar invalidUnits[] = {0xd800,0x41};
  NSString* invalid = [[NSString alloc] initWithCharacters:invalidUnits length:2];
  for (NSUInteger i = 0; i < 513; ++i)
    [first append:@"archive_payload" fields:@{@"index":@(i),@"timestamp":@123.456,@"payload":i == 127 ? large : (i == 128 ? invalid : @"x")}];
  [first append:@"stop_requested" fields:@{}];
  [second append:@"recording_started" fields:@{}];
  // A deferred renderer reply belongs to the original archive after restart.
  [first append:@"observer" fields:@{@"context_id":@"original-context",@"observation":@{@"kind":@"settled",@"event_id":@7,@"default_prevented":@NO}}];
  [first closeWithCompletion:^{ finished = YES; }];
  [second closeWithCompletion:^{ finishedSecond = YES; }];
  Wait(^BOOL { return finished && finishedSecond; });
  Check(!failed,@"normal archive writes");
  Check(![first.recordingID isEqual:second.recordingID],@"recording identities differ");
  Check([Read([first.directoryURL URLByAppendingPathComponent:@"session.bplist"])[@"id"] isEqual:first.recordingID],@"immutable session identity");
  NSArray* paths = [[NSFileManager.defaultManager contentsOfDirectoryAtURL:[first.directoryURL URLByAppendingPathComponent:@"events"] includingPropertiesForKeys:nil options:0 error:nil]
      sortedArrayUsingComparator:^NSComparisonResult(NSURL* a, NSURL* b) { return [a.lastPathComponent compare:b.lastPathComponent]; }];
  NSMutableArray* events = [NSMutableArray array];
  for (NSURL* path in paths) {
    NSDictionary* chunk = Read(path);
    Check([chunk[@"recording_id"] isEqual:first.recordingID],@"chunk recording identity");
    [events addObjectsFromArray:chunk[@"events"]];
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path.path error:nil];
    Check([attributes[NSFilePosixPermissions] unsignedLongValue] == 0600,@"private event file");
  }
  Check(events.count == 515,@"all events including late reply retained");
  for (NSUInteger i = 0; i < events.count; ++i) Check([events[i][@"sequence"] unsignedLongValue] == i+1,@"complete ordered event sequence");
  Check([events[127][@"fields"][@"payload"] isEqual:large],@"full large Unicode payload");
  unsigned char expectedUnits[] = {0x00,0xd8,0x41,0x00};
  Check([events[128][@"fields"][@"payload"][@"oxcart_utf16le"] isEqual:[NSData dataWithBytes:expectedUnits length:4]],@"unpaired UTF16 units preserved exactly");
  Check([events.lastObject[@"kind"] isEqual:@"observer"],@"late reply not assigned to new recording");

  NSEvent* down = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagShift timestamp:10.25 windowNumber:0 context:nil characters:@"Ä" charactersIgnoringModifiers:@"ä" isARepeat:NO keyCode:0];
  NSDictionary* key = OXNativeInputFields(down);
  Check([key[@"characters"] isEqual:@"Ä"] && [key[@"characters_ignoring_modifiers"] isEqual:@"ä"] && [key[@"native_timestamp_seconds"] doubleValue] == 10.25,@"actual native key snapshot");
  NSEvent* up = [NSEvent keyEventWithType:NSEventTypeKeyUp location:NSZeroPoint modifierFlags:0 timestamp:10.32 windowNumber:0 context:nil characters:@"a" charactersIgnoringModifiers:@"a" isARepeat:NO keyCode:0];
  Check([OXNativeInputFields(up)[@"type"] isEqual:@"key_up"],@"native key up");
  NSEvent* flags = [NSEvent keyEventWithType:NSEventTypeFlagsChanged location:NSZeroPoint modifierFlags:NSEventModifierFlagShift timestamp:10 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:56];
  Check(OXNativeInputFields(flags)[@"characters"] == nil,@"flags do not access key-only characters");
  NSEvent* mouse = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:NSMakePoint(13,29) modifierFlags:0 timestamp:20 windowNumber:0 context:nil eventNumber:3 clickCount:2 pressure:0.5];
  NSDictionary* click = OXNativeInputFields(mouse);
  Check([click[@"window_x"] intValue] == 13 && [click[@"window_y"] intValue] == 29 && [click[@"click_count"] intValue] == 2 && [click[@"button_number"] intValue] == 0,@"native pointer geometry/button/dwell ingredients");
  CGEventRef cg = CGEventCreateScrollWheelEvent(NULL,kCGScrollEventUnitPixel,2,19,-7);
  NSEvent* wheel = [NSEvent eventWithCGEvent:cg]; CFRelease(cg);
  NSDictionary* scroll = OXNativeInputFields(wheel);
  Check([scroll[@"type"] isEqual:@"scroll_wheel"] && scroll[@"phase"] && scroll[@"momentum_phase"] && scroll[@"scrolling_delta_y"],@"native scroll fields retained without posting input");

  OXInputArchive* episode = [[OXInputArchive alloc] initWithRootURL:root metadata:@{@"source":@"native event snapshot check"}];
  [episode append:@"native_input" fields:key];
  [episode append:@"native_input" fields:OXNativeInputFields(up)];
  [episode append:@"native_input" fields:scroll];
  [episode append:@"observer" fields:@{@"context_id":@"ctx",@"observation":@{@"kind":@"capture",@"event_id":@1,@"type":@"keydown",@"default_prevented":@NO}}];
  [episode append:@"observer" fields:@{@"context_id":@"ctx",@"observation":@{@"kind":@"settled",@"event_id":@1,@"default_prevented":@YES}}];
  __block BOOL episodeDone = NO;
  [episode closeWithCompletion:^{ episodeDone = YES; }]; Wait(^BOOL { return episodeDone; });

  NSURL* blocked = [root URLByAppendingPathComponent:@"not-a-directory"];
  Check([[@"block" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:blocked options:NSDataWritingWithoutOverwriting error:nil],@"create concrete IO failure");
  OXInputArchive* broken = [[OXInputArchive alloc] initWithRootURL:blocked metadata:@{}];
  __block BOOL errorSeen = NO, brokenDone = NO;
  broken.failed = ^(NSString* message) { errorSeen = [message containsString:@"not-a-directory"]; };
  [broken append:@"native_input" fields:@{@"key":@"x"}];
  [broken closeWithCompletion:^{ brokenDone = YES; }];
  Wait(^BOOL { return errorSeen && brokenDone; });
  printf("Native input snapshots, full ordered archives, late replies and visible disk failures passed\n");
  return 0;
} }
