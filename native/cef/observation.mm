#import "observation.h"
#include "include/cef_devtools_message_observer.h"
#include "include/wrapper/cef_helpers.h"
#include <atomic>
#include <cmath>
#include <signal.h>
#include <mach/mach_time.h>

namespace {
uint64_t NowNanos() {
  static const auto scale = [] { mach_timebase_info_data_t x; mach_timebase_info(&x); return x; }();
  return static_cast<uint64_t>(static_cast<long double>(mach_continuous_time()) * scale.numer / scale.denom);
}
bool Integer(id value, int64_t& output) {
  if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return false;
  const char* type = [value objCType];
  if (type[0] == 'd' || type[0] == 'f') return false;
  output = [value longLongValue]; return true;
}
bool Index(id value, NSUInteger count, NSUInteger& index) {
  int64_t number;
  if (!Integer(value, number) || number < 0 || static_cast<uint64_t>(number) >= count) return false;
  index = static_cast<NSUInteger>(number); return true;
}
NSString* String(NSArray* strings, id index) {
  int64_t number;
  // Matched Blink AddString represents an empty string with sentinel -1.
  if (Integer(index, number) && number == -1) return @"";
  NSUInteger i;
  return Index(index, strings.count, i) && [strings[i] isKindOfClass:NSString.class] ? strings[i] : nil;
}
bool Secret(NSString* text, NSArray<NSString*>* markers) {
  for (NSString* marker in markers) if ([text containsString:marker]) return true;
  return false;
}
NSDictionary* Gap(NSString* reason) { return @{@"status": @"withheld", @"reason": reason, @"fields": @[]}; }
NSDictionary* Dictionary(id value) { return [value isKindOfClass:NSDictionary.class] ? value : nil; }

// Only this host-owned, reviewed fixture field projection leaves the worker.
NSDictionary* Project(NSDictionary* snapshot, NSString* rootFrame,
                     NSArray<NSString*>* ids, NSArray<NSString*>* markers) {
  NSArray* strings = snapshot[@"strings"], *documents = snapshot[@"documents"];
  if (![strings isKindOfClass:NSArray.class] || strings.count > 8192 ||
      ![documents isKindOfClass:NSArray.class] || documents.count > 64) return Gap(@"snapshot_shape_or_limit");
  for (id value in strings) if (![value isKindOfClass:NSString.class] || [value length] > 16384) return Gap(@"string_limit");
  NSDictionary* document = nil;
  for (id item in documents) {
    if (![item isKindOfClass:NSDictionary.class]) return Gap(@"snapshot_shape");
    if ([String(strings, item[@"frameId"]) isEqual:rootFrame]) {
      if (document) return Gap(@"ambiguous_root_document");
      document = item;
    }
  }
  if (!document) return Gap(@"root_document_missing");
  NSDictionary* nodes = document[@"nodes"], *layout = document[@"layout"];
  if (![nodes isKindOfClass:NSDictionary.class] || ![layout isKindOfClass:NSDictionary.class]) return Gap(@"snapshot_shape");
  NSArray* parents = nodes[@"parentIndex"], *types = nodes[@"nodeType"], *names = nodes[@"nodeName"],
      *backend = nodes[@"backendNodeId"], *attributes = nodes[@"attributes"];
  if (![parents isKindOfClass:NSArray.class] || parents.count == 0 || parents.count > 4096) return Gap(@"node_limit");
  NSUInteger count = parents.count;
  for (id column in @[types ?: NSNull.null, names ?: NSNull.null, backend ?: NSNull.null, attributes ?: NSNull.null])
    if (![column isKindOfClass:NSArray.class] || [column count] != count) return Gap(@"node_shape");
  NSMutableArray* nodeNames = [NSMutableArray arrayWithCapacity:count];
  NSMutableArray* nodeIds = [NSMutableArray arrayWithCapacity:count];
  for (NSUInteger i = 0; i < count; ++i) {
    int64_t parent, type, backendId;
    NSString* name = String(strings, names[i]);
    if (!Integer(parents[i], parent) || parent < -1 || parent >= static_cast<int64_t>(i) ||
        (i && parent < 0) || !Integer(types[i], type) || !Integer(backend[i], backendId) || backendId <= 0 || !name)
      return Gap(@"node_shape");
    [nodeNames addObject:name];
    if ([@[@"FORM", @"INPUT", @"TEXTAREA", @"SELECT"] containsObject:name]) return Gap(@"form_region_withheld");
    NSArray* attrs = attributes[i];
    if (![attrs isKindOfClass:NSArray.class] || attrs.count % 2) return Gap(@"attribute_shape");
    NSString* fieldId = @"";
    for (NSUInteger a = 0; a < attrs.count; a += 2) {
      NSString* key = String(strings, attrs[a]), *value = String(strings, attrs[a+1]);
      if (!key || !value) return Gap(@"attribute_shape");
      if ([key isEqual:@"id"]) fieldId = value;
    }
    [nodeIds addObject:fieldId];
  }
  NSArray* indexes = layout[@"nodeIndex"], *styles = layout[@"styles"], *bounds = layout[@"bounds"], *texts = layout[@"text"];
  if (![indexes isKindOfClass:NSArray.class] || indexes.count > 8192) return Gap(@"layout_limit");
  for (id column in @[styles ?: NSNull.null, bounds ?: NSNull.null, texts ?: NSNull.null])
    if (![column isKindOfClass:NSArray.class] || [column count] != indexes.count) return Gap(@"layout_shape");
  NSMutableDictionary* byNode = [NSMutableDictionary dictionary];
  for (NSUInteger i = 0; i < indexes.count; ++i) {
    NSUInteger node;
    if (!Index(indexes[i], count, node) || byNode[@(node)]) return Gap(@"layout_shape");
    NSArray* style = styles[i], *rectangle = bounds[i];
    if (![style isKindOfClass:NSArray.class] || (style.count != 3 && !(style.count == 0 && [types[node] intValue] == 9)) ||
        ![rectangle isKindOfClass:NSArray.class] || rectangle.count != 4) return Gap(@"layout_shape");
    NSMutableArray* css = [NSMutableArray array];
    for (id index in style) { NSString* value = String(strings, index); if (!value) return Gap(@"layout_shape"); [css addObject:value]; }
    for (id number in rectangle)
      if (![number isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID() || !std::isfinite([number doubleValue])) return Gap(@"layout_shape");
    NSString* text = String(strings, texts[i]);
    if (!text) return Gap(@"layout_shape");
    byNode[@(node)] = @{@"css": css, @"bounds": rectangle, @"text": text};
  }
  NSSet* excluded = [NSSet setWithArray:@[@"SCRIPT", @"STYLE", @"HEAD", @"IFRAME", @"CANVAS", @"VIDEO", @"AUDIO", @"OBJECT", @"EMBED"]];
  NSUInteger visits = 0;
  bool exhausted = false;
  auto supported = [&](NSUInteger index) {
    int64_t current = index;
    while (current >= 0) {
      if (++visits > 100000) { exhausted = true; return false; }
      if ([excluded containsObject:nodeNames[current]]) return false;
      NSDictionary* box = byNode[@(current)];
      if (box) {
        NSArray* css = box[@"css"];
        if (css.count && ([css[0] isEqual:@"none"] || [@[@"hidden", @"collapse"] containsObject:css[1]] || [css[2] doubleValue] <= 0)) return false;
      }
      current = [parents[current] longLongValue];
    }
    return byNode[@(index)] != nil;
  };
  NSMutableArray* fields = [NSMutableArray array];
  NSUInteger totalBytes = 0;
  for (NSString* fieldId in ids) {
    NSMutableArray* matches = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; ++i) if ([nodeIds[i] isEqual:fieldId]) [matches addObject:@(i)];
    NSString* reason = nil;
    NSUInteger selected = matches.count == 1 ? [matches[0] unsignedIntegerValue] : 0;
    if (matches.count != 1) reason = matches.count ? @"ambiguous_field" : @"missing_field";
    else if (!supported(selected)) reason = @"hidden_or_unsupported";
    NSMutableString* text = [NSMutableString string];
    if (!reason) {
      for (NSUInteger i = selected + 1; i < count; ++i) {
        int64_t ancestor = [parents[i] longLongValue];
        while (ancestor > static_cast<int64_t>(selected)) {
          if (++visits > 100000) return Gap(@"projection_work_limit");
          ancestor = [parents[ancestor] longLongValue];
        }
        if (ancestor != static_cast<int64_t>(selected) || [types[i] intValue] != 3 || !supported(i)) continue;
        [text appendString:byNode[@(i)][@"text"]];
        if ([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 2048) { reason = @"field_limit"; break; }
      }
      if (!reason && Secret(text, markers)) reason = @"known_secret_echo";
      if (!reason && text.length == 0) reason = @"text_unavailable";
    }
    if (exhausted) return Gap(@"projection_work_limit");
    if (reason) [fields addObject:@{@"field_id": fieldId, @"status": @"withheld", @"reason": reason}];
    else {
      totalBytes += [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
      if (totalBytes > 16384) return Gap(@"projection_limit");
      [fields addObject:@{@"field_id": fieldId, @"status": @"observed", @"text": text,
          @"node_index": @(selected), @"backend_node_id": backend[selected],
          @"bounds": byNode[@(selected)][@"bounds"], @"visibility": @"layout-present-occlusion-unknown"}];
    }
  }
  return @{@"status": @"partial", @"fields": fields, @"node_count": @(count)};
}
}

@interface BSNativeObservation ()
- (void)receiveBytes:(const void*)bytes size:(size_t)size;
- (void)agentChanged:(BOOL)attached;
@end

namespace {
class Observer final : public CefDevToolsMessageObserver {
 public:
  explicit Observer(BSNativeObservation* owner) : owner_(owner) {}
  bool OnDevToolsMessage(CefRefPtr<CefBrowser>, const void* message, size_t size) override {
    [owner_ receiveBytes:message size:size]; return true;
  }
  void OnDevToolsAgentAttached(CefRefPtr<CefBrowser>) override { [owner_ agentChanged:YES]; }
  void OnDevToolsAgentDetached(CefRefPtr<CefBrowser>) override { [owner_ agentChanged:NO]; }
 private:
  __weak BSNativeObservation* owner_;
  IMPLEMENT_REFCOUNTING(Observer);
};
std::atomic<int> nextId{1000000};
}

@implementation BSNativeObservation {
  CefRefPtr<CefBrowser> _browser;
  CefRefPtr<CefRegistration> _registration;
  NSString* _runId, *_surfaceId, *_origin, *_captureId;
  NSArray<NSString*>* _fieldIds, *_markers;
  dispatch_queue_t _worker;
  std::atomic<size_t> _queuedBytes;
  std::atomic<unsigned> _queuedCount;
  NSMutableDictionary* _contexts;
  NSDictionary* _before, *_projection, *_runtime;
  void (^_completion)(NSDictionary*);
  uint64_t _revision, _attachment, _activation, _nodeGeneration, _captureRevision, _start;
  int _phase, _pendingId;
  BOOL _closed, _blocked, _projectionInFlight, _pauseAtFixtureStartForTesting;
}
@synthesize pauseAtFixtureStartForTesting = _pauseAtFixtureStartForTesting;
- (instancetype)initWithBrowser:(CefRefPtr<CefBrowser>)browser runId:(NSString*)runId
    surfaceId:(NSString*)surfaceId allowedOrigin:(NSString*)origin
    fieldIds:(NSArray<NSString*>*)fieldIds secretMarkers:(NSArray<NSString*>*)markers {
  CEF_REQUIRE_UI_THREAD();
  self = [super init];
  if (self) {
    _browser = browser; _runId = [runId copy]; _surfaceId = [surfaceId copy]; _origin = [origin copy];
    _fieldIds = [fieldIds copy]; _markers = [markers copy];
    _contexts = [NSMutableDictionary dictionary]; _revision = _attachment = _activation = _nodeGeneration = 1;
    _worker = dispatch_queue_create("dev.bowshock.fixture-observation", DISPATCH_QUEUE_SERIAL);
    NSURLComponents* url = [NSURLComponents componentsWithString:origin];
    if (!browser || runId.length == 0 || runId.length > 128 || surfaceId.length == 0 || surfaceId.length > 128 ||
        ![url.scheme isEqual:@"http"] || ![@[@"127.0.0.1", @"localhost", @"::1"] containsObject:url.host] ||
        url.user || url.password || url.query || url.fragment || (url.path.length && ![url.path isEqual:@"/"]) ||
        fieldIds.count == 0 || fieldIds.count > 32 || markers.count > 16) _closed = YES;
    for (NSString* value in markers)
      if (![value isKindOfClass:NSString.class] || value.length == 0 || value.length > 128) _closed = YES;
    for (NSString* value in fieldIds)
      if (![value isKindOfClass:NSString.class] || value.length == 0 || value.length > 64 || (!_closed && Secret(value, markers))) _closed = YES;
    if ([NSSet setWithArray:fieldIds].count != fieldIds.count) _closed = YES;
    if (!_closed) _registration = browser->GetHost()->AddDevToolsMessageObserver(new Observer(self));
  }
  return self;
}
- (void)captureFixtureWithCompletion:(void (^)(NSDictionary*))completion {
  CEF_REQUIRE_UI_THREAD();
  if (_closed || _completion || _blocked || _pendingId || _projectionInFlight) {
    completion(@{@"status": @"failed", @"reason": _closed ? @"closed_or_scope_invalid" : @"busy_or_native_unresolved", @"fixture_only": @YES, @"fields": @[]}); return;
  }
  _completion = [completion copy]; _captureId = NSUUID.UUID.UUIDString; _start = NowNanos();
  _before = nil; _projection = nil; _runtime = nil; _phase = 0;
  // Development-only owned fixture stage; no raw page content is logged.
  fprintf(stderr, "BS_OBSERVATION_CAPTURE_STARTED\n"); fflush(stderr);
  if (_pauseAtFixtureStartForTesting) raise(SIGSTOP);
  [self sendNext];
  NSString* captureId = _captureId;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    if (self->_completion && [self->_captureId isEqual:captureId]) {
      [self checkDeadline];
    }
  });
}
- (BOOL)checkDeadline {
  if (!_completion || NowNanos() - _start < 3 * NSEC_PER_SEC) return NO;
  _blocked = _pendingId != 0;
  [self fail:@"host_timeout_native_work_not_cancelled"];
  return YES;
}
- (void)sendNext {
  if (!_completion || _closed || [self checkDeadline]) return;
  static NSArray<NSString*>* methods = @[@"Page.enable", @"Runtime.enable", @"DOM.enable", @"Browser.getVersion", @"Page.getFrameTree", @"DOMSnapshot.captureSnapshot", @"Page.getFrameTree"];
  int id = nextId.fetch_add(1);
  if (id <= 0 || id == INT_MAX) { [self fail:@"message_id_exhausted"]; return; }
  _pendingId = id;
  NSDictionary* params = _phase == 5 ? @{@"computedStyles": @[@"display", @"visibility", @"opacity"]} : @{};
  NSData* bytes = [NSJSONSerialization dataWithJSONObject:@{@"id": @(id), @"method": methods[_phase], @"params": params} options:0 error:nil];
  if (!_browser->GetHost()->SendDevToolsMessage(bytes.bytes, bytes.length)) { _pendingId = 0; [self fail:@"native_dispatch_failed"]; }
}
- (void)receiveBytes:(const void*)bytes size:(size_t)size {
  CEF_REQUIRE_UI_THREAD();
  if (_closed) return;
  if (size > 1048576 || _queuedBytes.load() + size > 2097152 || _queuedCount.load() >= 64) {
    _blocked = _pendingId != 0; [self fail:@"callback_copy_or_queue_limit"]; return;
  }
  NSData* copy = [NSData dataWithBytes:bytes length:size];
  _queuedBytes.fetch_add(size); _queuedCount.fetch_add(1);
  dispatch_async(_worker, ^{
    @autoreleasepool {
      id decoded = [NSJSONSerialization JSONObjectWithData:copy options:0 error:nil];
      dispatch_async(dispatch_get_main_queue(), ^{
        [self handle:decoded];
        self->_queuedBytes.fetch_sub(size); self->_queuedCount.fetch_sub(1);
      });
    }
  });
}
- (void)handle:(id)message {
  CEF_REQUIRE_UI_THREAD();
  if (_closed) return;
  // A late matching response still reconciles native ownership below, but
  // cannot advance a capture after a delayed main-queue deadline timer.
  [self checkDeadline];
  if (![message isKindOfClass:NSDictionary.class] || message[@"sessionId"]) { [self fail:@"unsupported_or_malformed_envelope"]; return; }
  NSString* method = message[@"method"];
  NSDictionary* params = message[@"params"];
  if (method) {
    if (![method isKindOfClass:NSString.class] || ![params isKindOfClass:NSDictionary.class]) return;
    if ([method isEqual:@"Runtime.executionContextCreated"]) {
      NSDictionary* context = Dictionary(params[@"context"]), *aux = Dictionary(context[@"auxData"]);
      id isDefault = aux[@"isDefault"];
      NSString* frame = aux[@"frameId"], *origin = context[@"origin"];
      int64_t contextId;
      if ([context isKindOfClass:NSDictionary.class] && [aux isKindOfClass:NSDictionary.class] &&
          isDefault && CFGetTypeID((__bridge CFTypeRef)isDefault) == CFBooleanGetTypeID() && [isDefault boolValue] &&
          [aux[@"type"] isEqual:@"default"] && [frame isKindOfClass:NSString.class] && frame.length <= 128 &&
          [origin isKindOfClass:NSString.class] && origin.length <= 1024 && Integer(context[@"id"], contextId)) {
        if (_contexts.count >= 64) { [_contexts removeAllObjects]; [self nativeLifecycle:@"context_limit"]; return; }
        NSDictionary* old = _contexts[frame];
        _contexts[frame] = old && ![old[@"id"] isEqual:@(contextId)] ? @{@"origin": @"", @"id": @(-1)} : @{@"origin": origin, @"id": @(contextId)};
        [self nativeLifecycle:@"context_created"];
      }
    } else if ([method isEqual:@"Runtime.executionContextsCleared"] || [method isEqual:@"Runtime.executionContextDestroyed"]) {
      [_contexts removeAllObjects]; [self nativeLifecycle:@"context_invalidated"];
    } else if ([@[@"Page.frameNavigated", @"Page.frameDetached", @"Page.frameAttached", @"Page.navigatedWithinDocument", @"DOM.documentUpdated"] containsObject:method]) {
      [self nativeLifecycle:method];
    }
    return;
  }
  int64_t id;
  if (_pendingId <= 0 || !Integer(message[@"id"], id) || id != _pendingId) return;
  _pendingId = 0; _blocked = NO;
  if (!_completion) return;
  if (message[@"error"] || ![message[@"result"] isKindOfClass:NSDictionary.class]) { [self fail:@"native_method_failed"]; return; }
  NSDictionary* result = message[@"result"];
  if (_phase == 3) {
    if (![result[@"product"] isKindOfClass:NSString.class] || ![result[@"protocolVersion"] isKindOfClass:NSString.class]) { [self fail:@"runtime_identity_missing"]; return; }
    _runtime = @{@"product": result[@"product"], @"protocol_version": result[@"protocolVersion"]};
  } else if (_phase == 4) {
    NSDictionary* frame = Dictionary(Dictionary(result[@"frameTree"])[@"frame"]);
    NSString* frameId = frame[@"id"], *loader = frame[@"loaderId"];
    if (![frame isKindOfClass:NSDictionary.class] || ![frameId isKindOfClass:NSString.class] || frameId.length == 0 ||
        ![loader isKindOfClass:NSString.class] || loader.length == 0) {
      [self fail:@"effective_origin_or_document_unverified"]; return;
    }
    NSDictionary* context = _contexts[frameId];
    if (![context[@"origin"] isEqual:_origin]) { [self fail:@"effective_origin_or_document_unverified"]; return; }
    _before = @{@"frame_id": frameId, @"loader_id": loader, @"context_id": context[@"id"]};
    _captureRevision = _revision;
  } else if (_phase == 5) {
    NSString* captureId = _captureId, *frame = _before[@"frame_id"];
    _projectionInFlight = YES;
    dispatch_async(_worker, ^{
      NSDictionary* projected = Project(result, frame, self->_fieldIds, self->_markers);
      dispatch_async(dispatch_get_main_queue(), ^{
        self->_projectionInFlight = NO;
        if (!self->_closed && self->_completion && [self->_captureId isEqual:captureId]) {
          self->_projection = projected; self->_phase = 6; [self sendNext];
        }
      });
    });
    return;
  } else if (_phase == 6) {
    NSDictionary* frame = Dictionary(Dictionary(result[@"frameTree"])[@"frame"]);
    NSDictionary* context = _contexts[_before[@"frame_id"]];
    if (_captureRevision != _revision || ![frame[@"id"] isEqual:_before[@"frame_id"]] ||
        ![frame[@"loaderId"] isEqual:_before[@"loader_id"]] || ![context[@"id"] isEqual:_before[@"context_id"]] ||
        ![context[@"origin"] isEqual:_origin]) { [self fail:@"changed_during_capture"]; return; }
    [self publish]; return;
  }
  ++_phase; [self sendNext];
}
- (void)publish {
  if (!_completion || _closed || [self checkDeadline]) return;
  CefRefPtr<CefFrame> cefFrame = _browser->GetMainFrame();
  if (!cefFrame || !cefFrame->IsValid()) { [self fail:@"native_main_frame_missing"]; return; }
  NSString* cefId = [NSString stringWithUTF8String:cefFrame->GetIdentifier().ToString().c_str()];
  NSString* document = [NSString stringWithFormat:@"%@:%llu", _before[@"loader_id"], _revision];
  NSDictionary* ref = @{@"run_id": _runId, @"surface_id": _surfaceId, @"browser_id": @(_browser->GetIdentifier()),
      @"target_namespace": @"cef-browser-cdp-root", @"attachment_generation": @(_attachment),
      @"frame_id": _before[@"frame_id"], @"cef_main_frame_id": cefId, @"cef_frame_namespace_join": @"root-browser-association-only",
      @"document_id": document, @"activation_generation": @(_activation), @"node_generation": @(_nodeGeneration),
      @"capture_id": _captureId, @"capture_start_continuous_ns": @(_start), @"capture_end_continuous_ns": @(NowNanos()),
      @"presentation_uncertainty": @"native-layout-only-screen-mapping-unverified",
      @"origin": @{@"kind": @"tuple", @"security_origin": _origin, @"provenance": @"Runtime.executionContextCreated.defaultContext"}};
  NSMutableDictionary* output = [_projection mutableCopy];
  output[@"observation_ref"] = ref; output[@"fixture_only"] = @YES; output[@"general_observation_enabled"] = @NO;
  output[@"runtime"] = _runtime; output[@"coverage"] = @{@"child_frames": @"withheld", @"cef_frame_count": @(_browser->GetFrameCount()),
      @"scope": @"root-only", @"atomic": @NO, @"ax": @"not_captured", @"pixels": @"withheld", @"actionable_geometry": @NO};
  // Check at the final publication boundary too, after native frame reads.
  if ([self checkDeadline]) return;
  void (^completion)(NSDictionary*) = _completion;
  _completion = nil; _projection = nil; _before = nil;
  completion(output);
}
- (void)fail:(NSString*)reason {
  if (!_completion) return;
  void (^completion)(NSDictionary*) = _completion;
  _completion = nil; _projection = nil; _before = nil;
  completion(@{@"status": @"failed", @"reason": reason, @"fixture_only": @YES, @"general_observation_enabled": @NO, @"fields": @[]});
}
- (void)nativeLifecycle:(NSString*)reason {
  CEF_REQUIRE_UI_THREAD();
  (void)reason;
  if (_closed) return;
  if (_revision == UINT64_MAX || _nodeGeneration == UINT64_MAX || _activation == UINT64_MAX) {
    [self fail:@"identity_generation_exhausted"]; [self close]; return;
  }
  ++_revision; ++_nodeGeneration; ++_activation;
  if (_completion && _phase >= 4) { _blocked = _pendingId != 0; [self fail:@"lifecycle_invalidated"]; }
}
- (void)agentChanged:(BOOL)attached {
  CEF_REQUIRE_UI_THREAD();
  if (_closed) return;
  if (_attachment == UINT64_MAX) { [self fail:@"attachment_generation_exhausted"]; [self close]; return; }
  ++_attachment; [_contexts removeAllObjects]; [self nativeLifecycle:@"agent_changed"];
  if (!attached) { _pendingId = 0; _blocked = NO; [self fail:@"agent_detached"]; }
}
- (void)close {
  CEF_REQUIRE_UI_THREAD();
  if (!_closed) [self fail:@"browser_closed"];
  _closed = YES; _registration = nullptr; _browser = nullptr; [_contexts removeAllObjects];
}
@end
