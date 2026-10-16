#import "traffic_browser.h"
#import "traffic_session.h"
#include "devtools_ids.h"
#include "include/cef_devtools_message_observer.h"
#include "include/wrapper/cef_helpers.h"
#include <atomic>

namespace {
CefRefPtr<CefValue> ProtocolValue(id value) {
  auto out = CefValue::Create();
  if ([value isKindOfClass:NSString.class]) out->SetString([value UTF8String]);
  else if ([value isKindOfClass:NSNumber.class]) {
    if (CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) out->SetBool([value boolValue]);
    else if (CFNumberIsFloatType((__bridge CFNumberRef)value)) out->SetDouble([value doubleValue]);
    else out->SetInt([value intValue]);
  } else if ([value isKindOfClass:NSDictionary.class]) {
    auto dictionary = CefDictionaryValue::Create();
    for (NSString* key in value) dictionary->SetValue(key.UTF8String,ProtocolValue(value[key]));
    out->SetDictionary(dictionary);
  } else if ([value isKindOfClass:NSArray.class]) {
    auto list = CefListValue::Create(); list->SetSize([value count]);
    NSUInteger i = 0; for (id item in value) list->SetValue(i++,ProtocolValue(item));
    out->SetList(list);
  } else out->SetNull();
  return out;
}
NSButton* Button(NSView* parent, NSString* title, id target, SEL action, NSRect frame) {
  NSButton* button = [NSButton buttonWithTitle:title target:target action:action];
  button.frame = frame; [parent addSubview:button]; return button;
}
NSTextField* Field(NSView* parent, NSString* placeholder, NSRect frame) {
  NSTextField* field = [[NSTextField alloc] initWithFrame:frame]; field.placeholderString = placeholder;
  [parent addSubview:field]; return field;
}
NSTextView* Editor(NSView* parent, NSRect frame, BOOL editable) {
  NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:frame]; scroll.hasVerticalScroller = YES;
  scroll.borderType = NSBezelBorder;
  NSTextView* text = [[NSTextView alloc] initWithFrame:scroll.contentView.bounds];
  text.editable = editable; text.richText = NO; text.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
  text.autoresizingMask = NSViewWidthSizable; text.verticallyResizable = YES;
  text.textContainer.widthTracksTextView = YES; scroll.documentView = text; [parent addSubview:scroll]; return text;
}
}
@interface OXTrafficBrowser () <NSWindowDelegate>
- (BOOL)hasResult:(int)identity;
- (void)result:(int)identity success:(BOOL)success bytes:(NSData*)bytes;
- (void)event:(NSString*)method bytes:(NSData*)bytes;
- (void)detached;
@end
namespace {
class TrafficObserver final : public CefDevToolsMessageObserver {
 public:
  explicit TrafficObserver(OXTrafficBrowser* owner) : owner_(owner) {}
  void OnDevToolsMethodResult(CefRefPtr<CefBrowser>, int identity, bool success, const void* bytes, size_t size) override {
    if ([owner_ hasResult:identity]) [owner_ result:identity success:success bytes:[NSData dataWithBytes:bytes length:size]];
  }
  void OnDevToolsEvent(CefRefPtr<CefBrowser>, const CefString& method, const void* bytes, size_t size) override {
    NSString* name = [NSString stringWithUTF8String:method.ToString().c_str()];
    if ([name hasPrefix:@"Network."] || [name hasPrefix:@"Fetch."])
      [owner_ event:name bytes:[NSData dataWithBytes:bytes length:size]];
  }
  void OnDevToolsAgentDetached(CefRefPtr<CefBrowser>) override { [owner_ detached]; }
 private:
  __weak OXTrafficBrowser* owner_;
  IMPLEMENT_REFCOUNTING(TrafficObserver);
};
}
@implementation OXTrafficBrowser {
  CefRefPtr<CefBrowser> _browser;
  CefRefPtr<CefRegistration> _registration;
  OXTrafficSession* _session;
  NSMutableDictionary<NSNumber*, OXTrafficReply>* _pending;
  dispatch_queue_t _decode;
  NSWindow* _window;
  NSTextField* _status;
  NSTextField* _pattern;
  NSButton* _requests;
  NSButton* _responses;
  NSPopUpButton* _pauses;
  NSPopUpButton* _events;
  NSTextField* _url;
  NSTextField* _method;
  NSTextField* _code;
  NSTextField* _bodyLabel;
  NSTextView* _headers;
  NSTextView* _details;
  NSDictionary* _snapshot;
  NSString* _selectedPause;
  NSString* _bodyPath;
  NSArray* _pauseRows;
  NSArray* _eventRows;
  BOOL _closed;
}
- (instancetype)initWithBrowser:(CefRefPtr<CefBrowser>)browser rootURL:(NSURL*)root {
  CEF_REQUIRE_UI_THREAD();
  if ((self = [super init])) {
    _browser = browser; _pending = [NSMutableDictionary dictionary];
    _decode = dispatch_queue_create("dev.oxcart.traffic-protocol",DISPATCH_QUEUE_SERIAL);
    __weak OXTrafficBrowser* weakSelf = self;
    _session = [[OXTrafficSession alloc] initWithRootURL:root transport:^(NSString* method, NSDictionary* params, OXTrafficReply reply) {
      dispatch_async(dispatch_get_main_queue(),^{
        OXTrafficBrowser* owner = weakSelf;
        if (!owner || owner->_closed || !owner->_browser) { reply(NO,@{@"message":@"Browser closed"}); return; }
        int identity = OXNextDevToolsID();
        if (identity <= 0 || identity == INT_MAX) { reply(NO,@{@"message":@"Protocol command IDs exhausted"}); return; }
        owner->_pending[@(identity)] = [reply copy];
        if (!owner->_browser->GetHost()->ExecuteDevToolsMethod(identity,method.UTF8String,ProtocolValue(params)->GetDictionary())) {
          [owner->_pending removeObjectForKey:@(identity)]; reply(NO,@{@"message":@"CEF rejected the command"});
        }
      });
    }];
    _session.changed = ^(NSDictionary* snapshot) { [weakSelf update:snapshot]; };
    _registration = browser->GetHost()->AddDevToolsMessageObserver(new TrafficObserver(self));
    [_session start];
  }
  return self;
}
- (void)result:(int)identity success:(BOOL)success bytes:(NSData*)bytes {
  OXTrafficReply reply = _pending[@(identity)]; if (!reply) return;
  [_pending removeObjectForKey:@(identity)];
  dispatch_async(_decode,^{
    NSError* error = nil;
    id value = bytes.length ? [NSJSONSerialization JSONObjectWithData:bytes options:0 error:&error] : @{};
    if (![value isKindOfClass:NSDictionary.class]) reply(NO,@{@"message":error.localizedDescription ?: @"Invalid CDP result"});
    else reply(success,value);
  });
}
- (BOOL)hasResult:(int)identity { return _pending[@(identity)] != nil; }
- (NSURL*)directoryURL { return _session.directoryURL; }
- (void)event:(NSString*)method bytes:(NSData*)bytes { [_session receiveEvent:method protocolBytes:bytes]; }
- (void)detached {
  [_session agentDetached];
  NSArray* callbacks = _pending.allValues; [_pending removeAllObjects];
  for (OXTrafficReply reply in callbacks) reply(NO,@{@"message":@"DevTools agent detached"});
}
- (void)markContext:(NSDictionary*)context { [_session markContext:context]; }
- (void)show {
  if (!_window) [self buildWindow];
  [_window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (void)buildWindow {
  _window = [[NSWindow alloc] initWithContentRect:NSMakeRect(100,70,1020,740)
      styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable
      backing:NSBackingStoreBuffered defer:NO];
  _window.title = @"Oxcart · Traffic"; _window.releasedWhenClosed = NO;
  _window.delegate = self;
  NSView* view = _window.contentView;
  _status = [NSTextField labelWithString:@"Passive capture"];
  _status.frame = NSMakeRect(16,704,988,24); [view addSubview:_status];
  _pattern = Field(view,@"URL glob, e.g. https://example.org/*",NSMakeRect(16,666,470,26));
  _requests = [NSButton checkboxWithTitle:@"Requests" target:nil action:nil]; _requests.frame = NSMakeRect(496,666,100,26); [view addSubview:_requests];
  _responses = [NSButton checkboxWithTitle:@"Responses" target:nil action:nil]; _responses.frame = NSMakeRect(602,666,110,26); [view addSubview:_responses];
  Button(view,@"Arm",self,@selector(arm:),NSMakeRect(720,663,80,32));
  Button(view,@"Stop / disarm",self,@selector(stopAction:),NSMakeRect(808,663,140,32));
  NSTextField* note = [NSTextField labelWithString:@"Response pauses consume upstream bytes into files. Stop during a stream cancels it and keeps partial data."];
  note.font = [NSFont systemFontOfSize:11]; note.textColor = NSColor.secondaryLabelColor;
  note.frame = NSMakeRect(16,639,988,21); [view addSubview:note];
  _pauses = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(16,601,988,28) pullsDown:NO];
  _pauses.target = self; _pauses.action = @selector(selectPause:); [view addSubview:_pauses];
  _url = Field(view,@"Request URL",NSMakeRect(16,565,748,26));
  _method = Field(view,@"Method",NSMakeRect(774,565,110,26));
  _code = Field(view,@"Status",NSMakeRect(894,565,110,26));
  _headers = Editor(view,NSMakeRect(16,354,590,201),YES);
  _bodyLabel = [NSTextField labelWithString:@"Body: preserve original"];
  _bodyLabel.frame = NSMakeRect(622,520,382,30); _bodyLabel.lineBreakMode = NSLineBreakByTruncatingMiddle; [view addSubview:_bodyLabel];
  Button(view,@"Choose body file…",self,@selector(chooseBody:),NSMakeRect(622,478,180,32));
  Button(view,@"Use original body",self,@selector(clearBody:),NSMakeRect(814,478,180,32));
  Button(view,@"Apply edits",self,@selector(apply:),NSMakeRect(622,430,120,34));
  Button(view,@"Forward original",self,@selector(forward:),NSMakeRect(750,430,140,34));
  Button(view,@"Cancel",self,@selector(cancel:),NSMakeRect(900,430,104,34));
  Button(view,@"Reveal archive",self,@selector(reveal:),NSMakeRect(622,375,170,34));
  Button(view,@"Resume capture",self,@selector(resume:),NSMakeRect(810,375,180,34));
  _events = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(16,311,988,28) pullsDown:NO];
  _events.target = self; _events.action = @selector(selectEvent:); [view addSubview:_events];
  _details = Editor(view,NSMakeRect(16,16,988,285),NO);
  [self update:_snapshot ?: @{}];
}
- (void)update:(NSDictionary*)snapshot {
  _snapshot = snapshot;
  if (!_window) return;
  NSString* active = [snapshot[@"armed"] count] ? [NSString stringWithFormat:@" · Active: %@",snapshot[@"armed"][@"pattern"]] : @"";
  _status.stringValue = [NSString stringWithFormat:@"%@ · %@ retained events%@",snapshot[@"status"] ?: @"",snapshot[@"event_count"] ?: @0,active];
  _pauseRows = [snapshot[@"pauses"] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) { return [a[@"id"] compare:b[@"id"]]; }];
  [_pauses removeAllItems];
  NSInteger selected = -1;
  for (NSDictionary* row in _pauseRows) {
    [_pauses addItemWithTitle:[NSString stringWithFormat:@"%@ · %@ · %@ · %@ bytes · %@",[row[@"response"] boolValue] ? @"Response" : @"Request",row[@"url"],row[@"state"],row[@"body_bytes"],row[@"id"]]];
    if ([row[@"id"] isEqual:_selectedPause]) selected = _pauses.numberOfItems-1;
  }
  if (selected >= 0) [_pauses selectItemAtIndex:selected];
  else { _selectedPause = nil; if (_pauseRows.count) { [_pauses selectItemAtIndex:0]; [self selectPause:nil]; } }
  if (!_pauseRows.count) { [_pauses addItemWithTitle:@"No paused exchanges"]; _pauses.enabled = NO; }
  else _pauses.enabled = YES;
  NSDictionary* current = [self selected];
  if (!_bodyPath && current) _bodyLabel.stringValue = [NSString stringWithFormat:@"Original body: %@ bytes · %@",current[@"body_bytes"],current[@"state"]];
  NSString* selectedEvent = _events.selectedItem.representedObject;
  _eventRows = [[snapshot[@"recent"] reverseObjectEnumerator] allObjects] ?: @[];
  [_events removeAllItems];
  for (NSDictionary* event in _eventRows) {
    [_events addItemWithTitle:[NSString stringWithFormat:@"%@ · %@ · %@",event[@"method"],event[@"url"],event[@"event_path"]]];
    _events.lastItem.representedObject = event[@"event_path"];
  }
  if (selectedEvent) for (NSMenuItem* item in _events.itemArray) if ([item.representedObject isEqual:selectedEvent]) [_events selectItem:item];
}
- (NSDictionary*)selected {
  for (NSDictionary* row in _pauseRows) if ([row[@"id"] isEqual:_selectedPause]) return row;
  return nil;
}
- (void)selectPause:(id)sender {
  (void)sender;
  NSInteger index = _pauses.indexOfSelectedItem;
  if (index < 0 || index >= (NSInteger)_pauseRows.count) return;
  NSDictionary* row = _pauseRows[index];
  _selectedPause = row[@"id"]; _bodyPath = nil; _bodyLabel.stringValue = @"Body: preserve original";
  _url.stringValue = row[@"url"]; _method.stringValue = row[@"method"];
  _code.stringValue = [row[@"status"] stringValue]; _headers.string = OXTrafficHeaderText(row[@"headers"]);
  _url.enabled = _method.enabled = ![row[@"response"] boolValue]; _code.enabled = [row[@"response"] boolValue];
  _details.string = [NSString stringWithFormat:@"Pause %@\nState: %@\nOriginal: %@/%@/original.bplist\nUpstream body: %@\nUse a body file for arbitrary binary content; a zero-byte file replaces with an empty body.\nCommand acceptance is retained separately from later Network observations.",
    row[@"id"],row[@"state"],_session.directoryURL.path,row[@"directory"],row[@"body_manifest"]];
}
- (void)selectEvent:(id)sender {
  (void)sender;
  NSString* path = _events.selectedItem.representedObject; if (!path) return;
  NSURL* url = [_session.directoryURL URLByAppendingPathComponent:path];
  // Reading one event is explicit; large bodies remain separate files.
  dispatch_async(_decode,^{
    NSError* error = nil; NSData* bytes = [NSData dataWithContentsOfURL:url options:0 error:&error];
    id value = bytes ? [NSPropertyListSerialization propertyListWithData:bytes options:0 format:nil error:&error] : nil;
    NSString* detail = value ? [NSString stringWithFormat:@"%@\n\n%@",url.path,value] : error.localizedDescription;
    dispatch_async(dispatch_get_main_queue(),^{ self->_details.string = detail ?: @"Unreadable event"; });
  });
}
- (void)arm:(id)sender { (void)sender; [_session armPattern:_pattern.stringValue requests:_requests.state == NSControlStateValueOn responses:_responses.state == NSControlStateValueOn]; }
- (void)stopAction:(id)sender { (void)sender; [self stop]; }
- (void)stop { [_session stop]; }
- (void)windowWillClose:(NSNotification*)notification { (void)notification; if (!_closed) [_session stop]; }
- (void)resume:(id)sender { (void)sender; [_session start]; }
- (void)forward:(id)sender { (void)sender; if (_selectedPause) [_session forwardPause:_selectedPause]; }
- (void)cancel:(id)sender { (void)sender; if (_selectedPause) [_session cancelPause:_selectedPause]; }
- (void)chooseBody:(id)sender {
  (void)sender;
  NSOpenPanel* panel = [NSOpenPanel openPanel]; panel.canChooseDirectories = NO; panel.allowsMultipleSelection = NO;
  NSString* identity = _selectedPause;
  [panel beginSheetModalForWindow:_window completionHandler:^(NSModalResponse result) {
    if (result == NSModalResponseOK && [identity isEqual:self->_selectedPause]) {
      self->_bodyPath = panel.URL.path; self->_bodyLabel.stringValue = [@"Body: " stringByAppendingString:self->_bodyPath];
    }
  }];
}
- (void)clearBody:(id)sender { (void)sender; _bodyPath = nil; _bodyLabel.stringValue = @"Body: preserve original"; }
- (void)apply:(id)sender {
  (void)sender; NSDictionary* row = [self selected]; if (!row) return;
  NSString* error = nil; NSArray* headers = OXTrafficParseHeaders(_headers.string,&error);
  if (!headers) { _status.stringValue = error; _details.string = error; return; }
  NSMutableDictionary* overrides = [@{@"headers":headers} mutableCopy];
  if ([row[@"response"] boolValue]) {
    NSScanner* scanner = [NSScanner scannerWithString:_code.stringValue]; long long code = 0;
    if (![scanner scanLongLong:&code] || !scanner.isAtEnd) { _status.stringValue = @"Enter an integer response status."; _details.string = _status.stringValue; return; }
    overrides[@"status"] = @(code);
  } else { overrides[@"url"] = _url.stringValue; overrides[@"method"] = _method.stringValue; }
  if (_bodyPath) overrides[@"body_file"] = _bodyPath;
  [_session applyPause:_selectedPause overrides:overrides];
}
- (void)reveal:(id)sender { (void)sender; [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[_session.directoryURL]]; }
- (void)closeWithCompletion:(void (^)(void))completion {
  CEF_REQUIRE_UI_THREAD();
  _closed = YES;
  [_window close];
  _registration = nullptr; _browser = nullptr;
  NSArray* callbacks = _pending.allValues; [_pending removeAllObjects];
  for (OXTrafficReply reply in callbacks) reply(NO,@{@"message":@"Browser closed"});
  dispatch_async(_decode,^{ [self->_session closeWithCompletion:completion]; });
}
@end
