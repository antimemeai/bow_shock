#import "traffic_session.h"
#import "extraction_workspace.h"

namespace {
NSDictionary* Dict(id x) { return [x isKindOfClass:NSDictionary.class] ? x : @{}; }
NSString* Text(id x) { return [x isKindOfClass:NSString.class] ? x : @""; }
NSURL* Child(NSURL* url, NSString* path) { return [url URLByAppendingPathComponent:path]; }
id Native(id x) {
  if (x == NSNull.null) return @{@"oxcart_external_null":@YES};
  if ([x isKindOfClass:NSDictionary.class]) {
    NSMutableDictionary* out = [NSMutableDictionary dictionary];
    for (NSString* key in x) out[key] = Native(x[key]);
    return out;
  }
  if ([x isKindOfClass:NSArray.class]) {
    NSMutableArray* out = [NSMutableArray array]; for (id item in x) [out addObject:Native(item)]; return out;
  }
  return x;
}
NSData* Body(NSDictionary* result, NSString* field) {
  NSString* value = result[field];
  if (![value isKindOfClass:NSString.class]) return nil;
  return [result[@"base64Encoded"] boolValue] ? [[NSData alloc] initWithBase64EncodedString:value options:0]
      : [value dataUsingEncoding:NSUTF8StringEncoding];
}
BOOL ValidHeaders(id value) {
  if (![value isKindOfClass:NSArray.class]) return NO;
  for (id raw in value) {
    NSDictionary* h = Dict(raw);
    NSCharacterSet* token = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&'*+-.^_`|~"];
    if (!Text(h[@"name"]).length || ![h[@"value"] isKindOfClass:NSString.class] ||
        [Text(h[@"name"]) rangeOfCharacterFromSet:token.invertedSet].location != NSNotFound ||
        [Text(h[@"value"]) rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location != NSNotFound) return NO;
    for (NSUInteger i = 0; i < [h[@"value"] length]; ++i) {
      unichar c = [h[@"value"] characterAtIndex:i]; if ((c < 32 && c != 9) || c == 127) return NO;
    }
  }
  return YES;
}
NSArray* HeaderArray(id value) {
  if ([value isKindOfClass:NSArray.class]) return value;
  NSMutableArray* out = [NSMutableArray array];
  for (NSString* key in Dict(value)) [out addObject:@{@"name":key,@"value":Text(value[key])}];
  return out;
}
}
NSArray<NSDictionary*>* OXTrafficParseHeaders(NSString* text, NSString** error) {
  NSMutableArray* out = [NSMutableArray array];
  for (NSString* raw in [text componentsSeparatedByString:@"\n"]) {
    NSString* line = [raw hasSuffix:@"\r"] ? [raw substringToIndex:raw.length-1] : raw;
    if (!line.length) continue;
    NSRange split = [line rangeOfString:@":"];
    if (split.location == NSNotFound || !split.location) { if (error) *error = @"Each header needs a name followed by a colon."; return nil; }
    NSString* value = [line substringFromIndex:split.location+1];
    if ([value hasPrefix:@" "]) value = [value substringFromIndex:1];
    [out addObject:@{@"name":[line substringToIndex:split.location],@"value":value}];
  }
  if (!ValidHeaders(out)) { if (error) *error = @"Invalid header name or embedded line break."; return nil; }
  return out;
}
NSString* OXTrafficHeaderText(id headers) {
  NSMutableArray* lines = [NSMutableArray array];
  for (NSDictionary* header in HeaderArray(headers))
    [lines addObject:[NSString stringWithFormat:@"%@: %@",header[@"name"],header[@"value"]]];
  return [lines componentsJoinedByString:@"\n"];
}

@implementation OXTrafficSession {
  dispatch_queue_t _worker;
  OXTrafficTransport _transport;
  NSMutableDictionary<NSString*, NSMutableDictionary*>* _requests;
  NSMutableDictionary<NSString*, NSMutableDictionary*>* _pauses;
  NSMutableArray* _recent;
  NSDictionary* _context;
  NSDictionary* _armed;
  NSString* _status;
  NSString* _storageError;
  NSUInteger _sequence;
  NSUInteger _generation;
  BOOL _closed, _stopping, _fetchEnabled, _fetchChanging, _started;
}
- (instancetype)initWithRootURL:(NSURL*)root transport:(OXTrafficTransport)transport {
  if ((self = [super init])) {
    _directoryURL = Child(root,NSUUID.UUID.UUIDString);
    _worker = dispatch_queue_create("dev.oxcart.traffic",DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    _transport = [transport copy]; _requests = [NSMutableDictionary dictionary];
    _pauses = [NSMutableDictionary dictionary]; _recent = [NSMutableArray array];
    _context = @{}; _status = @"Starting passive traffic capture…";
  }
  return self;
}
- (BOOL)write:(id)value path:(NSString*)path {
  NSError* error = nil;
  NSData* bytes = [NSPropertyListSerialization dataWithPropertyList:Native(value)
      format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
  if (!bytes || !OXWriteArtifact(bytes,Child(_directoryURL,path),&error)) {
    _status = [@"Traffic storage failure: " stringByAppendingString:error.localizedDescription ?: @"unknown error"];
    _storageError = _status;
    [self publish]; return NO;
  }
  return YES;
}
- (NSDictionary*)blob:(NSData*)bytes representation:(NSString*)representation {
  if (!bytes) return @{@"available":@NO,@"reason":@"Protocol body is absent or has invalid encoding."};
  NSString* path = [NSString stringWithFormat:@"blobs/%@.bin",NSUUID.UUID.UUIDString];
  NSError* error = nil;
  if (!OXWriteArtifact(bytes,Child(_directoryURL,path),&error)) {
    _status = [@"Traffic body storage failure: " stringByAppendingString:error.localizedDescription ?: @"unknown error"];
    _storageError = _status;
    [self publish];
    return @{@"available":@NO,@"reason":_status};
  }
  return @{@"available":@YES,@"path":path,@"bytes":@(bytes.length),@"representation":representation};
}
- (NSString*)record:(NSString*)kind fields:(NSDictionary*)fields {
  NSString* path = [NSString stringWithFormat:@"events/%012lu-%@.bplist",(unsigned long)++_sequence,NSUUID.UUID.UUIDString];
  [self write:@{@"kind":kind,@"sequence":@(_sequence),@"at":NSDate.date,
    @"uptime_seconds":@(NSProcessInfo.processInfo.systemUptime),@"context":_context,@"fields":fields} path:path];
  return path;
}
- (void)publish {
  NSMutableArray* pauses = [NSMutableArray array];
  for (NSString* key in _pauses) {
    NSDictionary* p = _pauses[key];
    NSMutableDictionary* summary = [NSMutableDictionary dictionaryWithDictionary:p[@"summary"]];
    summary[@"state"] = p[@"state"]; summary[@"body_owned"] = @([p[@"owned"] boolValue]);
    summary[@"body_bytes"] = p[@"body_bytes"] ?: @0;
    summary[@"body_manifest"] = p[@"body_manifest"] ?: @"";
    [pauses addObject:summary];
  }
  NSString* status = _storageError ? [NSString stringWithFormat:@"%@ · %@",_storageError,_status] : _status;
  NSDictionary* snapshot = @{@"directory":_directoryURL.path,@"status":status ?: @"",
    @"event_count":@(_sequence),@"armed":_armed ?: @{},@"pauses":pauses,@"recent":[_recent copy]};
  dispatch_async(dispatch_get_main_queue(),^{ if (self.changed) self.changed(snapshot); });
}
- (void)command:(NSString*)method params:(NSDictionary*)params reply:(OXTrafficReply)completion {
  if (_closed) return;
  [self record:@"command" fields:@{@"method":method,@"parameters":params}];
  __weak OXTrafficSession* weakSelf = self;
  NSUInteger generation = _generation;
  _transport(method,params,^(BOOL success, NSDictionary* result) {
    OXTrafficSession* owner = weakSelf; if (!owner) return;
    dispatch_async(owner->_worker,^{
      if (owner->_closed) return;
      if (owner->_generation != generation) {
        [owner record:@"retired_command_result" fields:@{@"method":method,@"success":@(success),@"result":result}]; return;
      }
      completion(success,Dict(result));
    });
  });
}
- (void)start {
  dispatch_async(_worker,^{
    if (self->_closed) return;
    if (!self->_started) [self write:@{@"format":@"oxcart.traffic",@"version":@1,@"created_at":NSDate.date,
      @"coverage":@[@"Current CEF DevTools target only; separately attached frame/worker targets are not collected.",
        @"Protocol-decoded bodies and header metadata, not TLS/HTTP wire bytes. Multipart file bytes may be absent.",
        @"Incremental content capture is requested per response. Missing/evicted/unavailable content is recorded.",
        @"Passive stream chunks are binary blobs. Edits are explicit Fetch pauses; fulfillment may require a complete base64 argument."]} path:@"session.bplist"];
    self->_started = YES;
    [self command:@"Network.enable" params:@{} reply:^(BOOL ok, NSDictionary* result) {
      [self record:@"capture_enabled" fields:@{@"success":@(ok),@"result":result}];
      self->_status = ok ? @"Passive capture. Editing is disarmed." : @"Chromium rejected traffic capture; see the retained error.";
      [self publish];
    }];
  });
}
- (void)markContext:(NSDictionary*)context {
  dispatch_async(_worker,^{
    if (self->_closed) return;
    NSMutableDictionary* merged = [context[@"lifecycle"] isEqual:@"main_load_started"] ? [NSMutableDictionary dictionary] : [self->_context mutableCopy];
    [merged addEntriesFromDictionary:context]; self->_context = merged;
    [self record:@"context" fields:context];
  });
}
- (void)receiveEvent:(NSString*)method parameters:(NSDictionary*)parameters {
  dispatch_async(_worker,^{ if (!self->_closed) [self event:method parameters:parameters]; });
}
- (void)receiveEvent:(NSString*)method protocolBytes:(NSData*)bytes {
  dispatch_async(_worker,^{
    if (self->_closed) return;
    NSError* error = nil;
    id value = [NSJSONSerialization JSONObjectWithData:bytes options:0 error:&error];
    if (![value isKindOfClass:NSDictionary.class]) {
      [self record:@"protocol_error" fields:@{@"method":method,@"error":error.localizedDescription ?: @"Expected dictionary",
        @"original":[self blob:bytes representation:@"external-CDP-JSON"]}]; return;
    }
    [self event:method parameters:value];
  });
}
- (void)finishRequest:(NSMutableDictionary*)request {
  if ([request[@"pending_stream"] boolValue] || !request[@"finished"] || [request[@"finalized"] boolValue]) return;
  if (![request[@"stream_ok"] boolValue] && [request[@"finished"] isEqual:@"completed"] && !request[@"fallback_attempted"]) {
    if (_requests[request[@"network_id"]] != request) {
      request[@"fallback_attempted"] = @YES; request[@"fallback_error"] = @{@"message":@"Network request ID was reused before body retrieval."};
      [self finishRequest:request]; return;
    }
    request[@"fallback_attempted"] = @YES; request[@"pending_stream"] = @YES;
    [self command:@"Network.getResponseBody" params:@{@"requestId":request[@"network_id"]} reply:^(BOOL ok, NSDictionary* result) {
      request[@"pending_stream"] = @NO;
      NSData* bytes = ok ? Body(result,@"body") : nil;
      if (bytes) {
        request[@"fallback_body"] = [self blob:bytes representation:@"Network.getResponseBody protocol-decoded content"];
      } else request[@"fallback_error"] = result;
      [self record:@"body_fallback" fields:@{@"exchange_id":request[@"id"],@"success":@(ok && bytes != nil),@"result":bytes ? @{} : result}];
      [self finishRequest:request]; [self publish];
    }];
    return;
  }
  request[@"finalized"] = @YES;
  NSString* path = [NSString stringWithFormat:@"bodies/%@.bplist",request[@"id"]];
  [self write:@{@"network_id":request[@"network_id"],@"exchange_id":request[@"id"],
    @"chunks":request[@"chunks"],@"outcome":request[@"finished"],
    @"stream_available":request[@"stream_ok"] ?: @NO,@"error":request[@"error"] ?: @"",
    @"fallback_body":request[@"fallback_body"] ?: @{},@"fallback_error":request[@"fallback_error"] ?: @{},
    @"representation":@"Chromium Network protocol-decoded content"} path:path];
  [self record:@"body_finished" fields:@{@"exchange_id":request[@"id"],@"manifest":path}];
}
- (NSDictionary*)retainRequest:(NSDictionary*)value {
  NSMutableDictionary* original = [value mutableCopy];
  if ([original[@"postData"] isKindOfClass:NSString.class]) {
    original[@"post_data_blob"] = [self blob:[original[@"postData"] dataUsingEncoding:NSUTF8StringEncoding]
        representation:@"CDP postData text re-encoded as UTF-8; multipart file bytes may be absent"];
    [original removeObjectForKey:@"postData"];
  }
  if ([original[@"postDataEntries"] isKindOfClass:NSArray.class]) {
    NSMutableArray* entries = [NSMutableArray array];
    for (NSDictionary* entry in original[@"postDataEntries"])
      [entries addObject:[self blob:[entry[@"bytes"] isKindOfClass:NSString.class] ? [[NSData alloc] initWithBase64EncodedString:entry[@"bytes"] options:0] : nil
          representation:@"CDP postDataEntries bytes; missing file bytes remain unavailable"]];
    original[@"postDataEntries"] = entries;
  }
  return original;
}
- (void)event:(NSString*)method parameters:(NSDictionary*)parameters {
  NSMutableDictionary* payload = [parameters mutableCopy];
  if ([parameters[@"request"] isKindOfClass:NSDictionary.class]) payload[@"request"] = [self retainRequest:parameters[@"request"]];
  NSString* networkID = Text(parameters[@"requestId"]);
  NSMutableDictionary* request = _requests[networkID];
  if ([method isEqual:@"Network.requestWillBeSent"]) {
    if (request && ![request[@"finalized"] boolValue]) {
      request[@"finished"] = @"redirected_or_id_reused"; [self finishRequest:request];
    }
    request = [@{@"id":NSUUID.UUID.UUIDString,@"network_id":networkID,@"chunks":[NSMutableArray array],
      @"url":Text(Dict(parameters[@"request"])[@"url"])} mutableCopy];
    if (networkID.length) _requests[networkID] = request;
    payload[@"exchange_id"] = request[@"id"];
    NSDictionary* original = Dict(parameters[@"request"]);
    if ([original[@"hasPostData"] boolValue] && ![original[@"postData"] isKindOfClass:NSString.class]) {
      [self command:@"Network.getRequestPostData" params:@{@"requestId":networkID} reply:^(BOOL ok, NSDictionary* result) {
        NSDictionary* blob = [self blob:ok && [result[@"postData"] isKindOfClass:NSString.class] ? [result[@"postData"] dataUsingEncoding:NSUTF8StringEncoding] : nil
            representation:@"Network.getRequestPostData UTF-8 text; multipart file bytes explicitly excluded by protocol"];
        [self record:@"request_body_retrieved" fields:@{@"exchange_id":request[@"id"],@"body":blob,@"result":ok ? @{} : result}];
      }];
    }
  }
  if ([method isEqual:@"Network.dataReceived"] && [parameters[@"data"] isKindOfClass:NSString.class]) {
    NSDictionary* chunk = [self blob:[[NSData alloc] initWithBase64EncodedString:parameters[@"data"] options:0]
        representation:@"Network.streamResourceContent chunk"];
    [payload removeObjectForKey:@"data"]; payload[@"data_blob"] = chunk;
    if (request) [request[@"chunks"] addObject:chunk];
  }
  NSString* eventPath = [self record:method fields:payload];
  if ([method isEqual:@"Network.requestWillBeSent"] || [method isEqual:@"Network.responseReceived"]) {
    [_recent addObject:@{@"method":method,@"url":request[@"url"] ?: @"",@"event_path":eventPath,@"network_id":networkID}];
    if (_recent.count > 150) [_recent removeObjectAtIndex:0]; // UI viewport only; all events/bodies remain on disk.
  }
  if ([method isEqual:@"Fetch.requestPaused"]) { [self paused:payload]; return; }
  if ([method isEqual:@"Network.responseReceived"] && request && !request[@"pending_stream"] && !request[@"stream_ok"]) {
    request[@"pending_stream"] = @YES;
    [self command:@"Network.streamResourceContent" params:@{@"requestId":networkID} reply:^(BOOL ok, NSDictionary* result) {
      request[@"pending_stream"] = @NO; request[@"stream_ok"] = @(ok);
      if (ok) {
        NSDictionary* chunk = [self blob:[result[@"bufferedData"] isKindOfClass:NSString.class] ? [[NSData alloc] initWithBase64EncodedString:result[@"bufferedData"] options:0] : nil
            representation:@"Network.streamResourceContent initial buffered bytes"];
        [request[@"chunks"] insertObject:chunk atIndex:0];
        if (![chunk[@"available"] boolValue]) { request[@"stream_ok"] = @NO; request[@"error"] = @{@"message":@"Missing or invalid initial buffered data."}; }
      } else request[@"error"] = result;
      [self record:@"stream_started" fields:@{@"exchange_id":request[@"id"],@"success":@(ok),@"error":ok ? @{} : result}];
      [self finishRequest:request]; [self publish];
    }];
  }
  if (([method isEqual:@"Network.loadingFinished"] || [method isEqual:@"Network.loadingFailed"]) && request) {
    request[@"finished"] = [method isEqual:@"Network.loadingFinished"] ? @"completed" : @"failed";
    [self finishRequest:request];
  }
  [self publish];
}
- (void)armPattern:(NSString*)pattern requests:(BOOL)requests responses:(BOOL)responses {
  dispatch_async(_worker,^{
    if (self->_closed) return;
    if (!pattern.length || (!requests && !responses) || self->_fetchChanging || self->_pauses.count) {
      self->_status = @"Resolve existing pauses before changing the pattern; select a nonempty glob and stage."; [self publish]; return;
    }
    self->_stopping = NO; self->_fetchChanging = YES;
    NSDictionary* revision = @{@"id":NSUUID.UUID.UUIDString,@"pattern":pattern,@"requests":@(requests),@"responses":@(responses)};
    NSMutableArray* patterns = [NSMutableArray array];
    if (requests) [patterns addObject:@{@"urlPattern":pattern,@"requestStage":@"Request"}];
    if (responses) [patterns addObject:@{@"urlPattern":pattern,@"requestStage":@"Response"}];
    [self record:@"arm_requested" fields:revision];
    [self command:@"Fetch.enable" params:@{@"patterns":patterns,@"handleAuthRequests":@NO} reply:^(BOOL ok, NSDictionary* result) {
      self->_fetchChanging = NO;
      if (ok) { self->_fetchEnabled = YES; self->_armed = revision; }
      [self record:@"arm_result" fields:@{@"revision":revision,@"success":@(ok),@"result":result}];
      self->_status = ok ? @"Editing armed. Matching traffic will pause." : @"Chromium rejected the pause pattern.";
      [self maybeDisable]; [self publish];
    }];
  });
}
- (void)paused:(NSDictionary*)parameters {
  NSString* fetchID = Text(parameters[@"requestId"]);
  if (!fetchID.length) return;
  BOOL response = parameters[@"responseStatusCode"] || parameters[@"responseErrorReason"];
  NSString* identity = NSUUID.UUID.UUIDString;
  NSDictionary* original = Dict(parameters[@"request"]);
  NSDictionary* summary = @{@"id":identity,@"fetch_id":fetchID,@"response":@(response),@"url":Text(original[@"url"]),
    @"method":Text(original[@"method"]),@"headers":response ? HeaderArray(parameters[@"responseHeaders"]) : HeaderArray(original[@"headers"]),
    @"status":parameters[@"responseStatusCode"] ?: @0,@"directory":[NSString stringWithFormat:@"pauses/%@",identity]};
  NSMutableDictionary* pause = [@{@"summary":summary,@"original":parameters,@"state":@"ready",@"chunks":[NSMutableArray array]} mutableCopy];
  _pauses[identity] = pause;
  BOOL saved = [self write:@{@"id":identity,@"original":parameters,@"armed_revision":_armed ?: @{},@"context":_context}
      path:[summary[@"directory"] stringByAppendingPathComponent:@"original.bplist"]];
  [self record:@"paused" fields:summary];
  if (!saved) {
    // A disk failure must neither edit unretained originals nor strand page traffic.
    [self command:@"Fetch.continueRequest" params:@{@"requestId":fetchID} reply:^(BOOL ok, NSDictionary* result) {
      [self resolved:pause identity:identity method:@"Fetch.continueRequest" success:ok result:result];
    }];
    return;
  }
  if (_stopping || !_armed) { [self forward:pause identity:identity overrides:nil]; return; }
  NSInteger code = [parameters[@"responseStatusCode"] integerValue];
  BOOL hasLocation = NO;
  for (NSDictionary* header in summary[@"headers"]) if ([Text(header[@"name"]).lowercaseString isEqual:@"location"]) hasLocation = YES;
  BOOL redirect = [@[@301,@302,@303,@307,@308] containsObject:@(code)] && hasLocation;
  BOOL noBody = [Text(original[@"method"]) isEqual:@"HEAD"] || code < 200 || code == 204 || code == 205 || code == 304;
  if (response && !redirect && !noBody && !parameters[@"responseErrorReason"]) {
    pause[@"state"] = @"opening_stream";
    [self command:@"Fetch.takeResponseBodyAsStream" params:@{@"requestId":fetchID} reply:^(BOOL ok, NSDictionary* result) {
      if (!self->_pauses[identity]) return;
      NSString* stream = Text(result[@"stream"]);
      if (!ok || !stream.length) {
        pause[@"state"] = @"ready"; pause[@"body_error"] = result;
        [self record:@"upstream_body_unavailable" fields:@{@"pause_id":identity,@"result":result}];
        if ([pause[@"cancel_when_open"] boolValue]) [self cancel:pause identity:identity];
        else if (self->_stopping) [self forward:pause identity:identity overrides:nil];
        [self publish]; return;
      }
      pause[@"stream"] = stream; pause[@"owned"] = @YES; pause[@"state"] = @"reading_stream";
      if (self->_stopping || [pause[@"cancel_when_open"] boolValue]) [self cancel:pause identity:identity];
      else [self readStream:pause identity:identity];
    }];
  }
  [self publish];
}
- (void)saveBody:(NSMutableDictionary*)pause identity:(NSString*)identity outcome:(NSString*)outcome {
  if (pause[@"body_manifest"]) return;
  NSString* path = [pause[@"summary"][@"directory"] stringByAppendingPathComponent:@"upstream-body.bplist"];
  [self write:@{@"chunks":pause[@"chunks"],@"outcome":outcome,@"pause_id":identity,
    @"representation":@"Fetch/IO protocol response stream bytes",@"bytes":pause[@"body_bytes"] ?: @0} path:path];
  pause[@"body_manifest"] = path;
}
- (void)readStream:(NSMutableDictionary*)pause identity:(NSString*)identity {
  [self command:@"IO.read" params:@{@"handle":pause[@"stream"],@"size":@65536} reply:^(BOOL ok, NSDictionary* result) {
    if (!self->_pauses[identity] || ![pause[@"state"] isEqual:@"reading_stream"]) {
      [self record:@"late_stream_result" fields:@{@"pause_id":identity,@"success":@(ok),
        @"body":ok ? [self blob:Body(result,@"data") representation:@"IO.read bytes received after cancellation"] : @{},
        @"error":ok ? @{} : result}]; return;
    }
    if (!ok) {
      [self record:@"upstream_stream_failed" fields:@{@"pause_id":identity,@"result":result}];
      [self cancel:pause identity:identity]; return;
    }
    NSData* bytes = Body(result,@"data");
    NSDictionary* blob = [self blob:bytes representation:@"Fetch/IO stream bytes"];
    [pause[@"chunks"] addObject:blob];
    pause[@"body_bytes"] = @([pause[@"body_bytes"] unsignedLongLongValue] + bytes.length);
    if (![blob[@"available"] boolValue]) { [self cancel:pause identity:identity]; return; }
    if ([result[@"eof"] boolValue]) {
      pause[@"state"] = @"ready"; pause[@"complete"] = @YES;
      [self saveBody:pause identity:identity outcome:@"completed"];
      [self command:@"IO.close" params:@{@"handle":pause[@"stream"]} reply:^(BOOL closed, NSDictionary* reply) {
        [self record:@"stream_closed" fields:@{@"pause_id":identity,@"success":@(closed),@"result":reply}];
      }];
    } else [self readStream:pause identity:identity];
    [self publish];
  }];
}
- (void)resolved:(NSMutableDictionary*)pause identity:(NSString*)identity method:(NSString*)method success:(BOOL)ok result:(NSDictionary*)result {
  [self record:@"decision_result" fields:@{@"pause_id":identity,@"method":method,@"success":@(ok),@"result":result,
    @"meaning":@"Command acceptance only; subsequent Network events describe observed traffic."}];
  if (ok) [_pauses removeObjectForKey:identity];
  else { pause[@"state"] = @"ready"; _status = @"Chromium rejected the decision; the pause remains available for retry/cancel."; }
  [self maybeDisable]; [self publish];
}
- (void)forward:(NSMutableDictionary*)pause identity:(NSString*)identity overrides:(NSDictionary*)overrides {
  if (![pause[@"state"] isEqual:@"ready"]) {
    _status = @"This pause is still reading or submitting. Wait for ready, or use Cancel / Stop."; [self publish]; return;
  }
  NSDictionary* summary = pause[@"summary"];
  BOOL response = [summary[@"response"] boolValue], owned = [pause[@"owned"] boolValue];
  if (owned && ![pause[@"complete"] boolValue]) return;
  NSMutableDictionary* params = [@{@"requestId":summary[@"fetch_id"]} mutableCopy];
  NSString* method = @"Fetch.continueRequest";
  NSMutableDictionary* decision = [NSMutableDictionary dictionaryWithDictionary:overrides ?: @{}];
  NSData* replacement = nil;
  if (overrides[@"body_file"]) {
    NSError* error = nil;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:Text(overrides[@"body_file"]) error:&error];
    if (response && [attributes[NSFileSize] unsignedLongLongValue] > UINT32_MAX) {
      _status = @"Chromium cannot fulfill more than 4,294,967,295 response bytes. Select a smaller replacement or cancel; retained source is untouched.";
      [self publish]; return;
    }
    replacement = [NSData dataWithContentsOfFile:Text(overrides[@"body_file"]) options:0 error:&error];
    if (!replacement) { _status = [@"Cannot read replacement body: " stringByAppendingString:error.localizedDescription ?: @""]; [self publish]; return; }
    if (response && replacement.length > UINT32_MAX) {
      _status = @"Replacement grew beyond Chromium's fulfillment size. Choose another body or cancel."; [self publish]; return;
    }
    NSDictionary* blob = [self blob:replacement representation:@"Operator replacement body bytes"];
    if (![blob[@"available"] boolValue]) return;
    decision[@"body_blob"] = blob; [decision removeObjectForKey:@"body_file"];
  }
  if (response && (owned || overrides.count)) {
    method = @"Fetch.fulfillRequest";
    NSNumber* code = overrides[@"status"] ?: summary[@"status"];
    if (![code isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)code) == CFBooleanGetTypeID() ||
        CFNumberIsFloatType((__bridge CFNumberRef)code) || code.integerValue < 100 || code.integerValue > 599) {
      _status = @"Response status must be an integer from 100 through 599."; [self publish]; return;
    }
    params[@"responseCode"] = code;
    params[@"responseHeaders"] = overrides[@"headers"] ?: summary[@"headers"];
    if (owned && !replacement) {
      uint64_t length = 0;
      for (NSDictionary* chunk in pause[@"chunks"]) {
        uint64_t size = [chunk[@"bytes"] unsignedLongLongValue];
        if (size > UINT32_MAX || length > UINT32_MAX - size) {
          _status = @"Chromium cannot fulfill more than 4,294,967,295 response bytes. The complete upstream data is retained; choose a replacement or cancel.";
          [self publish]; return;
        }
        length += size;
      }
      NSMutableData* all = [NSMutableData data];
      for (NSDictionary* chunk in pause[@"chunks"]) {
        NSData* data = [NSData dataWithContentsOfURL:Child(_directoryURL,Text(chunk[@"path"]))];
        if (!data || data.length != [chunk[@"bytes"] unsignedLongLongValue]) { _status = @"A retained upstream chunk is unreadable or changed; cancel or select a replacement body."; [self publish]; return; }
        [all appendData:data];
      }
      replacement = all;
    }
    if (replacement) {
      params[@"body"] = [replacement base64EncodedStringWithOptions:0];
      // Fulfilled bodies are decoded bytes: stale transfer/compression metadata would corrupt delivery.
      NSMutableArray* headers = [NSMutableArray array];
      for (NSDictionary* header in params[@"responseHeaders"]) {
        if (![@[@"content-length",@"content-encoding",@"transfer-encoding"] containsObject:Text(header[@"name"]).lowercaseString]) [headers addObject:header];
      }
      params[@"responseHeaders"] = headers;
    }
  } else if (!response) {
    for (NSString* key in @[@"url",@"method",@"headers"]) if (overrides[key]) params[key] = overrides[key];
    if (replacement) params[@"postData"] = [replacement base64EncodedStringWithOptions:0];
  }
  id headers = params[@"responseHeaders"] ?: params[@"headers"];
  if (headers && !ValidHeaders(headers)) { _status = @"Invalid header entries."; [self publish]; return; }
  if (!response && params[@"url"]) {
    NSURLComponents* url = [NSURLComponents componentsWithString:Text(params[@"url"])];
    if (![@[@"http",@"https"] containsObject:url.scheme.lowercaseString] || !url.host.length) { _status = @"Enter an HTTP(S) URL."; [self publish]; return; }
  }
  if (!response && params[@"method"] && (!Text(params[@"method"]).length ||
      [Text(params[@"method"]) rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound)) {
    _status = @"Enter a method without whitespace."; [self publish]; return;
  }
  // Save parameters without duplicating the complete base64 body in native metadata.
  NSMutableDictionary* saved = [params mutableCopy];
  [saved removeObjectForKey:@"body"]; [saved removeObjectForKey:@"postData"];
  if (replacement && !decision[@"body_blob"]) decision[@"body_manifest"] = pause[@"body_manifest"] ?: @"";
  NSDictionary* instruction = @{@"pause_id":identity,@"method":method,@"parameters":saved,@"overrides":decision,
    @"at":NSDate.date,@"context":_context,@"armed_revision":_armed ?: @{}};
  if (![self write:instruction path:[NSString stringWithFormat:@"pauses/%@/decisions/%@.bplist",identity,NSUUID.UUID.UUIDString]]) return;
  pause[@"state"] = @"sending";
  // This command's potentially large base64 argument is external-only, never persisted twice.
  [self record:@"decision_submitted" fields:instruction];
  __weak OXTrafficSession* weakSelf = self;
  NSUInteger generation = _generation;
  _transport(method,params,^(BOOL ok, NSDictionary* result) {
    OXTrafficSession* owner = weakSelf; if (!owner) return;
    dispatch_async(owner->_worker,^{ if (!owner->_closed && owner->_generation == generation && owner->_pauses[identity])
      [owner resolved:pause identity:identity method:method success:ok result:result]; });
  });
  [self publish];
}
- (void)forwardPause:(NSString*)identity { dispatch_async(_worker,^{ if (self->_pauses[identity]) [self forward:self->_pauses[identity] identity:identity overrides:nil]; }); }
- (void)applyPause:(NSString*)identity overrides:(NSDictionary*)overrides {
  dispatch_async(_worker,^{ if (self->_pauses[identity]) [self forward:self->_pauses[identity] identity:identity overrides:overrides]; });
}
- (void)cancel:(NSMutableDictionary*)pause identity:(NSString*)identity {
  if ([pause[@"state"] isEqual:@"opening_stream"]) { pause[@"cancel_when_open"] = @YES; return; }
  if ([pause[@"state"] isEqual:@"sending"]) return;
  if (pause[@"stream"] && ![pause[@"complete"] boolValue]) {
    [self saveBody:pause identity:identity outcome:@"cancelled_partial"];
    [self command:@"IO.close" params:@{@"handle":pause[@"stream"]} reply:^(BOOL ok, NSDictionary* result) {
      [self record:@"stream_closed" fields:@{@"pause_id":identity,@"success":@(ok),@"result":result}];
    }];
  }
  pause[@"state"] = @"sending";
  [self command:@"Fetch.failRequest" params:@{@"requestId":pause[@"summary"][@"fetch_id"],@"errorReason":@"Aborted"}
      reply:^(BOOL ok, NSDictionary* result) { if (self->_pauses[identity]) [self resolved:pause identity:identity method:@"Fetch.failRequest" success:ok result:result]; }];
}
- (void)cancelPause:(NSString*)identity { dispatch_async(_worker,^{ if (self->_pauses[identity]) [self cancel:self->_pauses[identity] identity:identity]; }); }
- (void)maybeDisable {
  if (!_stopping || _pauses.count || _fetchChanging || !_fetchEnabled) return;
  _fetchChanging = YES;
  [self command:@"Fetch.disable" params:@{} reply:^(BOOL ok, NSDictionary* result) {
    self->_fetchChanging = NO;
    if (ok) { self->_fetchEnabled = NO; self->_armed = nil; self->_status = @"Passive capture. Editing is disarmed."; }
    [self record:@"disarm_result" fields:@{@"success":@(ok),@"result":result}]; [self publish];
  }];
}
- (void)stop {
  dispatch_async(_worker,^{
    if (self->_closed) return; self->_stopping = YES;
    [self record:@"stop_requested" fields:@{}];
    for (NSString* identity in [self->_pauses.allKeys copy]) {
      NSMutableDictionary* pause = self->_pauses[identity];
      if ([pause[@"owned"] boolValue] && ![pause[@"complete"] boolValue]) [self cancel:pause identity:identity];
      else if (![pause[@"state"] isEqual:@"opening_stream"]) [self forward:pause identity:identity overrides:nil];
    }
    [self maybeDisable]; [self publish];
  });
}
- (void)agentDetached {
  dispatch_async(_worker,^{
    if (self->_closed) return;
    ++self->_generation;
    for (NSString* identity in self->_pauses)
      [self saveBody:self->_pauses[identity] identity:identity outcome:@"agent_detached_partial"];
    for (NSMutableDictionary* request in self->_requests.allValues) if (![request[@"finalized"] boolValue]) {
      request[@"pending_stream"] = @NO; request[@"finished"] = @"agent_detached_partial"; [self finishRequest:request];
    }
    [self->_pauses removeAllObjects]; [self->_requests removeAllObjects];
    self->_armed = nil; self->_fetchEnabled = NO; self->_fetchChanging = NO; self->_stopping = NO;
    [self record:@"agent_detached" fields:@{}];
    self->_status = @"Traffic capture detached. Resume capture to reattach; editing is disarmed."; [self publish];
  });
}
- (void)closeWithCompletion:(void (^)(void))completion {
  dispatch_async(_worker,^{
    if (!self->_closed) {
      for (NSString* identity in self->_pauses) {
        NSMutableDictionary* pause = self->_pauses[identity];
        [self saveBody:pause identity:identity outcome:@"browser_closed_partial"];
      }
      for (NSMutableDictionary* request in self->_requests.allValues) {
        if (![request[@"finalized"] boolValue]) {
          request[@"pending_stream"] = @NO; request[@"finished"] = @"browser_closed_partial"; [self finishRequest:request];
        }
      }
      [self record:@"closed" fields:@{}]; self->_closed = YES; [self->_pauses removeAllObjects];
      self->_status = @"Browser closed; traffic retained."; [self publish]; self->_transport = nil;
    }
    dispatch_async(dispatch_get_main_queue(),completion);
  });
}
@end
