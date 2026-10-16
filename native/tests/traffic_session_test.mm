#import <Foundation/Foundation.h>
#import "../cef/traffic_session.h"

static void Check(BOOL condition, NSString* message) {
  if (!condition) { fprintf(stderr,"FAIL: %s\n",message.UTF8String); exit(1); }
}
static void Wait(BOOL (^predicate)(void), NSString* message) {
  NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:8];
  while (!predicate() && deadline.timeIntervalSinceNow > 0)
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];
  Check(predicate(),message);
}
static NSDictionary* Take(NSMutableArray* commands, NSString* method) {
  __block NSDictionary* found = nil;
  Wait(^BOOL {
    for (NSDictionary* command in commands) if ([command[@"method"] isEqual:method]) { found = command; return YES; }
    return NO;
  },[@"Missing command " stringByAppendingString:method]);
  [commands removeObject:found]; return found;
}
static void Reply(NSDictionary* command, BOOL ok, NSDictionary* result) { ((OXTrafficReply)command[@"reply"])(ok,result); }
static id Read(NSURL* path) {
  NSData* bytes = [NSData dataWithContentsOfURL:path];
  Check(bytes != nil,[@"Unreadable artifact " stringByAppendingString:path.path]);
  NSPropertyListFormat format;
  id value = [NSPropertyListSerialization propertyListWithData:bytes options:0 format:&format error:nil];
  Check(value != nil && format == NSPropertyListBinaryFormat_v1_0,@"Expected binary native artifact"); return value;
}
static NSArray* Manifests(NSURL* root, NSString* directory) {
  NSURL* folder = [root URLByAppendingPathComponent:directory];
  NSArray* files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:folder includingPropertiesForKeys:nil options:0 error:nil];
  NSMutableArray* values = [NSMutableArray array];
  for (NSURL* file in files) if ([file.pathExtension isEqual:@"bplist"]) [values addObject:Read(file)];
  return values;
}
static NSData* Join(NSURL* root, NSArray* chunks) {
  NSMutableData* result = [NSMutableData data];
  for (NSDictionary* chunk in chunks) {
    Check([chunk[@"available"] boolValue],@"Body chunk must be available");
    NSData* bytes = [NSData dataWithContentsOfURL:[root URLByAppendingPathComponent:chunk[@"path"]]];
    Check(bytes.length == [chunk[@"bytes"] unsignedIntegerValue],@"Saved body byte count");
    [result appendData:bytes];
  }
  return result;
}
static NSDictionary* Pause(NSString* identifier, BOOL response) {
  NSMutableDictionary* value = [@{@"requestId":identifier,@"networkId":@"net-1",@"frameId":@"frame-1",@"resourceType":@"Document",
    @"request":@{@"url":@"https://www.python.org/",@"method":@"GET",@"headers":@{@"Accept":@"text/html"}}} mutableCopy];
  if (response) {
    value[@"responseStatusCode"] = @200;
    value[@"responseHeaders"] = @[@{@"name":@"Content-Type",@"value":@"application/octet-stream"},
      @{@"name":@"Content-Encoding",@"value":@"gzip"},@{@"name":@"Content-Length",@"value":@"100"},
      @{@"name":@"Set-Cookie",@"value":@"a=1"},@{@"name":@"Set-Cookie",@"value":@"b=2"}];
  }
  return value;
}
int main(int argc, const char* argv[]) {
  @autoreleasepool {
    Check(argc == 2,@"Pass artifact directory");
    NSURL* root = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES];
    NSMutableArray* commands = [NSMutableArray array];
    OXTrafficSession* session = [[OXTrafficSession alloc] initWithRootURL:root transport:^(NSString* method, NSDictionary* params, OXTrafficReply reply) {
      dispatch_async(dispatch_get_main_queue(),^{ [commands addObject:@{@"method":method,@"params":params,@"reply":[reply copy]}]; });
    }];
    __block NSDictionary* snapshot = nil;
    session.changed = ^(NSDictionary* value) { snapshot = value; };
    [session start]; Reply(Take(commands,@"Network.enable"),YES,@{});
    [session markContext:@{@"navigation_id":@"nav-1",@"page_url":@"https://www.python.org/"}];

    // Protocol buffered bytes precede incremental chunks even when the result is delayed.
    [session receiveEvent:@"Network.requestWillBeSent" parameters:@{@"requestId":@"n-1",@"request":@{@"url":@"https://www.python.org/",@"method":@"GET"}}];
    [session receiveEvent:@"Network.responseReceived" parameters:@{@"requestId":@"n-1",@"response":@{@"status":@200}}];
    NSDictionary* stream = Take(commands,@"Network.streamResourceContent");
    [session receiveEvent:@"Network.dataReceived" parameters:@{@"requestId":@"n-1",@"data":@"AP8=",@"dataLength":@2}];
    [session receiveEvent:@"Network.loadingFinished" parameters:@{@"requestId":@"n-1"}];
    Reply(stream,YES,@{@"bufferedData":@"YWJj"});
    Wait(^BOOL { return Manifests(session.directoryURL,@"bodies").count == 1; },@"Complete streamed body manifest");
    NSDictionary* body = Manifests(session.directoryURL,@"bodies").firstObject;
    const uint8_t expected[] = {'a','b','c',0,255};
    Check([Join(session.directoryURL,body[@"chunks"]) isEqual:[NSData dataWithBytes:expected length:5]],@"Exact ordered binary stream bytes");
    Check([body[@"outcome"] isEqual:@"completed"] && [body[@"stream_available"] boolValue],@"Stream completion state");

    // Unsupported streaming falls back to complete protocol body retrieval, with no content cap.
    [session receiveEvent:@"Network.requestWillBeSent" parameters:@{@"requestId":@"fallback",@"request":@{@"url":@"https://www.python.org/doc/"}}];
    [session receiveEvent:@"Network.responseReceived" parameters:@{@"requestId":@"fallback"}];
    Reply(Take(commands,@"Network.streamResourceContent"),NO,@{@"message":@"Not supported for resource"});
    [session receiveEvent:@"Network.loadingFinished" parameters:@{@"requestId":@"fallback"}];
    NSMutableData* large = [NSMutableData dataWithLength:1024*1024+29];
    ((uint8_t*)large.mutableBytes)[large.length-1] = 193;
    Reply(Take(commands,@"Network.getResponseBody"),YES,@{@"base64Encoded":@YES,@"body":[large base64EncodedStringWithOptions:0]});
    Wait(^BOOL { return Manifests(session.directoryURL,@"bodies").count == 2; },@"Fallback manifest");
    for (NSDictionary* item in Manifests(session.directoryURL,@"bodies")) if ([item[@"network_id"] isEqual:@"fallback"])
      Check([Join(session.directoryURL,@[item[@"fallback_body"]]) isEqual:large],@"Complete large fallback binary body");

    [session armPattern:@"https://www.python.org/*" requests:YES responses:YES];
    NSDictionary* arm = Take(commands,@"Fetch.enable");
    Check([arm[@"params"][@"patterns"] count] == 2,@"Explicit request and response stage patterns");
    Reply(arm,YES,@{});
    Wait(^BOOL { return [snapshot[@"armed"] count] != 0; },@"Armed snapshot");

    // The actual continued request receives URL/method/duplicate headers and arbitrary binary bytes.
    [session receiveEvent:@"Fetch.requestPaused" parameters:Pause(@"fetch-request",NO)];
    Wait(^BOOL { return [snapshot[@"pauses"] count] == 1; },@"Request pause");
    NSString* requestPause = snapshot[@"pauses"][0][@"id"];
    NSURL* replacement = [root URLByAppendingPathComponent:@"replacement.bin"];
    Check([[NSData dataWithBytes:expected length:5] writeToURL:replacement atomically:NO],@"Body input file");
    NSArray* duplicate = @[@{@"name":@"X-Example",@"value":@"one"},@{@"name":@"X-Example",@"value":@"two"}];
    [session applyPause:requestPause overrides:@{@"url":@"https://www.python.org/doc/",@"method":@"POST",@"headers":duplicate,@"body_file":replacement.path}];
    NSDictionary* continued = Take(commands,@"Fetch.continueRequest");
    NSDictionary* cp = continued[@"params"];
    Check([cp[@"url"] isEqual:@"https://www.python.org/doc/"] && [cp[@"method"] isEqual:@"POST"] && [cp[@"headers"] isEqual:duplicate],@"Request edits reach protocol recipient");
    Check([[[NSData alloc] initWithBase64EncodedString:cp[@"postData"] options:0] isEqual:[NSData dataWithBytes:expected length:5]],@"Request binary replacement");
    Reply(continued,YES,@{});
    Wait(^BOOL { return [snapshot[@"pauses"] count] == 0; },@"Request resolved");

    // Read the real upstream stream, retain it, then fulfill from a different file.
    [session receiveEvent:@"Fetch.requestPaused" parameters:Pause(@"fetch-response",YES)];
    NSDictionary* take = Take(commands,@"Fetch.takeResponseBodyAsStream");
    Reply(take,YES,@{@"stream":@"stream-A"});
    NSDictionary* read = Take(commands,@"IO.read");
    Check([read[@"params"][@"size"] isEqual:@65536],@"Chunk size is a read size, not a harvest limit");
    Reply(read,YES,@{@"base64Encoded":@YES,@"data":@"AAECA/8=",@"eof":@YES});
    Reply(Take(commands,@"IO.close"),YES,@{});
    Wait(^BOOL { return [snapshot[@"pauses"] count] == 1 && [snapshot[@"pauses"][0][@"body_manifest"] length] != 0; },@"Upstream bytes saved");
    NSDictionary* responseRow = snapshot[@"pauses"][0];
    NSDictionary* upstream = Read([session.directoryURL URLByAppendingPathComponent:responseRow[@"body_manifest"]]);
    NSData* upstreamBytes = Join(session.directoryURL,upstream[@"chunks"]);
    Check([upstreamBytes isEqual:[[NSData alloc] initWithBase64EncodedString:@"AAECA/8=" options:0]],@"Original upstream binary body retained");
    NSURL* oversized = [root URLByAppendingPathComponent:@"oversized-sparse-response.bin"];
    Check([NSData.data writeToURL:oversized atomically:NO],@"Sparse replacement created");
    NSFileHandle* sparse = [NSFileHandle fileHandleForWritingToURL:oversized error:nil];
    Check([sparse truncateAtOffset:static_cast<uint64_t>(UINT32_MAX)+1 error:nil],@"Sparse replacement extended"); [sparse closeFile];
    [session applyPause:responseRow[@"id"] overrides:@{@"body_file":oversized.path}];
    Wait(^BOOL { return [snapshot[@"status"] containsString:@"Chromium cannot fulfill"]; },@"Runtime fatal fulfillment size rejected before reading body into memory");
    [session applyPause:responseRow[@"id"] overrides:@{@"status":@201,@"headers":Pause(@"x",YES)[@"responseHeaders"],@"body_file":replacement.path}];
    NSDictionary* fulfilled = Take(commands,@"Fetch.fulfillRequest");
    NSDictionary* fp = fulfilled[@"params"];
    Check([fp[@"responseCode"] isEqual:@201],@"Edited status reaches fulfillment");
    Check([[[NSData alloc] initWithBase64EncodedString:fp[@"body"] options:0] isEqual:[NSData dataWithBytes:expected length:5]],@"Replacement response bytes reach fulfillment");
    Check([fp[@"responseHeaders"] count] == 3,@"Stale compression/length removed and duplicate Set-Cookie preserved");
    Reply(fulfilled,NO,@{@"message":@"Injected rejection"});
    Wait(^BOOL { return [snapshot[@"status"] containsString:@"rejected the decision"]; },@"Rejected decision remains paused");
    Check([snapshot[@"pauses"] count] == 1,@"Rejected edit not reported as delivered");
    [session forwardPause:responseRow[@"id"]];
    NSDictionary* originalForward = Take(commands,@"Fetch.fulfillRequest");
    Check([[[NSData alloc] initWithBase64EncodedString:originalForward[@"params"][@"body"] options:0] isEqual:upstreamBytes],@"Forward consumed response from exact original bytes");
    Reply(originalForward,YES,@{});
    Wait(^BOOL { return [snapshot[@"pauses"] count] == 0; },@"Response resolved");

    // Stop resolves an ordinary request unchanged and waits for resolution before disabling Fetch.
    [session receiveEvent:@"Fetch.requestPaused" parameters:Pause(@"stop-request",NO)];
    Wait(^BOOL { return [snapshot[@"pauses"] count] == 1; },@"Stop request pause");
    [session stop];
    NSDictionary* unchanged = Take(commands,@"Fetch.continueRequest");
    Check([unchanged[@"params"] isEqual:@{@"requestId":@"stop-request"}],@"Stop forwards ordinary request unchanged");
    Reply(unchanged,YES,@{}); Reply(Take(commands,@"Fetch.disable"),YES,@{});
    Wait(^BOOL { return [snapshot[@"armed"] count] == 0; },@"Disarmed");

    // Stop while a destructive body stream is open cancels promptly, retaining partial chunks.
    [session armPattern:@"https://www.python.org/*" requests:NO responses:YES];
    Reply(Take(commands,@"Fetch.enable"),YES,@{});
    Wait(^BOOL { return [snapshot[@"armed"] count] != 0; },@"Rearmed");
    [session receiveEvent:@"Fetch.requestPaused" parameters:Pause(@"stop-stream",YES)];
    Reply(Take(commands,@"Fetch.takeResponseBodyAsStream"),YES,@{@"stream":@"stream-B"});
    Reply(Take(commands,@"IO.read"),YES,@{@"data":@"first chunk",@"eof":@NO});
    NSDictionary* outstanding = Take(commands,@"IO.read");
    BOOL indexedBeforeEOF = NO;
    for (NSDictionary* event in Manifests(session.directoryURL,@"events")) {
      if ([event[@"kind"] isEqual:@"upstream_chunk"] && [event[@"fields"][@"fetch_id"] isEqual:@"stop-stream"]) {
        indexedBeforeEOF = [Join(session.directoryURL,@[event[@"fields"][@"body_blob"]]) isEqual:[@"first chunk" dataUsingEncoding:NSUTF8StringEncoding]];
      }
    }
    Check(indexedBeforeEOF,@"Original chunk ownership and bytes are indexed before EOF or Stop");
    [session stop];
    Reply(Take(commands,@"IO.close"),YES,@{});
    NSDictionary* aborted = Take(commands,@"Fetch.failRequest");
    Check([aborted[@"params"] isEqual:@{@"requestId":@"stop-stream",@"errorReason":@"Aborted"}],@"Stop cancels consumed stream without waiting for read/model");
    Reply(aborted,YES,@{}); Reply(Take(commands,@"Fetch.disable"),YES,@{});
    Reply(outstanding,NO,@{@"message":@"Stream closed"});
    Wait(^BOOL { return [snapshot[@"armed"] count] == 0; },@"Stream stop disarmed");

    // Redirect headers remain an ordinary pause; no attempt to consume a redirect body.
    [session armPattern:@"https://www.python.org/*" requests:NO responses:YES];
    Reply(Take(commands,@"Fetch.enable"),YES,@{});
    Wait(^BOOL { return [snapshot[@"armed"] count] != 0; },@"Redirect test armed");
    NSMutableDictionary* redirect = [Pause(@"redirect",YES) mutableCopy];
    redirect[@"responseStatusCode"] = @301; redirect[@"responseHeaders"] = @[@{@"name":@"Location",@"value":@"/doc/"}];
    [session receiveEvent:@"Fetch.requestPaused" parameters:redirect];
    Wait(^BOOL { return [snapshot[@"pauses"] count] == 1; },@"Redirect pause ready");
    Check([snapshot[@"pauses"][0][@"state"] isEqual:@"ready"],@"Redirect does not read body");
    [session forwardPause:snapshot[@"pauses"][0][@"id"]];
    Reply(Take(commands,@"Fetch.continueRequest"),YES,@{});
    Wait(^BOOL { return [snapshot[@"pauses"] count] == 0; },@"Redirect forwarded");

    // Cancel while a stream handle is in flight waits for that handle, then closes/cancels.
    [session receiveEvent:@"Fetch.requestPaused" parameters:Pause(@"cancel-opening",YES)];
    NSDictionary* opening = Take(commands,@"Fetch.takeResponseBodyAsStream");
    Wait(^BOOL { return [snapshot[@"pauses"] count] == 1; },@"Opening pause visible");
    [session cancelPause:snapshot[@"pauses"][0][@"id"]];
    Reply(opening,YES,@{@"stream":@"opening-stream"});
    Reply(Take(commands,@"IO.close"),YES,@{}); Reply(Take(commands,@"Fetch.failRequest"),YES,@{});
    Wait(^BOOL { return [snapshot[@"pauses"] count] == 0; },@"Opening stream canceled");

    // A detached agent retires old replies, preserves partials and disarms without sending stale decisions.
    [session receiveEvent:@"Fetch.requestPaused" parameters:Pause(@"detach-stream",YES)];
    Reply(Take(commands,@"Fetch.takeResponseBodyAsStream"),YES,@{@"stream":@"detach-handle"});
    NSDictionary* detachedRead = Take(commands,@"IO.read");
    [session agentDetached];
    Reply(detachedRead,YES,@{@"base64Encoded":@YES,@"data":@"AP8=",@"eof":@YES});
    Wait(^BOOL { return [snapshot[@"armed"] count] == 0 && [snapshot[@"pauses"] count] == 0; },@"Detached pauses retired");
    NSData* originalSession = [NSData dataWithContentsOfURL:[session.directoryURL URLByAppendingPathComponent:@"session.bplist"]];
    [session start]; Reply(Take(commands,@"Network.enable"),YES,@{});
    Wait(^BOOL { return [snapshot[@"status"] hasPrefix:@"Passive capture"]; },@"Passive capture resumed");
    Check([[NSData dataWithContentsOfURL:[session.directoryURL URLByAppendingPathComponent:@"session.bplist"]] isEqual:originalSession],@"Resuming preserves original session metadata");

    NSString* headerError = nil;
    Check([OXTrafficParseHeaders(@"Set-Cookie: a=1\nSet-Cookie: b=2",&headerError) count] == 2,@"Header editor preserves duplicates");
    Check(OXTrafficParseHeaders(@"missing colon",&headerError) == nil,@"Malformed header rejected");
    Check(OXTrafficParseHeaders(@"bad name: value",&headerError) == nil,@"Whitespace header name rejected");
    __block BOOL closed = NO; [session closeWithCompletion:^{ closed = YES; }];
    Wait(^BOOL { return closed; },@"Worker flushed on close");
    NSArray* events = Manifests(session.directoryURL,@"events");
    NSUInteger accepted = 0, rejected = 0;
    for (NSDictionary* event in events) if ([event[@"kind"] isEqual:@"decision_result"]) {
      if ([event[@"fields"][@"success"] boolValue]) ++accepted; else ++rejected;
    }
    Check(accepted == 6 && rejected == 1,@"Decision acceptance/rejection is distinct in actual retained timeline");
    Check([Join(session.directoryURL,upstream[@"chunks"]) isEqual:upstreamBytes],@"Editing never changes original upstream bytes");

    // Actual filesystem failure: no unretained edit and no stranded original request.
    NSURL* blocked = [root URLByAppendingPathComponent:@"blocked-root"];
    Check([[@"not a directory" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:blocked atomically:NO],@"Blocked storage fixture");
    OXTrafficSession* broken = [[OXTrafficSession alloc] initWithRootURL:blocked transport:^(NSString* method, NSDictionary* params, OXTrafficReply reply) {
      dispatch_async(dispatch_get_main_queue(),^{ [commands addObject:@{@"method":method,@"params":params,@"reply":[reply copy]}]; });
    }];
    __block NSDictionary* brokenSnapshot = nil; broken.changed = ^(NSDictionary* value) { brokenSnapshot = value; };
    [broken start]; Reply(Take(commands,@"Network.enable"),YES,@{});
    [broken armPattern:@"https://www.python.org/*" requests:YES responses:NO];
    Reply(Take(commands,@"Fetch.enable"),YES,@{});
    Wait(^BOOL { return [brokenSnapshot[@"armed"] count] != 0; },@"Fault test armed");
    [broken receiveEvent:@"Fetch.requestPaused" parameters:Pause(@"unretained-request",NO)];
    NSDictionary* rescue = Take(commands,@"Fetch.continueRequest");
    Check([rescue[@"params"] isEqual:@{@"requestId":@"unretained-request"}],@"Storage failure forwards unchanged instead of editing unretained original");
    Reply(rescue,YES,@{});
    Wait(^BOOL { return [brokenSnapshot[@"pauses"] count] == 0; },@"Storage failure did not strand request");
    Check([brokenSnapshot[@"status"] containsString:@"storage failure"],@"Storage failure remains visible");
    closed = NO; [broken closeWithCompletion:^{ closed = YES; }]; Wait(^BOOL { return closed; },@"Failed-storage session closes");
    printf("Native traffic command and storage checks passed: %s\n",session.directoryURL.path.UTF8String);
  }
}
