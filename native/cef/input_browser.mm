#import "input_browser.h"
#import "input_archive.h"
#import "input_events.h"
#include "include/cef_frame.h"

namespace {
NSString* String(const CefString& value) {
  auto text = value.ToString16();
  return [[NSString alloc] initWithCharacters:reinterpret_cast<const unichar*>(text.data()) length:text.size()];
}
id Value(CefRefPtr<CefValue> value) {
  switch (value->GetType()) {
    case VTYPE_NULL: return @{@"oxcart_null":@YES};
    case VTYPE_BOOL: return @(value->GetBool());
    case VTYPE_INT: return @(value->GetInt());
    case VTYPE_DOUBLE: return @(value->GetDouble());
    case VTYPE_STRING: return String(value->GetString());
    case VTYPE_DICTIONARY: {
      auto dict = value->GetDictionary(); CefDictionaryValue::KeyList keys; dict->GetKeys(keys);
      NSMutableDictionary* result = [NSMutableDictionary dictionaryWithCapacity:keys.size()];
      for (const auto& key : keys) result[String(key)] = Value(dict->GetValue(key));
      return [result copy];
    }
    case VTYPE_LIST: {
      auto list = value->GetList(); NSMutableArray* result = [NSMutableArray arrayWithCapacity:list->GetSize()];
      for (size_t i = 0; i < list->GetSize(); ++i) [result addObject:Value(list->GetValue(i))];
      return [result copy];
    }
    default: return @{@"oxcart_unexpected_cef_type":@(value->GetType())};
  }
}
}
@implementation OXInputBrowser {
  CefRefPtr<CefBrowser> _browser;
  NSURL* _root;
  NSMutableDictionary<NSString*, OXInputArchive*>* _archives;
  NSMutableDictionary<NSString*, NSString*>* _contexts;
  NSMutableDictionary* _context;
  BOOL _closed;
}
- (instancetype)initWithBrowser:(CefRefPtr<CefBrowser>)browser rootURL:(NSURL*)root {
  self = [super init]; if (!self) return nil;
  _browser = browser; _root = root;
  _archives = [NSMutableDictionary dictionary]; _contexts = [NSMutableDictionary dictionary];
  _context = [NSMutableDictionary dictionary];
  for (NSString* name in @[NSApplicationDidBecomeActiveNotification,NSApplicationDidResignActiveNotification,
      NSWindowDidBecomeKeyNotification,NSWindowDidResignKeyNotification])
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(focusChanged:) name:name object:nil];
  return self;
}
- (NSWindow*)window {
  if (!_browser || !_browser->IsValid()) return nil;
  return ((__bridge NSView*)_browser->GetHost()->GetWindowHandle()).window;
}
- (void)focusChanged:(NSNotification*)notification {
  if (!_activeRecordingID) return;
  if ([notification.object isKindOfClass:NSWindow.class] && notification.object != self.window) return;
  [_archives[_activeRecordingID] append:@"native_focus" fields:@{@"notification":notification.name,
      @"app_active":@(NSApp.isActive),@"browser_window_key":@(self.window.isKeyWindow)}];
}
- (void)sendRecording:(NSString*)recording frameID:(NSString*)frameID context:(NSString*)context {
  if (!_browser || !_browser->IsValid()) return;
  auto frame = _browser->GetFrameByIdentifier(frameID.UTF8String);
  if (!frame || !frame->IsValid()) return;
  auto message = CefProcessMessage::Create("oxcart.input.set");
  message->GetArgumentList()->SetString(0,recording.UTF8String);
  message->GetArgumentList()->SetString(1,context.UTF8String);
  frame->SendProcessMessage(PID_RENDERER,message);
}
- (NSURL*)startWithContext:(NSDictionary*)context {
  if (_closed || _activeRecordingID) return nil;
  [self markContext:context];
  NSWindow* window = self.window; NSScreen* screen = window.screen;
  NSDictionary* metadata = @{@"browser_id":@(_browser->GetIdentifier()),@"context":[_context copy],
      @"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"platform":@"macOS/AppKit/CEF15400",
      @"native_scope":@"Only this browser's native window, including its Chrome UI. No global tap; no other application/panel events.",
      @"device_identity":@"unknown; precision and phase are observed event properties, not a guessed device class",
      @"browser_scope":@"Instrumented ordinary frame contexts. No workers or closed shadow internals. Page code can interfere. Native and DOM records are not causally paired.",
      @"window_frame":NSStringFromRect(window.frame),@"screen_frame":NSStringFromRect(screen.frame),
      @"backing_scale_factor":@(screen.backingScaleFactor),@"screen_number":screen.deviceDescription[@"NSScreenNumber"] ?: @0,
      @"app_active":@(NSApp.isActive),@"browser_window_key":@(window.isKeyWindow)};
  OXInputArchive* archive = [[OXInputArchive alloc] initWithRootURL:_root metadata:metadata];
  __weak OXInputBrowser* weakSelf = self;
  NSString* archiveID = archive.recordingID;
  archive.failed = ^(NSString* message) {
    OXInputBrowser* owner = weakSelf;
    // End acquisition on storage failure instead of silently growing an unwritable trace.
    if ([owner.activeRecordingID isEqual:archiveID]) [owner stop];
    if (owner.failed) owner.failed(message);
  };
  _activeRecordingID = archive.recordingID; _archives[archive.recordingID] = archive;
  [archive append:@"recording_started" fields:[_context copy]];
  for (NSString* contextID in _contexts) [self sendRecording:_activeRecordingID frameID:_contexts[contextID] context:contextID];
  return archive.directoryURL;
}
- (void)stop {
  if (!_activeRecordingID) return;
  NSString* recording = _activeRecordingID; _activeRecordingID = nil;
  [_archives[recording] append:@"stop_requested" fields:@{}];
  for (NSString* context in _contexts) [self sendRecording:@"" frameID:_contexts[context] context:context];
}
- (void)markContext:(NSDictionary*)context {
  [_context addEntriesFromDictionary:context];
  if (_activeRecordingID) [_archives[_activeRecordingID] append:@"context" fields:[_context copy]];
}
- (void)nativeEvent:(NSEvent*)event {
  if (!_activeRecordingID || _closed) return;
  NSWindow* window = self.window;
  NSWindow* recipient = event.window ?: NSApp.keyWindow;
  if (!window || recipient != window) return;
  NSDictionary* fields = OXNativeInputFields(event); if (!fields) return;
  NSMutableDictionary* snapshot = [fields mutableCopy];
  snapshot[@"window_resolution"] = event.window ? @"event_window" : @"current_key_window";
  snapshot[@"window_frame"] = NSStringFromRect(window.frame);
  snapshot[@"backing_scale_factor"] = @(window.backingScaleFactor);
  snapshot[@"screen_frame"] = NSStringFromRect(window.screen.frame);
  snapshot[@"first_responder_class"] = NSStringFromClass(window.firstResponder.class) ?: @"unknown";
  snapshot[@"browser_window_key"] = @(window.isKeyWindow); snapshot[@"app_active"] = @(NSApp.isActive);
  [_archives[_activeRecordingID] append:@"native_input" fields:[snapshot copy]];
}
- (BOOL)receiveFrame:(CefRefPtr<CefFrame>)frame message:(CefRefPtr<CefProcessMessage>)message {
  if (message->GetName() != "oxcart.input.record") return NO;
  if (_closed) return YES;
  auto args = message->GetArgumentList();
  if (args->GetSize() != 4 || args->GetType(0) != VTYPE_STRING || args->GetType(1) != VTYPE_STRING ||
      args->GetType(2) != VTYPE_STRING || args->GetType(3) != VTYPE_DICTIONARY) return YES;
  NSString* kind = String(args->GetString(0)), *context = String(args->GetString(1));
  NSString* recording = String(args->GetString(2));
  NSString* frameID = String(frame->GetIdentifier());
  if ([kind isEqual:@"context_ready"]) {
    _contexts[context] = frameID;
    recording = _activeRecordingID;
    if (recording) [self sendRecording:recording frameID:frameID context:context];
  } else if ([kind isEqual:@"context_released"]) {
    [_contexts removeObjectForKey:context];
  }
  OXInputArchive* archive = recording ? _archives[recording] : nil;
  if (archive) {
    auto value = CefValue::Create(); value->SetDictionary(args->GetDictionary(3)->Copy(false));
    [archive append:kind fields:@{@"context_id":context,@"frame_id":frameID,
        @"frame_url":String(frame->GetURL()),@"main_frame":@(frame->IsMain()),@"observation":Value(value)}];
    if ([kind isEqual:@"observer_install_failed"] || [kind isEqual:@"observer_conversion_failed"] || [kind isEqual:@"context_unavailable"]) {
      if (self.failed) self.failed([NSString stringWithFormat:@"Input observation %@ in frame %@; details retained.",kind,frameID]);
    }
  }
  return YES;
}
- (void)rendererTerminated {
  if (_activeRecordingID) [_archives[_activeRecordingID] append:@"renderer_terminated" fields:@{@"note":@"Deferred events in the terminated renderer may be unavailable."}];
  [_contexts removeAllObjects];
}
- (void)closeWithCompletion:(void (^)(void))completion {
  [self stop]; _closed = YES;
  [NSNotificationCenter.defaultCenter removeObserver:self];
  dispatch_group_t group = dispatch_group_create();
  for (OXInputArchive* archive in _archives.allValues) {
    [archive append:@"browser_closed" fields:@{@"note":@"Browser IPC may end before all renderer acknowledgments. Inspect recorded contexts and stop markers."}];
    dispatch_group_enter(group);
    [archive closeWithCompletion:^{ dispatch_group_leave(group); }];
  }
  _browser = nullptr; [_contexts removeAllObjects];
  dispatch_group_notify(group,dispatch_get_main_queue(),completion);
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
