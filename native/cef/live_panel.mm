#import "live_panel.h"
#import "input_browser.h"
#import "live_observation.h"
#import "traffic_browser.h"
#import "blackbird_connection.h"
#import "extraction_controller.h"

namespace {
NSTextView* TextView(NSView* parent, NSRect frame, BOOL editable) {
  NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:frame];
  scroll.hasVerticalScroller = YES; scroll.borderType = NSBezelBorder;
  NSTextView* text = [[NSTextView alloc] initWithFrame:scroll.contentView.bounds];
  text.editable = editable; text.richText = NO;
  text.font = [NSFont systemFontOfSize:13]; text.textContainerInset = NSMakeSize(10, 10);
  text.autoresizingMask = NSViewWidthSizable;
  scroll.documentView = text; [parent addSubview:scroll]; return text;
}
NSButton* Button(NSView* view, NSString* title, id target, SEL action, NSRect frame) {
  NSButton* button = [NSButton buttonWithTitle:title target:target action:action];
  button.frame = frame; [view addSubview:button]; return button;
}
}

@implementation BSLivePanel {
  NSPanel* _panel;
  NSTextField* _connectionLabel;
  NSTextField* _pageLabel;
  NSTextField* _status;
  NSTextView* _transcript;
  NSTextView* _composer;
  NSButton* _send;
  NSButton* _observe;
  NSButton* _stop;
  NSButton* _includePage;
  NSButton* _extract;
  NSButton* _recordInput;
  OXExtractionController* _extraction;
  BSBlackbirdConnection* _connection;
  NSURL* _readingsURL;
  BSLiveObservation* _observer;
  NSMutableDictionary<NSNumber*, OXTrafficBrowser*>* _traffic;
  NSURL* _trafficRoot;
  dispatch_group_t _trafficWrites;
  NSMutableDictionary<NSNumber*, OXInputBrowser*>* _input;
  NSURL* _inputRoot;
  dispatch_group_t _inputWrites;
  CefRefPtr<CefBrowser> _browser;
  NSMutableDictionary* _result;
  NSString* _request;
  NSString* _smokeObjective;
  void (^_quit)(void);
  BOOL _capturing, _loading, _closing, _smoke, _smokeStarted, _streaming;
  uint64_t _captureEpoch;
}
- (instancetype)initWithBlackbirdURL:(NSURL*)executable sessionURL:(NSURL*)session
    workingDirectoryURL:(NSURL*)directory model:(NSString*)model
    result:(NSMutableDictionary*)result smokeObjective:(NSString*)objective
    smoke:(BOOL)smoke quit:(void (^)(void))quit {
  self = [super init]; if (!self) return nil;
  _readingsURL = [[session URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"readings" isDirectory:YES];
  _trafficRoot = [[session URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"traffic" isDirectory:YES];
  _traffic = [NSMutableDictionary dictionary]; _trafficWrites = dispatch_group_create();
  _inputRoot = [[session URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"input" isDirectory:YES];
  _input = [NSMutableDictionary dictionary]; _inputWrites = dispatch_group_create();
  _result = result; _smokeObjective = [objective copy]; _smoke = smoke; _quit = [quit copy];
  NSRect screen = NSScreen.mainScreen.visibleFrame;
  CGFloat width = MIN(520, MAX(380, screen.size.width * 0.36));
  CGFloat height = MIN(820, screen.size.height - 70);
  _panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(NSMaxX(screen) - width - 12,
      NSMaxY(screen) - height - 24, width, height)
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskMiniaturizable
      backing:NSBackingStoreBuffered defer:NO];
  _panel.title = @"Oxcart · Blackbird"; _panel.releasedWhenClosed = NO;
  NSView* content = _panel.contentView;
  NSTextField* heading = [NSTextField labelWithString:@"OXCART"];
  heading.font = [NSFont boldSystemFontOfSize:20];
  heading.frame = NSMakeRect(16, height - 43, width - 32, 27); [content addSubview:heading];
  _recordInput = Button(content,@"Record input",self,@selector(recordInput:),NSMakeRect(width-152,height-43,136,28));
  _recordInput.toolTip = @"Record this browser's input, typed values and page events locally. Finish input or Stop ends acquisition.";
  _connectionLabel = [NSTextField labelWithString:@"Connecting to Blackbird…"];
  _connectionLabel.textColor = NSColor.secondaryLabelColor;
  _connectionLabel.frame = NSMakeRect(16, height - 68, width - 32, 20); [content addSubview:_connectionLabel];
  _pageLabel = [NSTextField labelWithString:@"Browse to a page to begin."];
  _pageLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
  _pageLabel.frame = NSMakeRect(16, height - 99, width - 32, 22); [content addSubview:_pageLabel];
  _extract = Button(content,@"Extract",self,@selector(extract:),NSMakeRect(16,height-140,120,30));
  Button(content,@"Preview",self,@selector(preview:),NSMakeRect(146,height-140,120,30));
  Button(content,@"Traffic",self,@selector(traffic:),NSMakeRect(276,height-140,94,30));
  _transcript = TextView(content, NSMakeRect(16, 226, width - 32, height - 378), NO);
  _includePage = [NSButton checkboxWithTitle:@"Include a fresh reading of this page" target:self action:@selector(includePageChanged:)];
  _includePage.state = NSControlStateValueOn;
  _includePage.frame = NSMakeRect(16, 194, width - 32, 25); [content addSubview:_includePage];
  _composer = TextView(content, NSMakeRect(16, 91, width - 32, 98), YES);
  _composer.string = @"";
  _send = Button(content, @"Send", self, @selector(send:), NSMakeRect(width - 110, 48, 94, 33));
  _send.keyEquivalent = @"\r"; _send.keyEquivalentModifierMask = NSEventModifierFlagCommand;
  _observe = Button(content, @"Read page", self, @selector(observe:), NSMakeRect(16, 48, 106, 33));
  _stop = Button(content, @"Stop", self, @selector(stop:), NSMakeRect(132, 48, 82, 33));
  _status = [NSTextField labelWithString:@"Browse normally. Send shares the page with Blackbird."];
  _status.font = [NSFont systemFontOfSize:11]; _status.textColor = NSColor.secondaryLabelColor;
  _status.frame = NSMakeRect(16, 18, width - 32, 23); [content addSubview:_status];
  _connection = [[BSBlackbirdConnection alloc] initWithExecutableURL:executable
      sessionURL:session workingDirectoryURL:directory model:model];
  _extraction = [[OXExtractionController alloc] initWithDataURL:session.URLByDeletingLastPathComponent connection:_connection result:result];
  __weak BSLivePanel* weakSelf = self;
  _connection.eventHandler = ^(NSDictionary* event) { [weakSelf receive:event]; };
  _extraction.stateChanged = ^{ [weakSelf updateButtons]; };
  _extraction.finished = ^{ BSLivePanel* panel = weakSelf; if (panel && panel->_smoke && [panel->_result[@"smoke_extraction"] boolValue]) panel->_quit(); };
  [_panel orderFront:nil]; [self updateButtons]; [_connection start];
  return self;
}
- (NSPanel*)panel { return _panel; }
- (void)append:(NSString*)text {
  if (!text.length) return;
  // The complete conversation remains in Blackbird's session. Keep this view bounded.
  if (text.length > 512 * 1024) {
    NSUInteger start = text.length - 512 * 1024;
    NSRange character = [text rangeOfComposedCharacterSequenceAtIndex:start];
    text = [text substringFromIndex:NSMaxRange(character)];
  }
  if (_transcript.string.length + text.length > 512 * 1024) {
    NSUInteger remove = MIN(_transcript.string.length, 128 * 1024 + text.length);
    [_transcript.textStorage deleteCharactersInRange:NSMakeRange(0, remove)];
  }
  [_transcript.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:text]];
  [_transcript scrollRangeToVisible:NSMakeRange(_transcript.string.length, 0)];
}
- (void)updateButtons {
  _recordInput.enabled = !_closing && _browser;
  _recordInput.title = _browser && _input[@(_browser->GetIdentifier())].activeRecordingID ? @"Finish input" : @"Record input";
  _observe.enabled = !_closing && _browser && !_capturing && !_loading;
  _send.enabled = !_closing && _connection.ready && !_capturing &&
      !_extraction.busy && (_includePage.state != NSControlStateValueOn || (_browser && !_loading));
  _extract.enabled = !_closing && _connection.ready && !_connection.running && !_extraction.busy && !_capturing && _browser && !_loading;
  _send.title = _connection.running ? @"Steer" : @"Send";
  _stop.enabled = !_closing && (_browser || _capturing || _connection.running || _extraction.busy);
}
- (void)includePageChanged:(id)sender { (void)sender; [self updateButtons]; }
- (void)receive:(NSDictionary*)event {
  if ([_extraction receiveEvent:event]) { [self updateButtons]; return; }
  NSString* type = event[@"type"];
  if ([type isEqual:@"ready"]) {
    _connectionLabel.stringValue = [NSString stringWithFormat:@"Blackbird · %@", event[@"model"] ?: @"ready"];
    _result[@"blackbird_ready"] = @YES;
  } else if ([type isEqual:@"text"]) {
    if (!_request || ![event[@"id"] isEqual:_request]) return;
    if (!_streaming) { [self append:@"\nBlackbird\n"]; _streaming = YES; }
    [self append:[event[@"text"] isKindOfClass:NSString.class] ? event[@"text"] : @""];
  } else if ([type isEqual:@"status"]) {
    if ([event[@"id"] isEqual:_request] && [event[@"text"] isKindOfClass:NSString.class])
      _status.stringValue = event[@"text"];
  } else if ([type isEqual:@"final"]) {
    if (![event[@"id"] isEqual:_request]) return;
    NSString* answer = [event[@"text"] isKindOfClass:NSString.class] ? event[@"text"] : @"";
    if (!_streaming && answer.length) [self append:[@"\nBlackbird\n" stringByAppendingString:answer]];
    [self append:@"\n"];
    _status.stringValue = [NSString stringWithFormat:@"Blackbird %@", event[@"outcome"] ?: @"finished"];
    _result[@"answer"] = answer; _result[@"outcome"] = event[@"outcome"] ?: @"unknown";
    _request = nil; _streaming = NO;
    if (_smoke) _quit();
  } else if ([type isEqual:@"error"]) {
    NSString* message = [event[@"message"] isKindOfClass:NSString.class] ? event[@"message"] : @"Blackbird connection failed";
    _connectionLabel.stringValue = message; [self append:[NSString stringWithFormat:@"\n%@\n", message]];
    _result[@"blackbird_error"] = message;
    _request = _connection.activeRequestID;
    if (_smoke && _smokeObjective.length) _quit();
  } else if ([type isEqual:@"closed"]) {
    _connectionLabel.stringValue = @"Blackbird disconnected. Relaunch Oxcart to reconnect.";
    _request = nil; _streaming = NO;
  }
  [self updateButtons]; [self maybeSmoke];
}
- (void)attachBrowser:(CefRefPtr<CefBrowser>)browser {
  if (_closing || (_browser && _browser->IsSame(browser))) return;
  ++_captureEpoch; [_observer close]; _capturing = NO;
  _browser = browser; _observer = [[BSLiveObservation alloc] initWithBrowser:browser readingsURL:_readingsURL];
  NSNumber* browserID = @(browser->GetIdentifier());
  if (!_traffic[browserID]) {
    _traffic[browserID] = [[OXTrafficBrowser alloc] initWithBrowser:browser rootURL:_trafficRoot];
    NSMutableArray* paths = _result[@"traffic_directories"];
    if (!paths) { paths = [NSMutableArray array]; _result[@"traffic_directories"] = paths; }
    [paths addObject:_traffic[browserID].directoryURL.path];
  }
  if (!_input[browserID]) {
    _input[browserID] = [[OXInputBrowser alloc] initWithBrowser:browser rootURL:_inputRoot];
    __weak BSLivePanel* weakSelf = self;
    _input[browserID].failed = ^(NSString* message) {
      BSLivePanel* panel = weakSelf; if (!panel) return;
      panel->_status.stringValue = message;
      [panel append:[NSString stringWithFormat:@"\n%@\n",message]];
      panel->_result[@"input_recording_error"] = message;
      [panel updateButtons];
    };
  }
  _loading = browser->IsLoading();
  _pageLabel.stringValue = [NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()] ?: @"";
  [_extraction beginVisitWithURL:_pageLabel.stringValue title:@"Browser visit"];
  [_traffic[browserID] markContext:@{@"browser_id":browserID,@"page_url":_pageLabel.stringValue,@"lifecycle":@"selected"}];
  [_input[browserID] markContext:@{@"page_url":_pageLabel.stringValue,@"traffic_directory":_traffic[browserID].directoryURL.path,@"lifecycle":@"selected"}];
  if ([_result[@"record_input_on_start"] boolValue] && !_result[@"input_started_on_launch"]) {
    _result[@"input_started_on_launch"] = @YES; [self recordInput:nil];
  }
  [self updateButtons];
}
- (void)mainLoadStartedForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSDictionary* context = @{@"browser_id":@(browser->GetIdentifier()),@"page_url":[NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()] ?: @"",@"navigation_id":NSUUID.UUID.UUIDString,@"lifecycle":@"main_load_started"};
  [_input[@(browser->GetIdentifier())] markContext:context];
  [_traffic[@(browser->GetIdentifier())] markContext:context];
  if (!_browser || !_browser->IsSame(browser)) return;
  ++_captureEpoch; _capturing = NO; _loading = YES;
  [_observer cancel]; [_observer nativeLifecycle:@"navigation"]; _status.stringValue = @"Loading page…";
  [_extraction beginVisitWithURL:[NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()] ?: @"" title:@"Browser visit"];
  [self updateButtons];
}
- (void)mainLoadEndedForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!_browser || !_browser->IsSame(browser)) return;
  _loading = NO;
  _pageLabel.stringValue = [NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()] ?: @"";
  _status.stringValue = @"Page ready."; [self updateButtons]; [self maybeSmoke];
}
- (void)rendererTerminatedForBrowser:(CefRefPtr<CefBrowser>)browser {
  [_input[@(browser->GetIdentifier())] rendererTerminated];
  if (!_browser || !_browser->IsSame(browser)) return;
  ++_captureEpoch; _capturing = NO; [_observer cancel]; [_observer nativeLifecycle:@"renderer terminated"];
  _status.stringValue = @"Renderer stopped. Reload the page."; [self updateButtons];
}
- (void)browserClosing:(CefRefPtr<CefBrowser>)browser {
  NSNumber* identity = @(browser->GetIdentifier());
  OXInputBrowser* input = _input[identity];
  if (input) {
    dispatch_group_enter(_inputWrites);
    [input closeWithCompletion:^{ dispatch_group_leave(self->_inputWrites); }];
    [_input removeObjectForKey:identity];
  }
  OXTrafficBrowser* traffic = _traffic[identity];
  if (traffic) {
    dispatch_group_enter(_trafficWrites);
    [traffic closeWithCompletion:^{ dispatch_group_leave(self->_trafficWrites); }];
    [_traffic removeObjectForKey:identity];
  }
  if (!_browser || !_browser->IsSame(browser)) return;
  ++_captureEpoch; [_observer close]; _observer = nil; _browser = nullptr; _capturing = NO;
  _pageLabel.stringValue = @"No browser selected."; [self updateButtons];
}
- (void)capture:(void (^)(BSLivePage*))completion {
  if (!_browser || _capturing || _closing) return;
  _capturing = YES; const uint64_t epoch = ++_captureEpoch;
  _status.stringValue = @"Reading the rendered page…"; [self updateButtons];
  [_observer captureWithCompletion:^(BSLivePage* page, NSString* error) {
    if (self->_closing || epoch != self->_captureEpoch) return;
    self->_capturing = NO;
    if (!page) {
      self->_status.stringValue = error ?: @"Page reading failed. Try again.";
      self->_result[@"capture_error"] = self->_status.stringValue;
      [self->_extraction readingFailed:self->_status.stringValue];
      [self updateButtons]; if (self->_smoke) self->_quit(); return;
    }
    self->_result[@"page"] = [page nativeValue];
    [self->_extraction addReading:[page nativeValue]];
    [self->_traffic[@(self->_browser->GetIdentifier())] markContext:@{@"capture_id":page.captureId,@"reading_directory":page.directoryURL.path,@"page_url":page.url,@"lifecycle":@"reading_saved"}];
    [self->_input[@(self->_browser->GetIdentifier())] markContext:@{@"capture_id":page.captureId,@"reading_directory":page.directoryURL.path,@"page_url":page.url,@"lifecycle":@"reading_saved"}];
    self->_result[@"block_count"] = @(page.blockCount);
    self->_pageLabel.stringValue = page.url;
    self->_status.stringValue = [NSString stringWithFormat:@"Saved %lu text blocks · %llu bytes.",
        (unsigned long)page.blockCount, (unsigned long long)page.textBytes];
    [self updateButtons]; completion(page);
  }];
}
- (void)observe:(id)sender {
  (void)sender;
  [self capture:^(BSLivePage* page) {
    [self append:[NSString stringWithFormat:@"\nReading · %@\n%@\nSaved complete reading: %@\n", page.title, page.url, page.directoryURL.path]];
  }];
}
- (void)submit:(NSString*)objective page:(BSLivePage*)page {
  BOOL steer = _connection.running;
  NSString* request = [_connection sendObjective:objective observations:page ? @[[page nativeValue]] : @[] steer:steer];
  if (!request) { _status.stringValue = @"Blackbird could not accept the request."; [self updateButtons]; return; }
  _request = request; _streaming = NO;
  [self append:[NSString stringWithFormat:@"\nYou%@\n%@\n", page ? [@" · " stringByAppendingString:page.url] : @"", objective]];
  _status.stringValue = steer ? @"Steering Blackbird…" : @"Blackbird is working…";
  _composer.string = @""; [self updateButtons];
}
- (void)send:(id)sender {
  (void)sender;
  NSString* objective = [_composer.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (!objective.length || !_connection.ready || _closing || _capturing || _extraction.busy) return;
  if (_includePage.state == NSControlStateValueOn) {
    [self capture:^(BSLivePage* page) { [self submit:objective page:page]; }];
  } else [self submit:objective page:nil];
}
- (void)extract:(id)sender {
  (void)sender;
  if (!_extract.enabled) return;
  NSString* objective = [_composer.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (!objective.length) objective = @"Extract and organize the useful information from this visit, preserving source-supported detail and describing gaps.";
  [self capture:^(BSLivePage*) { [self->_extraction extract:objective]; }];
}
- (void)preview:(id)sender { (void)sender; [_extraction showPreview]; }
- (void)traffic:(id)sender { (void)sender; if (_browser) [_traffic[@(_browser->GetIdentifier())] show]; }
- (void)recordInput:(id)sender {
  (void)sender; if (!_browser || _closing) return;
  OXInputBrowser* input = _input[@(_browser->GetIdentifier())];
  if (input.activeRecordingID) {
    [input stop]; _status.stringValue = @"Input recording finished; pending observations are retained.";
  } else {
    NSURL* path = [input startWithContext:@{@"objective":_composer.string ?: @"",@"source":@"operator_native_session"}];
    if (path) {
      [self append:[NSString stringWithFormat:@"\nRecording browser input and page triggers locally: %@\n",path.path]];
      _status.stringValue = @"Recording browser input · Finish input or Stop ends recording.";
      NSMutableArray* paths = _result[@"input_directories"];
      if (!paths) { paths = [NSMutableArray array]; _result[@"input_directories"] = paths; }
      [paths addObject:path.path];
    }
  }
  [self updateButtons];
}
- (void)nativeInputEvent:(NSEvent*)event {
  for (OXInputBrowser* input in _input.allValues) [input nativeEvent:event];
}
- (BOOL)receiveInputForBrowser:(CefRefPtr<CefBrowser>)browser frame:(CefRefPtr<CefFrame>)frame
    message:(CefRefPtr<CefProcessMessage>)message {
  return [_input[@(browser->GetIdentifier())] receiveFrame:frame message:message];
}
- (void)stop:(id)sender {
  (void)sender; ++_captureEpoch; _capturing = NO; [_observer cancel];
  [_extraction stop];
  for (OXTrafficBrowser* traffic in _traffic.allValues) [traffic stop];
  for (OXInputBrowser* input in _input.allValues) [input stop];
  [_connection cancel]; _status.stringValue = @"Stop requested."; [self updateButtons];
}
- (void)maybeSmoke {
  if (!_smoke || _smokeStarted || _closing || _loading || !_browser) return;
  NSString* url = [NSString stringWithUTF8String:_browser->GetMainFrame()->GetURL().ToString().c_str()];
  if (!url.length || [url isEqual:@"about:blank"] || (_smokeObjective.length && !_connection.ready)) return;
  _smokeStarted = YES;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 800 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
    [self capture:^(BSLivePage* page) {
      if ([self->_result[@"smoke_extraction"] boolValue]) [self->_extraction extract:self->_smokeObjective];
      else if (self->_smokeObjective.length) [self submit:self->_smokeObjective page:page];
      else self->_quit();
    }];
  });
}
- (void)closeWithCompletion:(void (^)(void))completion {
  if (_closing) return;
  _closing = YES; ++_captureEpoch; [_observer close]; _observer = nil; _browser = nullptr;
  [self updateButtons];
  dispatch_group_t group = dispatch_group_create(); dispatch_group_enter(group); dispatch_group_enter(group);
  [_extraction closeWithCompletion:^{ dispatch_group_leave(group); }];
  [_connection closeWithCompletion:^{ dispatch_group_leave(group); }];
  dispatch_group_enter(group);
  dispatch_group_notify(_trafficWrites,dispatch_get_main_queue(),^{ dispatch_group_leave(group); });
  dispatch_group_enter(group);
  dispatch_group_notify(_inputWrites,dispatch_get_main_queue(),^{ dispatch_group_leave(group); });
  dispatch_group_notify(group,dispatch_get_main_queue(),completion);
}
@end
