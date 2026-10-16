#import "../cef/extraction_controller.h"
#import "../cef/extraction_workspace.h"
#import "../cef/blackbird_connection.h"
#import <Cocoa/Cocoa.h>
#include <cstdio>
#include <cstdlib>

static void Check(bool value, const char* message) {
  if (!value) { fprintf(stderr,"FAIL: %s\n",message); std::exit(1); }
}
static NSDictionary* Read(NSString* path) {
  NSData* data = [NSData dataWithContentsOfFile:path];
  return data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil] : nil;
}
@interface OXExtractionController (TestActions)
- (void)action:(NSString*)action fields:(NSDictionary*)fields;
@end
@interface ModelTransport : BSBlackbirdConnection
@property(nonatomic) BOOL omitOutputs;
@property(nonatomic) BOOL cancelTweak;
@property(nonatomic) BOOL malformedOutput;
@property(nonatomic,weak) OXExtractionController* controller;
@property(nonatomic,readonly) NSUInteger calls;
@property(nonatomic,readonly) BOOL inspectedPreview;
@end
@implementation ModelTransport {
  NSString* _active;
  BOOL _cancelled, _inspectedPreview;
  NSUInteger _calls;
}
- (BOOL)isReady { return YES; }
- (BOOL)isRunning { return _active != nil; }
- (NSUInteger)calls { return _calls; }
- (BOOL)inspectedPreview { return _inspectedPreview; }
- (NSString*)sendObjective:(NSString*)objective observations:(NSArray*)observations steer:(BOOL)steer {
  (void)steer;
  Check(!_active,"coordinator does not overlap model turns");
  ++_calls; _cancelled = NO; _active = NSUUID.UUID.UUIDString;
  NSString* request = _active;
  NSString* directory = [NSURL URLWithString:observations[0][@"url"]].path.stringByDeletingLastPathComponent;
  NSDictionary* attempt = Read([directory stringByAppendingPathComponent:@"attempt.bplist"]);
  Check(attempt != nil && [objective containsString:@"FORMAT.txt"],"model receives actual saved input/format paths");
  if (attempt[@"predecessor_directory"]) {
    NSString* path = [attempt[@"predecessor_directory"] stringByAppendingPathComponent:@"preview.txt"];
    NSString* rendered = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    Check(rendered.length > 0,"revision can inspect actual previously rendered preview");
    _inspectedPreview = YES;
  }
  if ([attempt[@"phase"] isEqual:@"manual"]) Check([attempt[@"readings"] count] == 2,"manual correction includes newly collected same-visit reading");
  dispatch_async(dispatch_get_main_queue(),^{
    if (!self.omitOutputs) {
      NSMutableDictionary* document = [@{@"format":@"oxcart.extraction",@"version":@1,
          @"title":[@"Result · " stringByAppendingString:attempt[@"phase"]],
          @"blocks":@[@{@"kind":@"paragraph",@"text":@"Source-supported content",@"interpretation":@"observed",@"sources":@[@{@"capture_id":@"capture"}]}],
          @"assessment":@"needs_help",@"issues":@[@"Operator should check coverage"],
          @"recipe":@{@"page_type":@"Example",@"applicability":@"Matching page types",@"instructions":@"Collect source-supported content"}} mutableCopy];
      if (self.malformedOutput) document[@"issues"] = @17;
      NSData* bytes = [NSPropertyListSerialization dataWithPropertyList:document format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
      Check(OXWriteArtifact(bytes,[NSURL fileURLWithPath:attempt[@"result_path"]],nil),"model writes native result");
    }
    if (self.cancelTweak && [attempt[@"phase"] isEqual:@"tweak"]) [self.controller stop];
    self->_active = nil;
    [self.controller receiveEvent:@{@"type":@"final",@"id":request,@"text":@"Result saved",
        @"outcome":self->_cancelled ? @"cancelled" : @"completed"}];
  });
  return request;
}
- (void)cancel { _cancelled = YES; }
@end

static void Wait(BOOL* finished) {
  NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:25];
  while (!*finished && deadline.timeIntervalSinceNow > 0)
    [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  Check(*finished,"native extraction loop finishes");
}
int main(int argc, char** argv) { @autoreleasepool {
  [NSApplication sharedApplication];
  NSString* path = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
  NSURL* root = [NSURL fileURLWithPath:path isDirectory:YES];
  NSURL* reading = [root URLByAppendingPathComponent:@"reading"];
  NSDictionary* metadata = @{@"format":@"oxcart.reading",@"version":@1,@"capture_id":@"capture",
      @"documents":@[@{@"text_bytes":@24,@"text_file":@"0.txt"}]};
  NSData* manifest = [NSPropertyListSerialization dataWithPropertyList:metadata format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
  Check(OXWriteArtifact(manifest,[reading URLByAppendingPathComponent:@"reading.bplist"],nil),"create direct native reading metadata");
  NSDictionary* reference = @{@"capture_id":@"capture",@"url":reading.absoluteString,@"reading":@{
      @"directory":reading.path,@"manifest_path":[reading URLByAppendingPathComponent:@"reading.bplist"].path}};
  for (NSUInteger scenario = 0; scenario < 4; ++scenario) {
    NSURL* directory = [root URLByAppendingPathComponent:[NSString stringWithFormat:@"case-%lu",(unsigned long)scenario]];
    ModelTransport* transport = [[ModelTransport alloc] initWithExecutableURL:[NSURL fileURLWithPath:@"/usr/bin/true"]
        sessionURL:directory workingDirectoryURL:root model:@"controlled"];
    transport.omitOutputs = scenario == 1; transport.cancelTweak = scenario == 2;
    transport.malformedOutput = scenario == 3;
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    OXExtractionController* controller = [[OXExtractionController alloc] initWithDataURL:directory connection:transport result:result];
    transport.controller = controller;
    __block BOOL finished = NO; controller.finished = ^{ finished = YES; };
    [controller beginVisitWithURL:@"https://www.python.org/" title:@"Saved native inputs"];
    [controller addReading:reference]; [controller extract:@"Organize the retained inputs"];
    Wait(&finished);
    Check(transport.calls == 2 && transport.inspectedPreview,"exactly initial pass plus one revision, using real renderer output");
    Check(!controller.busy,"finished loop leaves no active extraction");
    if (scenario == 0) {
      Check([result[@"extraction"][@"valid"] boolValue],"valid second result is available");
      NSString* prior = result[@"extraction"][@"attempt_id"];
      NSURL* extraReading = [root URLByAppendingPathComponent:@"reading-2"];
      NSMutableDictionary* extraMetadata = [metadata mutableCopy]; extraMetadata[@"capture_id"] = @"capture-2";
      NSData* extraManifest = [NSPropertyListSerialization dataWithPropertyList:extraMetadata format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
      Check(OXWriteArtifact(extraManifest,[extraReading URLByAppendingPathComponent:@"reading.bplist"],nil),"save a second captured identity");
      NSDictionary* extra = @{@"capture_id":@"capture-2",@"url":extraReading.absoluteString,@"reading":@{
          @"directory":extraReading.path,@"manifest_path":[extraReading URLByAppendingPathComponent:@"reading.bplist"].path}};
      [controller addReading:extra]; finished = NO;
      [controller action:@"revise" fields:@{@"attempt_id":prior,@"correction":@"Include the new reading",@"selection":@"Source-supported content"}];
      Wait(&finished);
      Check(transport.calls == 3 && [result[@"extraction"][@"phase"] isEqual:@"manual"],"operator revision does not start another automatic loop");
    } else if (scenario == 1 || scenario == 3) Check(![result[@"extraction"][@"valid"] boolValue] && result[@"extraction_error"],"missing/malformed model outputs remain explicit after one tweak");
    else {
      Check(result[@"extraction_error"] != nil,"Stop reports retained cancelled work");
      NSArray* attempts = [NSFileManager.defaultManager contentsOfDirectoryAtURL:[[directory URLByAppendingPathComponent:@"extraction"] URLByAppendingPathComponent:@"attempts"] includingPropertiesForKeys:nil options:0 error:nil];
      NSUInteger retained = 0;
      for (NSURL* attempt in attempts) if ([NSFileManager.defaultManager fileExistsAtPath:[attempt URLByAppendingPathComponent:@"received.bplist"].path]) ++retained;
      Check(retained == 2,"cancelled second submission remains retained");
    }
    finished = NO; controller.finished = nil;
    [controller closeWithCompletion:^{ finished = YES; }]; Wait(&finished);
  }
  if (argc <= 1) [NSFileManager.defaultManager removeItemAtURL:root error:nil];
  puts("native initial/tweak/manual/Stop loop and actual preview consumption passed");
}}
