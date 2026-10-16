#import "live_observation.h"
#include "include/cef_devtools_message_observer.h"
#include "include/wrapper/cef_helpers.h"
#include <atomic>
#include <cmath>
#include <mach/mach_time.h>
#include <vector>

@interface BSLiveTextBlock ()
@property(nonatomic) int64_t backendNodeId;
@property(nonatomic, copy) NSString* tagName;
@property(nonatomic, copy) NSString* text;
@property(nonatomic, copy) NSString* linkURL;
@property(nonatomic) NSRect bounds;
@end
@implementation BSLiveTextBlock
@end

@interface BSLivePage ()
@property(nonatomic, copy) NSString* url;
@property(nonatomic, copy) NSString* title;
@property(nonatomic, copy) NSString* text;
@property(nonatomic, copy) NSString* origin;
@property(nonatomic, copy) NSString* frameId;
@property(nonatomic, copy) NSString* documentId;
@property(nonatomic, copy) NSString* captureId;
@property(nonatomic) uint64_t captureStartNanos;
@property(nonatomic) uint64_t captureEndNanos;
@property(nonatomic) BOOL truncated;
@property(nonatomic) NSUInteger nodeCount;
@property(nonatomic) NSUInteger childFrameCount;
@property(nonatomic, copy) NSArray<BSLiveTextBlock*>* blocks;
@property(nonatomic, copy) NSArray<NSString*>* coverage;
@end
@implementation BSLivePage
@end

// These are native protocol-adapter values. Decoded JSON never crosses the
// worker boundary or becomes a stored page/capture model.
@interface BSLiveFrame : NSObject
@property(nonatomic, copy) NSString* url;
@property(nonatomic, copy) NSString* origin;
@property(nonatomic, copy) NSString* frameId;
@property(nonatomic, copy) NSString* loaderId;
@property(nonatomic) NSUInteger childFrameCount;
@end
@implementation BSLiveFrame
@end

@interface BSLiveReply : NSObject
@property(nonatomic) int messageId;
@property(nonatomic, copy) NSString* error;
@property(nonatomic, strong) BSLiveFrame* frame;
@property(nonatomic, strong) BSLivePage* page;
@end
@implementation BSLiveReply
@end

namespace {
constexpr size_t kMessageBytes = 24 * 1024 * 1024;
constexpr NSUInteger kOutputBytes = 32768, kBlockBytes = 2048, kBlocks = 256;
constexpr uint64_t kDeadlineNanos = 10 * NSEC_PER_SEC;
std::atomic<int> nextMessageId{2000000};
uint64_t NowNanos() {
  static const auto scale = [] { mach_timebase_info_data_t x; mach_timebase_info(&x); return x; }();
  return static_cast<uint64_t>(static_cast<long double>(mach_continuous_time()) * scale.numer / scale.denom);
}
NSDictionary* Dict(id value) { return [value isKindOfClass:NSDictionary.class] ? value : nil; }
NSArray* Array(id value) { return [value isKindOfClass:NSArray.class] ? value : nil; }
NSString* Text(id value) { return [value isKindOfClass:NSString.class] ? value : nil; }
bool Integer(id value, int64_t& out) {
  if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return false;
  const char* type = [value objCType];
  if (type[0] == 'd' || type[0] == 'f') return false;
  out = [value longLongValue]; return true;
}
bool Index(id value, NSUInteger size, NSUInteger& out) {
  int64_t number;
  if (!Integer(value, number) || number < 0 || static_cast<uint64_t>(number) >= size) return false;
  out = static_cast<NSUInteger>(number); return true;
}
NSString* Intern(NSArray* strings, id index) {
  int64_t number;
  if (Integer(index, number) && number == -1) return @"";
  NSUInteger i;
  return Index(index, strings.count, i) ? Text(strings[i]) : nil;
}
NSString* Bounded(NSString* value, NSUInteger bytes, BOOL& truncated) {
  NSData* data = [value dataUsingEncoding:NSUTF8StringEncoding];
  if (!data) { truncated = YES; return @""; }
  if (data.length <= bytes) return value;
  truncated = YES;
  const uint8_t* buffer = static_cast<const uint8_t*>(data.bytes);
  while (bytes && (buffer[bytes] & 0xc0) == 0x80) --bytes;
  return [[NSString alloc] initWithBytes:buffer length:bytes encoding:NSUTF8StringEncoding] ?: @"";
}
NSString* HTTPURL(NSString* value, NSString* base = nil) {
  if (!value || value.length > 8192) return @"";
  NSURL* url = base ? [NSURL URLWithString:value relativeToURL:[NSURL URLWithString:base]] : [NSURL URLWithString:value];
  if (!url.absoluteURL) return @"";
  NSURLComponents* parts = [NSURLComponents componentsWithURL:url.absoluteURL resolvingAgainstBaseURL:YES];
  if (![@[@"http", @"https"] containsObject:parts.scheme.lowercaseString] || !parts.host.length) return @"";
  parts.user = nil; parts.password = nil;
  return parts.string ?: @"";
}
BSLiveFrame* ReadFrame(NSDictionary* result, NSString** error) {
  NSDictionary* tree = Dict(result[@"frameTree"]), *frame = Dict(tree[@"frame"]);
  NSString* frameId = Text(frame[@"id"]), *loader = Text(frame[@"loaderId"]), *origin = Text(frame[@"securityOrigin"]);
  NSString* url = HTTPURL(Text(frame[@"url"]));
  if (!frameId.length || frameId.length > 256 || !loader.length || loader.length > 256 ||
      !origin.length || origin.length > 2048 || !url.length) {
    *error = @"Current root document has no readable HTTP(S) frame identity."; return nil;
  }
  BSLiveFrame* native = [BSLiveFrame new];
  native.url = url; native.origin = origin; native.frameId = frameId; native.loaderId = loader;
  // Count descendants without trusting a recursively deep external structure.
  NSMutableArray* pending = [NSMutableArray arrayWithArray:Array(tree[@"childFrames"]) ?: @[]];
  NSUInteger visited = 0;
  while (pending.count && visited < 4096) {
    NSDictionary* child = Dict(pending.lastObject); [pending removeLastObject]; ++visited;
    NSArray* descendants = Array(child[@"childFrames"]);
    if (descendants.count > 4096 - MIN(pending.count, 4096UL)) break;
    if (descendants) [pending addObjectsFromArray:descendants];
  }
  native.childFrameCount = visited;
  return native;
}

BSLivePage* Project(NSDictionary* result, BSLiveFrame* frame, NSString** error) {
  auto fail = [&](NSString* message) -> BSLivePage* { *error = message; return nil; };
  NSArray* strings = Array(result[@"strings"]), *documents = Array(result[@"documents"]);
  if (!strings || !documents || strings.count > 400000 || documents.count > 4096)
    return fail(@"DOM snapshot exceeds the string/document bound or is malformed.");
  NSDictionary* document = nil;
  for (id item in documents) {
    NSDictionary* candidate = Dict(item);
    if ([Intern(strings, candidate[@"frameId"]) isEqual:frame.frameId]) {
      if (document) return fail(@"DOM snapshot contains multiple root documents.");
      document = candidate;
    }
  }
  if (!document) return fail(@"Root document is absent from the DOM snapshot; retry after navigation.");
  NSDictionary* nodes = Dict(document[@"nodes"]), *layout = Dict(document[@"layout"]);
  NSArray* parents = Array(nodes[@"parentIndex"]), *names = Array(nodes[@"nodeName"]),
      *types = Array(nodes[@"nodeType"]), *backend = Array(nodes[@"backendNodeId"]),
      *attributes = Array(nodes[@"attributes"]);
  NSUInteger count = parents.count;
  if (!count || count > 200000 || names.count != count || types.count != count || backend.count != count || attributes.count != count)
    return fail(@"DOM snapshot exceeds the node bound or has inconsistent columns.");
  NSArray* indexes = Array(layout[@"nodeIndex"]), *styles = Array(layout[@"styles"]),
      *bounds = Array(layout[@"bounds"]), *texts = Array(layout[@"text"]);
  if (!indexes || indexes.count > 200000 || styles.count != indexes.count || bounds.count != indexes.count || texts.count != indexes.count)
    return fail(@"DOM snapshot has inconsistent layout columns.");
  std::vector<int64_t> parent(count), type(count), backendId(count), layoutFor(count, -1);
  std::vector<bool> excluded(count, false);
  NSMutableArray<NSString*>* tags = [NSMutableArray arrayWithCapacity:count];
  NSMutableArray<NSString*>* links = [NSMutableArray arrayWithCapacity:count];
  NSString* base = Intern(strings, document[@"baseURL"]) ?: frame.url;
  NSSet* excludedTags = [NSSet setWithArray:@[@"HEAD", @"SCRIPT", @"STYLE", @"TEMPLATE", @"NOSCRIPT", @"INPUT", @"TEXTAREA", @"IFRAME", @"OBJECT", @"EMBED"]];
  NSUInteger attributeVisits = 0;
  for (NSUInteger i = 0; i < count; ++i) {
    NSString* tag = [Intern(strings, names[i]) uppercaseString];
    NSArray* attrs = Array(attributes[i]);
    if (!Integer(parents[i], parent[i]) || parent[i] < -1 || parent[i] >= static_cast<int64_t>(i) ||
        !Integer(types[i], type[i]) || !Integer(backend[i], backendId[i]) || backendId[i] <= 0 || !tag || !attrs || attrs.count % 2)
      return fail(@"DOM snapshot contains an invalid node.");
    BOOL omit = [excludedTags containsObject:tag];
    NSString* href = @"";
    for (NSUInteger a = 0; a < attrs.count; a += 2) {
      if (++attributeVisits > 1000000) return fail(@"DOM snapshot attribute work bound reached.");
      NSString* key = Intern(strings, attrs[a]), *value = Intern(strings, attrs[a + 1]);
      if (!key || !value) return fail(@"DOM snapshot contains an invalid attribute.");
      if ([key isEqual:@"href"] && [tag isEqual:@"A"]) href = HTTPURL(value, base);
      if ([key isEqual:@"type"] && [value.lowercaseString isEqual:@"password"]) omit = YES;
    }
    excluded[i] = omit;
    [tags addObject:tag]; [links addObject:href];
  }
  for (NSUInteger i = 0; i < indexes.count; ++i) {
    NSUInteger node;
    NSArray* css = Array(styles[i]), *rectangle = Array(bounds[i]);
    if (!Index(indexes[i], count, node) || layoutFor[node] != -1 || !css || (css.count != 3 && css.count != 0) || rectangle.count != 4 || !Intern(strings, texts[i]))
      return fail(@"DOM snapshot contains an invalid layout row.");
    for (id number in rectangle) {
      if (![number isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID() || !std::isfinite([number doubleValue]))
        return fail(@"DOM snapshot contains an invalid layout rectangle.");
    }
    if (css.count) {
      NSString* display = Intern(strings, css[0]), *visibility = Intern(strings, css[1]), *opacity = Intern(strings, css[2]);
      if (!display || !visibility || !opacity) return fail(@"DOM snapshot contains an invalid style.");
      // Visibility can be overridden by descendants; inspect it on text nodes
      // below, while display/opacity exclude the whole subtree.
      if ([display isEqual:@"none"] || opacity.doubleValue <= 0) excluded[node] = true;
    }
    layoutFor[node] = static_cast<int64_t>(i);
  }
  // Parent-first DOM order makes subtree exclusion/link inheritance linear.
  for (NSUInteger i = 0; i < count; ++i) {
    if (parent[i] < 0) continue;
    NSUInteger p = static_cast<NSUInteger>(parent[i]);
    excluded[i] = excluded[i] || excluded[p];
    if (!links[i].length) links[i] = links[p];
  }
  BSLivePage* page = [BSLivePage new];
  BOOL truncated = NO;
  page.url = frame.url; page.title = Bounded(Intern(strings, document[@"title"]) ?: @"", 2048, truncated);
  page.origin = frame.origin; page.frameId = frame.frameId; page.documentId = frame.loaderId;
  page.nodeCount = count; page.childFrameCount = frame.childFrameCount;
  NSMutableArray<BSLiveTextBlock*>* blocks = [NSMutableArray array];
  NSMutableString* joined = [NSMutableString string];
  NSUInteger outputBytes = 0;
  for (NSUInteger node = 0; node < count; ++node) {
    if (excluded[node] || type[node] != 3 || layoutFor[node] < 0) continue;
    NSUInteger row = static_cast<NSUInteger>(layoutFor[node]);
    NSArray* css = styles[row], *rectangle = bounds[row];
    if (css.count && [@[@"hidden", @"collapse"] containsObject:Intern(strings, css[1])]) continue;
    double width = [rectangle[2] doubleValue], height = [rectangle[3] doubleValue];
    if (width <= 0 || height <= 0) continue;
    NSString* rendered = [Intern(strings, texts[row]) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!rendered.length) continue;
    if (blocks.count >= kBlocks || outputBytes + 1 >= kOutputBytes) { truncated = YES; break; }
    NSUInteger separator = blocks.count ? 1 : 0;
    rendered = Bounded(rendered, MIN(kBlockBytes, kOutputBytes - outputBytes - separator), truncated);
    if (!rendered.length) { truncated = YES; break; }
    BSLiveTextBlock* block = [BSLiveTextBlock new];
    block.backendNodeId = backendId[node]; block.text = rendered; block.linkURL = links[node];
    NSUInteger element = parent[node] >= 0 ? static_cast<NSUInteger>(parent[node]) : node;
    block.tagName = tags[element];
    block.bounds = NSMakeRect([rectangle[0] doubleValue], [rectangle[1] doubleValue], width, height);
    [blocks addObject:block];
    if (separator) [joined appendString:@"\n"];
    [joined appendString:rendered];
    outputBytes += [rendered lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + separator;
  }
  page.text = joined; page.blocks = blocks; page.truncated = truncated;
  NSMutableArray* coverage = [NSMutableArray arrayWithArray:@[
    @"Root-document rendered DOM text; child-frame text is omitted.",
    @"Origin is Page.getFrameTree loader securityOrigin metadata; effective JavaScript window origin is unverified.",
    @"Includes offscreen layout text. Occlusion, clipping, pixels and accessibility are not evaluated.",
    @"Input/textarea values and password descendants are omitted. Custom secrets rendered as ordinary page text cannot be recognized.",
    @"Canvas/image/video text is absent. Node IDs and CSS bounds describe this capture, not an action target.",
    @"Capture spans an interval; dynamic page text can change during the read."]];
  if (truncated) [coverage addObject:@"Output truncated: at most 256 text blocks, 2048 UTF-8 bytes per block and 32768 UTF-8 bytes total."];
  if (!blocks.count) [coverage addObject:@"No rendered root-document text was available; the page may still be loading or use non-DOM content."];
  page.coverage = coverage;
  return page;
}
}

@interface BSLiveObservation ()
- (void)receiveBytes:(const void*)bytes size:(size_t)size;
- (void)agentDetached;
- (void)sendNext;
- (void)finish:(BSLivePage*)page error:(NSString*)error;
@end

namespace {
class LiveObserver final : public CefDevToolsMessageObserver {
 public:
  explicit LiveObserver(BSLiveObservation* owner) : owner_(owner) {}
  bool OnDevToolsMessage(CefRefPtr<CefBrowser>, const void* bytes, size_t size) override {
    [owner_ receiveBytes:bytes size:size]; return true;
  }
  void OnDevToolsAgentDetached(CefRefPtr<CefBrowser>) override { [owner_ agentDetached]; }
 private:
  __weak BSLiveObservation* owner_;
  IMPLEMENT_REFCOUNTING(LiveObserver);
};
}

@implementation BSLiveObservation {
  CefRefPtr<CefBrowser> _browser;
  CefRefPtr<CefRegistration> _registration;
  dispatch_queue_t _worker;
  std::atomic<size_t> _queuedBytes;
  std::atomic<unsigned> _queuedCount;
  void (^_completion)(BSLivePage*, NSString*);
  BSLiveFrame* _before;
  BSLivePage* _page;
  NSString* _captureId;
  uint64_t _started, _generation, _lifecycle, _captureLifecycle;
  int _phase, _pendingId;
  BOOL _closed;
}
- (instancetype)initWithBrowser:(CefRefPtr<CefBrowser>)browser {
  CEF_REQUIRE_UI_THREAD();
  if ((self = [super init])) {
    _browser = browser;
    _worker = dispatch_queue_create("dev.oxcart.live-observation", DISPATCH_QUEUE_SERIAL);
    _closed = !browser;
    if (!_closed) _registration = browser->GetHost()->AddDevToolsMessageObserver(new LiveObserver(self));
  }
  return self;
}
- (void)captureWithCompletion:(void (^)(BSLivePage*, NSString*))completion {
  CEF_REQUIRE_UI_THREAD();
  if (_closed || _completion) { completion(nil, _closed ? @"Browser is closed." : @"A page read is already running."); return; }
  _completion = [completion copy]; _captureId = NSUUID.UUID.UUIDString;
  _started = NowNanos(); _captureLifecycle = _lifecycle; _phase = 0; ++_generation;
  uint64_t generation = _generation;
  [self sendNext];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDeadlineNanos), dispatch_get_main_queue(), ^{
    if (self->_completion && self->_generation == generation)
      [self finish:nil error:@"Page read exceeded ten seconds; retry when the page responds."];
  });
}
- (void)sendNext {
  if (!_completion || _closed) return;
  int messageId = nextMessageId.fetch_add(1);
  if (messageId <= 0 || messageId == INT_MAX) { [self finish:nil error:@"DevTools message IDs exhausted."]; return; }
  _pendingId = messageId;
  // JSON exists only in the external Chromium DevTools protocol envelope.
  NSString* command = _phase == 1
      ? [NSString stringWithFormat:@"{\"id\":%d,\"method\":\"DOMSnapshot.captureSnapshot\",\"params\":{\"computedStyles\":[\"display\",\"visibility\",\"opacity\"]}}", messageId]
      : [NSString stringWithFormat:@"{\"id\":%d,\"method\":\"Page.getFrameTree\",\"params\":{}}", messageId];
  NSData* bytes = [command dataUsingEncoding:NSUTF8StringEncoding];
  if (!_browser->GetHost()->SendDevToolsMessage(bytes.bytes, bytes.length))
    [self finish:nil error:@"Chromium rejected the page read command."];
}
- (void)receiveBytes:(const void*)bytes size:(size_t)size {
  CEF_REQUIRE_UI_THREAD();
  if (_closed || !_completion || !_pendingId) return;
  if (size > kMessageBytes || _queuedBytes.load() + size > 2 * kMessageBytes || _queuedCount.load() >= 8) {
    [self finish:nil error:@"Page DevTools response exceeded the 24 MiB message or queue bound."]; return;
  }
  NSData* copy = [NSData dataWithBytes:bytes length:size];
  const int expectedId = _pendingId, phase = _phase;
  const uint64_t generation = _generation;
  BSLiveFrame* frame = _before;
  _queuedBytes.fetch_add(size); _queuedCount.fetch_add(1);
  dispatch_async(_worker, ^{
    @autoreleasepool {
      NSDictionary* message = Dict([NSJSONSerialization JSONObjectWithData:copy options:0 error:nil]);
      int64_t receivedId;
      BSLiveReply* reply = nil;
      if (Integer(message[@"id"], receivedId) && receivedId == expectedId) {
        reply = [BSLiveReply new]; reply.messageId = expectedId;
        NSDictionary* result = Dict(message[@"result"]);
        NSString* error = nil;
        if (message[@"error"] || !result) error = @"Chromium could not read this page's frame or DOM snapshot.";
        else if (phase == 1) reply.page = Project(result, frame, &error);
        else reply.frame = ReadFrame(result, &error);
        reply.error = error;
      }
      self->_queuedBytes.fetch_sub(size); self->_queuedCount.fetch_sub(1);
      dispatch_async(dispatch_get_main_queue(), ^{
        if (!reply || self->_closed || !self->_completion || self->_generation != generation || self->_pendingId != reply.messageId) return;
        self->_pendingId = 0;
        if (NowNanos() - self->_started > kDeadlineNanos) { [self finish:nil error:@"Page read exceeded ten seconds."]; return; }
        if (reply.error) { [self finish:nil error:reply.error]; return; }
        if (phase == 0) self->_before = reply.frame;
        else if (phase == 1) self->_page = reply.page;
        else {
          if (![reply.frame.frameId isEqual:self->_before.frameId] || ![reply.frame.loaderId isEqual:self->_before.loaderId] ||
              ![reply.frame.origin isEqual:self->_before.origin]) {
            [self finish:nil error:@"Root document navigated during capture; read the new page again."]; return;
          }
          BSLivePage* page = self->_page;
          page.captureId = self->_captureId; page.captureStartNanos = self->_started; page.captureEndNanos = NowNanos();
          if (self->_captureLifecycle != self->_lifecycle)
            page.coverage = [page.coverage arrayByAddingObject:@"Native page lifecycle changed during capture; loader identity remained the same."];
          [self finish:page error:nil]; return;
        }
        ++self->_phase; [self sendNext];
      });
    }
  });
}
- (void)finish:(BSLivePage*)page error:(NSString*)error {
  if (!_completion) return;
  void (^completion)(BSLivePage*, NSString*) = _completion;
  _completion = nil; _pendingId = 0; _before = nil; _page = nil;
  completion(page, error);
}
- (void)nativeLifecycle:(NSString*)reason {
  CEF_REQUIRE_UI_THREAD();
  (void)reason; ++_lifecycle;
}
- (void)agentDetached {
  CEF_REQUIRE_UI_THREAD();
  [self finish:nil error:@"Chromium detached the page reader; retry the capture."];
}
- (void)cancel {
  CEF_REQUIRE_UI_THREAD();
  ++_generation;
  [self finish:nil error:@"Page read stopped. Chromium's in-flight reader may still finish."];
}
- (void)close {
  CEF_REQUIRE_UI_THREAD();
  _closed = YES;
  [self finish:nil error:@"Browser closed during the page read."];
  _registration = nullptr; _browser = nullptr;
}
@end
