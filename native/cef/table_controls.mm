#import "table_controls.h"
#import "observation.h"
#import "table_projection.h"
#import "continuous_clock.h"
#include "include/cef_client.h"
#include "include/cef_application_mac.h"
#include <algorithm>
#include <unistd.h>

namespace {
bool Reply(NSDictionary* reply, NSString* op) { return [reply[@"op"] isEqual:op]; }
NSTextView* TextArea(NSView* parent, NSRect frame) {
  NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:frame];
  scroll.hasVerticalScroller = YES;
  scroll.borderType = NSBezelBorder;
  NSTextView* view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
  view.editable = NO;
  view.selectable = YES;
  view.richText = NO;
  view.allowsUndo = NO;
  view.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
  view.textContainerInset = NSMakeSize(10, 10);
  view.autoresizingMask = NSViewWidthSizable;
  scroll.documentView = view;
  [parent addSubview:scroll];
  return view;
}
NSButton* Button(NSView* parent, NSString* title, id target, SEL action, NSRect frame) {
  NSButton* button = [NSButton buttonWithTitle:title target:target action:action];
  button.frame = frame; [parent addSubview:button]; return button;
}
NSString* JSON(id value) {
  NSData* bytes = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:nil];
  return bytes ? [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] : @"Unavailable";
}
}

@implementation BSOwnedTableControls {
  NSString* _origin;
  NSString* _smokeMode;
  NSMutableDictionary* _result;
  void (^_quit)(void);
  void (^_closed)(void);
  CefRefPtr<CefBrowser> _browser;
  BSNativeObservation* _reader;
  NSTextField* _status;
  NSTextView* _source;
  NSTextView* _exact;
  NSTextField* _sourceLabel;
  NSButton* _observe;
  NSButton* _save;
  NSButton* _stop;
  NSButton* _refresh;
  NSButton* _delete;
  NSPopUpButton* _retention;
  NSPopUpButton* _saved;
  NSPopUpButton* _fields;
  NSDictionary* _batch;
  NSDictionary* _review;
  NSDictionary* _guard;
  NSDictionary* _listGuard;
  NSString* _stage;
  NSString* _draftStage;
  NSString* _commit;
  NSArray<NSString*>* _commitIDs;
  NSTimer* _expiryTimer;
  NSTimer* _workloadTimer;
  id _activationObserver;
  id _wakeObserver;
  id _sessionObserver;
  uint64_t _epoch;
  uint64_t _closeDeadline;
  BOOL _busy, _ready, _loaded, _closing, _closeFinished, _smokeStarted, _stopping;
  BOOL _rustStopped, _helperStopped;
  uint64_t _requestedStop;
  uint64_t _captureStart, _lastTick, _maxTickGap, _stopTarget;
  NSUInteger _smokeObservations;
  BOOL _retentionChangedInSmoke, _captureCompleted;
  BOOL _selectedBrowserChosen;
  NSMutableArray* _smokeReviews;
  NSMutableDictionary<NSString*, NSValue*>* _sourceRanges;
  NSInteger _lifecycleStep;
  int _lifecycleFirstBrowser, _lifecycleExtraBrowser, _lifecycleLaterBrowser;
  CefRefPtr<CefClient> _lifecycleClient;
  NSDictionary* _lifecycleFirstObservation;
  NSMutableArray* _lifecycleSamples;
  NSMutableArray* _lifecycleReadGuards;
  NSTimer* _lifecycleTimer;
  NSString* _lifecycleReleasePath;
  void (^_lifecycleHeldOrdinary)(void);
  uint64_t _lifecycleStartNs;
  BOOL _lifecycleOldOrdinary;
}
- (instancetype)initWithOrigin:(NSString*)origin databaseURL:(NSURL*)databaseURL
    smokeMode:(NSString*)smokeMode result:(NSMutableDictionary*)result quit:(void (^)(void))quit {
  self = [super init];
  if (!self) return nil;
  _origin = [origin copy]; _smokeMode = [smokeMode copy]; _result = result; _quit = [quit copy];
  NSURL* directory = [[NSBundle mainBundle].executableURL URLByDeletingLastPathComponent];
  _tableConnection = [[BSTableConnection alloc]
      initWithExecutableURL:[directory URLByAppendingPathComponent:@"bow-shock-controller"]
      databaseURL:databaseURL clockProbeURL:[directory URLByAppendingPathComponent:@"bow_shock_clock_probe"]
      ownedOrigin:origin];
  NSRect screen = NSScreen.mainScreen.visibleFrame;
  NSRect controlsFrame = NSMakeRect(std::max(NSMinX(screen) + 10, NSMaxX(screen) - 600),
      std::max(NSMinY(screen) + 10, NSMaxY(screen) - 820), 580, 780);
  _panel = [[NSPanel alloc] initWithContentRect:controlsFrame
      styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  _panel.title = @"Bow Shock · observed tables"; _panel.releasedWhenClosed = NO;
  NSView* content = _panel.contentView;
  NSTextField* heading = [NSTextField labelWithString:@"Owned catalog · human review"];
  heading.font = [NSFont systemFontOfSize:19 weight:NSFontWeightSemibold];
  heading.frame = NSMakeRect(20, 738, 540, 28); [content addSubview:heading];
  _status = [NSTextField wrappingLabelWithString:@"Connecting the table controller…"];
  _status.frame = NSMakeRect(20, 677, 540, 53); [content addSubview:_status];
  _observe = Button(content, @"Observe page", self, @selector(observe:), NSMakeRect(20, 632, 145, 34));
  _retention = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(180, 635, 210, 30) pullsDown:NO];
  [_retention addItemsWithTitles:@[@"Retain for 10 minutes", @"Retain for 1 hour", @"Retain for 24 hours"]];
  _retention.target = self; _retention.action = @selector(retentionChanged:); [content addSubview:_retention];
  _save = Button(content, @"Save reviewed table", self, @selector(save:), NSMakeRect(395, 632, 165, 34));
  _fields = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, 596, 160, 28) pullsDown:NO];
  [_fields addItemsWithTitles:@[@"name", @"price", @"note", @"sku", @"quantity", @"private"]];
  _fields.target = self; _fields.action = @selector(highlightSource:); [content addSubview:_fields];
  _sourceLabel = [NSTextField labelWithString:@"Captured source · root only · children withheld"];
  _sourceLabel.frame = NSMakeRect(190, 598, 370, 23); [content addSubview:_sourceLabel];
  _source = TextArea(content, NSMakeRect(20, 323, 540, 266));
  NSTextField* exactLabel = [NSTextField labelWithString:@"Exact immutable review · source identity and retention"];
  exactLabel.frame = NSMakeRect(20, 293, 540, 24); [content addSubview:exactLabel];
  _exact = TextArea(content, NSMakeRect(20, 129, 540, 161));
  _saved = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, 88, 330, 30) pullsDown:NO];
  [_saved addItemWithTitle:@"Saved tables"]; _saved.target = self; _saved.action = @selector(selectSaved:);
  [content addSubview:_saved];
  _refresh = Button(content, @"Refresh", self, @selector(refreshSaved:), NSMakeRect(360, 85, 90, 34));
  _delete = Button(content, @"Delete", self, @selector(deleteSaved:), NSMakeRect(465, 85, 95, 34));
  _stop = Button(content, @"Stop all", self, @selector(stop:), NSMakeRect(20, 27, 140, 38));
  Button(content, @"Quit Bow Shock", self, @selector(quit:), NSMakeRect(395, 27, 165, 38));
  NSTextField* limit = [NSTextField labelWithString:@"Catalog only · up to 4 retained tables · no delegated effects"];
  limit.font = [NSFont systemFontOfSize:11]; limit.frame = NSMakeRect(20, 68, 540, 16); [content addSubview:limit];
  [self updateButtons];
  return self;
}
- (void)updateButtons {
  BOOL available = _ready && _tableConnection.connected && _controlConnection.connected && !_closing && !_stopping;
  _observe.enabled = available && _loaded && !_busy;
  _retention.enabled = available && !_busy;
  _save.enabled = available && !_busy && _review && [BSTableConnection publicationGuardIsCurrent:_guard];
  _refresh.enabled = available && !_busy;
  _saved.enabled = available && !_busy && _commitIDs.count > 0 && [BSTableConnection publicationGuardIsCurrent:_listGuard];
  _delete.enabled = available && !_busy && _commit != nil;
  _stop.enabled = !_closing && !_stopping && _tableConnection.connected && _controlConnection.connected;
}
- (void)retireDisplay {
  ++_epoch; _review = nil; _batch = nil; _stage = nil; _guard = nil; _commit = nil;
  _source.string = @""; _exact.string = @""; [self updateButtons];
  _sourceRanges = nil;
  [_fields removeAllItems];
}
- (void)clearList {
  _commitIDs = nil; _listGuard = nil; [_saved removeAllItems]; [_saved addItemWithTitle:@"Saved tables"];
  [self updateButtons];
}
- (void)unavailable:(NSString*)message {
  _busy = NO; [self retireDisplay]; _status.stringValue = message;
  if (_smokeMode && !_closing && ![self lifecycle]) { _result[@"table_workflow"] = @"failed"; _quit(); }
}
- (void)start {
  [_panel orderFront:nil];
  _result[@"table_panel_visible"] = @(_panel.isVisible);
  __weak BSOwnedTableControls* weakSelf = self;
  void (^activation)(NSNotification*) = ^(NSNotification* notification) {
    BSOwnedTableControls* controls = weakSelf; if (!controls || controls->_closing) return;
    if ([controls lifecycle]) [controls lifecycleSnapshot:[@"notification_" stringByAppendingString:notification.name]];
    [controls retireDisplay]; [controls clearList];
    if (controls->_ready) controls->_status.stringValue = @"Session activated. Observe or refresh to inspect source again.";
  };
  _activationObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification
      object:NSApp queue:NSOperationQueue.mainQueue usingBlock:activation];
  _wakeObserver = [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceDidWakeNotification
      object:nil queue:NSOperationQueue.mainQueue usingBlock:activation];
  _sessionObserver = [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceSessionDidBecomeActiveNotification
      object:nil queue:NSOperationQueue.mainQueue usingBlock:activation];
  _tableConnection.disconnectHandler = ^{
    BSOwnedTableControls* strongSelf = weakSelf; if (!strongSelf) return;
    strongSelf->_ready = NO; [strongSelf clearList];
    [strongSelf unavailable:@"Controller disconnected. Saved outcomes require recovery; manual browsing remains available."];
  };
  _expiryTimer = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer*) {
    BSOwnedTableControls* strongSelf = weakSelf; if (!strongSelf) return;
    if (strongSelf->_guard && ![BSTableConnection publicationGuardIsCurrent:strongSelf->_guard]) {
      [strongSelf retireDisplay]; strongSelf->_status.stringValue = @"Displayed source expired. Observe or refresh again.";
    }
    if (strongSelf->_listGuard && ![BSTableConnection publicationGuardIsCurrent:strongSelf->_listGuard]) [strongSelf clearList];
    [strongSelf updateButtons];
  }];
  [NSRunLoop.mainRunLoop addTimer:_expiryTimer forMode:NSRunLoopCommonModes];
  [_tableConnection startWithCompletion:^(NSDictionary* reply) {
    if (!Reply(reply, @"initialized")) { [self unavailable:@"Table controller unavailable."]; return; }
    self->_result[@"controller_initialized"] = @YES;
    self->_result[@"controller_pid"] = @(self->_tableConnection.childPid);
    [self waitForReady];
  }];
}
- (void)later:(void (^)(void))block {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), block);
}
- (void)waitForReady {
  if (_closing) return;
  [_tableConnection statusCommit:nil completion:^(NSDictionary* reply) {
    if (self->_closing) return;
    if (Reply(reply, @"table_status") && [reply[@"health"] isEqual:@"ready"]) {
      [self->_tableConnection scopeOrigin:self->_origin completion:^(NSDictionary* scoped) {
        if (!Reply(scoped, @"table_scoped")) { [self unavailable:@"Owned catalog scope unavailable."]; return; }
        NSURL* directory = [[NSBundle mainBundle].executableURL URLByDeletingLastPathComponent];
        BSTableConnection* authority = self->_tableConnection;
        self->_controlConnection = [[BSControlConnection alloc]
            initWithExecutableURL:[directory URLByAppendingPathComponent:@"bow-shock-native-control"]
            runId:authority.runId authorityAliveProvider:^{ return authority.connected; }];
        __weak BSOwnedTableControls* weakControls = self;
        self->_controlConnection.disconnectHandler = ^{
          BSOwnedTableControls* controls = weakControls;
          if (controls && !controls->_closing) { controls->_ready = NO; [controls unavailable:@"Independent control unavailable. Observation disabled."]; }
        };
        [self->_controlConnection startWithCompletion:^(NSDictionary* controlReply) {
          if (!controlReply || self->_closing) { [self unavailable:@"Independent control could not initialize."]; return; }
          self->_result[@"control_pid"] = @(self->_controlConnection.childPid);
          self->_ready = YES; self->_status.stringValue = @"Human browsing and owned catalog observation ready. No delegated input or network effects.";
          [self updateButtons]; [self maybeSmoke];
        }];
      }];
    } else if (Reply(reply, @"table_status") && [reply[@"health"] isEqual:@"opening"]) {
      [self later:^{ [self waitForReady]; }];
    } else if (Reply(reply, @"table_error") && [reply[@"code"] isEqual:@"not_ready"]) {
      [self later:^{ [self waitForReady]; }];
    } else {
      [self unavailable:@"Saved table store is unavailable or recovery is restricted. No automatic purge or retry."];
    }
  }];
}
- (void)attachBrowser:(CefRefPtr<CefBrowser>)browser {
  if ([_smokeMode isEqual:@"lifecycle-browser"]) {
    if (!_lifecycleFirstBrowser) { _lifecycleFirstBrowser = browser->GetIdentifier(); _lifecycleClient = browser->GetHost()->GetClient(); }
    else if (_lifecycleStep == 1) _lifecycleExtraBrowser = browser->GetIdentifier();
    else if (_lifecycleStep == 5) _lifecycleLaterBrowser = browser->GetIdentifier();
  }
  // This POC controls one explicitly identified browser; popups are manual.
  if (_selectedBrowserChosen) return;
  _selectedBrowserChosen = YES; _browser = browser; _loaded = NO;
  _panel.title = [NSString stringWithFormat:@"Bow Shock · browser %d · observed tables", browser->GetIdentifier()];
}
- (void)mainLoadStartedForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!_browser || !_browser->IsSame(browser)) return;
  _loaded = NO; [self retireDisplay];
  // Reader invalidation can synchronously complete an outstanding capture.
  // Retire its UI decision before that callback can inspect the old epoch.
  if (_reader) [_reader nativeLifecycle:@"native_main_load_started"];
  [self updateButtons];
  if ([_smokeMode isEqual:@"lifecycle-browser"] && _lifecycleStep == 2) [self lifecycleSnapshot:@"navigation_started"];
}
- (void)mainLoadEndedForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (_browser && _browser->IsSame(browser)) { _loaded = YES; [self updateButtons]; [self maybeSmoke]; }
  [self lifecycleBrowserLoaded:browser];
}
- (void)rendererTerminatedForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!_browser || !_browser->IsSame(browser)) return;
  _loaded = NO; [self retireDisplay];
  if (_reader) [_reader nativeLifecycle:@"native_renderer_terminated"];
  _status.stringValue = @"Renderer ended. Load the catalog again before observing.";
  if ([_smokeMode isEqual:@"lifecycle-browser"] && _lifecycleStep == 4 && ![_result[@"native_lifecycle"] isEqual:@"failed"]) {
    NSDictionary* sample = [self lifecycleSnapshot:@"renderer_terminated"];
    if (![self lifecycleRequire:!_observe.enabled && [sample[@"source_length"] unsignedLongLongValue] == 0 reason:@"renderer_not_retired"]) return;
    browser->GetHost()->CloseBrowser(false);
  }
}
- (void)browserClosing:(CefRefPtr<CefBrowser>)browser {
  if (!_browser || !_browser->IsSame(browser)) return;
  _loaded = NO; [self retireDisplay];
  if (_reader) { [_reader close]; _reader = nil; }
  _browser = nullptr; _status.stringValue = @"Observed browser closed. Other browser windows remain manual.";
  if ([_smokeMode isEqual:@"lifecycle-browser"] && _lifecycleStep == 4 && ![_result[@"native_lifecycle"] isEqual:@"failed"]) {
    [self lifecycleSnapshot:@"selected_closed"]; _lifecycleStep = 5; [self lifecycleCreateBrowser:@"amber"];
  }
}
- (uint64_t)retentionMs {
  if ([_smokeMode isEqual:@"lifecycle-display"]) return 5000;
  const uint64_t values[] = {600000, 3600000, 86400000};
  NSInteger selected = _retention.indexOfSelectedItem; return values[selected >= 0 && selected < 3 ? selected : 0];
}
- (void)observe:(id)sender {
  if (!_observe.enabled || !_browser) return;
  ++_smokeObservations;
  [self retireDisplay]; _busy = YES; uint64_t epoch = _epoch;
  _status.stringValue = @"Observing the rendered root document…"; [self updateButtons];
  if (!_reader) _reader = [[BSNativeObservation alloc] initWithBrowser:_browser
      runId:_tableConnection.runId surfaceId:[NSString stringWithFormat:@"browser-%d", _browser->GetIdentifier()]
      allowedOrigin:_origin fieldIds:@[@"name", @"price", @"note", @"sku", @"quantity", @"private"]
      secretMarkers:@[@"BS_PRIVATE_MARKER"]];
  if ([_smokeMode isEqual:@"workload"] && ![self beginWorkloadProbe]) return;
  [_reader captureFixtureWithCompletion:^(NSDictionary* record) {
    self->_busy = NO;
    if ([self->_smokeMode isEqual:@"workload"]) {
      [self workloadTick]; [self->_workloadTimer invalidate]; self->_workloadTimer = nil;
      self->_captureCompleted = YES; self->_result[@"observation"] = record;
      self->_result[@"ui_max_gap_ns"] = @(self->_maxTickGap);
      [self finishWorkloadProbe]; return;
    }
    if (epoch != self->_epoch || self->_closing) {
      if ([self->_smokeMode isEqual:@"lifecycle-browser"]) {
        self->_result[@"retired_capture_callbacks"] = @([self->_result[@"retired_capture_callbacks"] unsignedLongLongValue] + 1);
        self->_result[@"retired_capture_status"] = record[@"status"] ?: @"unavailable";
      }
      [self updateButtons]; return;
    }
    NSDictionary* batch = BSFixtureTableBatch(record, self->_tableConnection.runId, self->_origin);
    if (!batch) { [self unavailable:@"Observation withheld or not a supported owned catalog capture."]; return; }
    self->_batch = batch; self->_busy = YES;
    NSString* draft = self->_draftStage;
    void (^staged)(NSDictionary*) = ^(NSDictionary* reply) {
      self->_busy = NO;
      BOOL accepted = Reply(reply, draft ? @"table_revised" : @"table_staged");
      // Correlation metadata may survive UI retirement, while page data does
      // not. Only never-approved draft stages are reused on a fresh capture.
      if (accepted) self->_draftStage = reply[@"staging_id"];
      if (epoch != self->_epoch || self->_closing) { [self updateButtons]; return; }
      if (!accepted) { self->_draftStage = nil; [self unavailable:@"Staging unavailable. Quit cleanly and restart for a fresh session; no save was submitted."]; return; }
      self->_stage = reply[@"staging_id"]; [self requestReview:epoch];
    };
    if (draft) [self->_tableConnection reviseStaging:draft batch:batch completion:staged];
    else [self->_tableConnection stageBatch:batch completion:staged];
  }];
}
- (void)requestReview:(uint64_t)epoch {
  _busy = YES; _review = nil; [self updateButtons];
  [_tableConnection reviewStaging:_stage retentionMs:[self retentionMs] completion:^(NSDictionary* reply) {
    self->_busy = NO;
    if (epoch != self->_epoch || self->_closing) { [self updateButtons]; return; }
    if (!Reply(reply, @"table_reviewed") || ![BSTableConnection publicationGuardIsCurrent:reply[@"publication_guard"]]) {
      [self unavailable:@"Review unavailable. Observe again before saving."]; return;
    }
    self->_review = reply[@"review"]; self->_guard = reply[@"publication_guard"];
    if (self->_smokeMode) {
      if (!self->_smokeReviews) self->_smokeReviews = [NSMutableArray array];
      [self->_smokeReviews addObject:self->_review];
    }
    self->_exact.string = self->_review[@"content"];
    if (![self displayBatch:self->_batch saved:NO]) return;
    self->_status.stringValue = @"Partial table ready for review. Check field states, literal sources and retention, then Save.";
    [self updateButtons];
    if ([self->_smokeMode isEqual:@"save"]) {
      // NSTextView exposes its mutable backing string. Freeze what the person
      // saw before later display retirement clears that same backing store.
      self->_result[@"displayed_review_content"] = [self->_exact.string copy];
      [self save:nil];
    } else if ([self->_smokeMode isEqual:@"drafts"]) {
      if (!self->_retentionChangedInSmoke) {
        self->_retentionChangedInSmoke = YES;
        [self->_retention selectItemAtIndex:1]; [self retentionChanged:nil];
      } else if (self->_smokeObservations < 5) [self observe:nil];
      else {
        self->_result[@"draft_reviews"] = self->_smokeReviews;
        self->_result[@"observations"] = @(self->_smokeObservations);
        [self stop:nil];
      }
    } else [self lifecycleReviewed];
  }];
}
- (BOOL)displayBatch:(NSDictionary*)batch saved:(BOOL)saved {
  NSMutableString* text = [NSMutableString stringWithFormat:@"%@\n%@\n\n", saved ? @"Saved capture; not current page evidence" : @"Current captured source",
      saved ? @"Provenance shown as recorded; absent details remain unavailable" : @"Root-only · child frames withheld · not an atomic DOM snapshot"];
  NSMutableDictionary* ranges = [NSMutableDictionary dictionary];
  NSMutableArray* choices = [NSMutableArray array];
  NSArray* rows = batch[@"rows"];
  NSUInteger rowIndex = 0;
  for (NSDictionary* row in rows) {
    ++rowIndex;
    if (rows.count > 1) [text appendFormat:@"Row %lu\n\n", static_cast<unsigned long>(rowIndex)];
    NSUInteger fieldIndex = 0;
    for (NSDictionary* field in row[@"fields"]) {
    ++fieldIndex;
    NSDictionary* state = field[@"state"]; NSDictionary* source = field[@"source"];
    [text appendFormat:@"%@ [%@]\n", field[@"name"], state[@"kind"]];
    if (state[@"value"]) [text appendFormat:@"Value: %@\n", state[@"value"]];
    if (state[@"candidates"]) [text appendFormat:@"Candidates: %@\n", [state[@"candidates"] componentsJoinedByString:@" | "]];
    if (state[@"reason"]) [text appendFormat:@"Reason: %@\n", state[@"reason"]];
    NSString* fragment = source[@"fragment"] ?: @"unavailable";
    [text appendString:@"Literal source: "];
    NSString* choice = rows.count == 1 ? field[@"name"] : [NSString stringWithFormat:@"%lu · %@", static_cast<unsigned long>(rowIndex), field[@"name"]];
    if (ranges[choice]) choice = [choice stringByAppendingFormat:@" (%lu)", static_cast<unsigned long>(fieldIndex)];
    [choices addObject:choice];
    ranges[choice] = [NSValue valueWithRange:NSMakeRange(text.length, fragment.length)];
    [text appendFormat:@"%@\n", fragment];
    [text appendFormat:@"Visibility: %@ · normalization: %@\n", source[@"visibility"], source[@"normalization"]];
    [text appendFormat:@"Capture identity: %@\n\n", JSON(source[@"observation"])];
    }
  }
  if (![BSTableConnection publicationGuardIsCurrent:_guard]) {
    [self unavailable:@"Source expired before display. Observe or refresh again."]; return NO;
  }
  [_fields removeAllItems]; [_fields addItemsWithTitles:choices];
  _sourceLabel.stringValue = saved ? @"Saved source · original provenance" : @"Captured source · root only · children withheld";
  _sourceRanges = ranges; _source.string = text; [self highlightSource:nil]; return YES;
}
- (void)highlightSource:(id)sender {
  NSValue* selected = _sourceRanges[_fields.titleOfSelectedItem];
  NSRange range = selected ? selected.rangeValue : NSMakeRange(NSNotFound, 0);
  if (range.location != NSNotFound && NSMaxRange(range) <= _source.string.length) {
    [_source setSelectedRange:range]; [_source scrollRangeToVisible:range];
  }
}
- (void)retentionChanged:(id)sender {
  if (_busy || !_stage || !_batch || _closing || _stopping) return;
  ++_epoch; uint64_t epoch = _epoch; _review = nil; _exact.string = @"";
  _busy = YES; [self updateButtons];
  [_tableConnection reviseStaging:_stage batch:_batch completion:^(NSDictionary* reply) {
    void (^continuation)(void) = ^{
      self->_busy = NO;
      if (epoch != self->_epoch || self->_closing) { [self updateButtons]; return; }
      if (!Reply(reply, @"table_revised")) { [self unavailable:@"Retention change needs a new observation."]; return; }
      [self requestReview:epoch];
    };
    if ([self->_smokeMode isEqual:@"lifecycle-stop"] && self->_lifecycleStep == 1 && Reply(reply, @"table_revised")) {
      // Defer the actual validated ordinary UI continuation, not its wire reply.
      // The app and independent worker continue serving while the driver holds
      // only the exact owned Rust child, then releases this fixture barrier.
      self->_lifecycleHeldOrdinary = [continuation copy];
      [self lifecycleSnapshot:@"ordinary_ack_received"];
      fprintf(stderr, "BS_LIFECYCLE stop_ready app=%d rust=%d\n", getpid(), self->_tableConnection.childPid); fflush(stderr);
    } else continuation();
  }];
}
- (void)save:(id)sender {
  if (!_save.enabled) return;
  uint64_t epoch = _epoch; NSDictionary* exactReview = _review; NSDictionary* guard = _guard;
  // After dispatch an approval may have been accepted even if its ACK is lost.
  // Never revise that stage automatically and risk deleting an admitted save.
  _draftStage = nil;
  _busy = YES; _status.stringValue = @"Approving the exact displayed review…"; [self updateButtons];
  [_tableConnection approveReview:exactReview publicationGuard:guard completion:^(NSDictionary* reply) {
    self->_busy = NO;
    if (epoch != self->_epoch || self->_closing) { [self updateButtons]; return; }
    if (!Reply(reply, @"table_approved")) { [self unavailable:@"Approval unavailable. This POC holds 4 table records; delete unwanted captures and quit cleanly before restarting."]; return; }
    self->_busy = YES; self->_status.stringValue = @"Save queued; waiting for durable table acknowledgement…";
    [self->_tableConnection commitApproval:reply[@"approval_id"] completion:^(NSDictionary* commitReply) {
      self->_busy = NO;
      if (!Reply(commitReply, @"table_committed")) {
        if (epoch == self->_epoch && !self->_closing) [self unavailable:@"Save acknowledgement unavailable. Refresh saved tables to discover outcomes; do not resubmit."];
        return;
      }
      NSString* commit = commitReply[@"commit_id"];
      if (epoch != self->_epoch || self->_closing) { [self updateButtons]; return; }
      self->_commit = commit; self->_review = nil;
      [self waitForCommit:commit epoch:epoch];
    }];
  }];
}
- (void)waitForCommit:(NSString*)commit epoch:(uint64_t)epoch {
  if (epoch != _epoch || _closing) return;
  _busy = YES; [self updateButtons];
  [_tableConnection statusCommit:commit completion:^(NSDictionary* reply) {
    self->_busy = NO;
    if (epoch != self->_epoch || self->_closing) { [self updateButtons]; return; }
    if (!Reply(reply, @"table_status") || ![reply[@"health"] isEqual:@"ready"]) {
      [self unavailable:@"Save status unavailable. Recover by the original identity or fresh saved list."]; return;
    }
    if ([reply[@"state"] isEqual:@"committed"]) [self read:commit epoch:epoch smokeSave:YES];
    else if ([@[@"preparing", @"admission_pending", @"admitted", @"writing"] containsObject:reply[@"state"]]) {
      self->_status.stringValue = @"Save pending; no durable result yet.";
      self->_busy = YES; [self later:^{ self->_busy = NO; [self waitForCommit:commit epoch:epoch]; }];
    } else [self unavailable:@"Save was rejected or its outcome is unknown. No automatic resubmission."];
  }];
}
- (void)read:(NSString*)commit epoch:(uint64_t)epoch smokeSave:(BOOL)smokeSave {
  _busy = YES; [self updateButtons];
  [_tableConnection readCommit:commit completion:^(NSDictionary* reply) {
    self->_busy = NO;
    if (epoch != self->_epoch || self->_closing) { [self updateButtons]; return; }
    if (!Reply(reply, @"table_read") || ![BSTableConnection publicationGuardIsCurrent:reply[@"publication_guard"]]) {
      [self unavailable:@"Saved source expired or is unavailable."]; return;
    }
    self->_commit = commit; self->_batch = reply[@"batch"]; self->_guard = reply[@"publication_guard"];
    self->_review = nil; self->_stage = nil; self->_exact.string = @"Saved content is shown with its original provenance. Approval from this run was not restored.";
    if (![self displayBatch:self->_batch saved:YES]) return;
    self->_status.stringValue = @"Saved table acknowledged; original captured source shown.";
    [self updateButtons];
    if (self->_smokeMode) {
      if ([self lifecycle]) [self lifecycleSavedRead:commit];
      else {
        self->_result[@"table_workflow"] = @"pass";
        if (smokeSave) { self->_result[@"commit_id"] = commit; self->_result[@"saved_batch"] = self->_batch; }
        self->_quit();
      }
    }
  }];
}
- (void)refreshSaved:(id)sender {
  if (_busy || !_ready || _closing || _stopping) return;
  [self retireDisplay]; [self clearList]; uint64_t epoch = _epoch; _busy = YES; [self updateButtons];
  [_tableConnection listWithCompletion:^(NSDictionary* reply) {
    self->_busy = NO;
    if (epoch != self->_epoch || self->_closing) { [self updateButtons]; return; }
    if (!Reply(reply, @"table_listed") || ![BSTableConnection publicationGuardIsCurrent:reply[@"publication_guard"]]) {
      [self unavailable:@"Saved table list unavailable."]; return;
    }
    self->_commitIDs = reply[@"commit_ids"]; self->_listGuard = reply[@"publication_guard"];
    [self->_saved removeAllItems]; [self->_saved addItemWithTitle:@"Select a saved capture"];
    [self->_saved addItemsWithTitles:self->_commitIDs];
    self->_status.stringValue = self->_commitIDs.count ? @"Select a saved capture to inspect its original source." : @"No retained tables in this store.";
    [self updateButtons];
    if ([self->_smokeMode isEqual:@"reopen"]) {
      self->_result[@"commit_ids"] = self->_commitIDs;
      if (self->_commitIDs.count == 0) { [self unavailable:@"No same-boot retained rows reopened."]; return; }
      [self->_saved selectItemAtIndex:1]; [self selectSaved:nil];
    } else if ([self->_smokeMode isEqual:@"lifecycle-display"]) {
      if (![self lifecycleRequire:self->_commitIDs.count == 1 reason:@"saved_list_missing"]) return;
      [self->_saved selectItemAtIndex:1]; [self selectSaved:nil];
    }
  }];
}
- (void)selectSaved:(id)sender {
  if (_busy || _closing || _stopping || ![BSTableConnection publicationGuardIsCurrent:_listGuard]) return;
  NSInteger index = _saved.indexOfSelectedItem - 1;
  if (index < 0 || static_cast<NSUInteger>(index) >= _commitIDs.count) return;
  NSString* commit = _commitIDs[static_cast<NSUInteger>(index)];
  [self retireDisplay]; [self read:commit epoch:_epoch smokeSave:NO];
}
- (void)deleteSaved:(id)sender {
  if (!_delete.enabled) return;
  NSString* commit = _commit; [self retireDisplay]; _busy = YES; [self updateButtons];
  [_tableConnection deleteCommit:commit completion:^(NSDictionary* reply) {
    self->_busy = NO;
    if (self->_closing) return;
    self->_status.stringValue = Reply(reply, @"table_deleted") ? @"Managed access denied; deletion queued. Refresh to inspect remaining tables." : @"Deletion acknowledgement unavailable; outcome may be unknown.";
    [self clearList]; [self updateButtons];
  }];
}
- (void)stop:(id)sender {
  if (!_stop.enabled) return;
  if ([_smokeMode isEqual:@"workload"]) {
    NSDictionary* now = BSContinuousClockWitness();
    _result[@"stop_handler_ns"] = now[@"continuous_ns"] ?: @0;
    _result[@"stop_during_capture"] = @(!_captureCompleted);
  }
  if (_tableConnection.stopGeneration == UINT64_MAX) {
    [_controlConnection invalidate]; [_tableConnection invalidate];
    [self unavailable:@"Stop counter exhausted. Connections have been closed."]; return;
  }
  // Sole UI Stop caller mirrors the next Rust fence conservatively before its
  // ACK. This grants no effect; disagreement closes both connections.
  _requestedStop = _tableConnection.stopGeneration + 1;
  _rustStopped = NO; _helperStopped = NO;
  _stopping = YES; [self retireDisplay]; [self clearList]; _status.stringValue = @"Stopping new delegated work…";
  [_tableConnection stopAllWithCompletion:^(NSDictionary* reply) {
    if (!Reply(reply, @"stopped") || [reply[@"stop_generation"] unsignedLongLongValue] != self->_requestedStop) {
      [self->_controlConnection invalidate]; [self->_tableConnection invalidate];
      [self unavailable:@"Stop acknowledgement unavailable. Connections have been closed."]; return;
    }
    self->_result[@"controller_stop_generation"] = reply[@"stop_generation"];
    if ([self->_smokeMode isEqual:@"workload"]) self->_result[@"stop_rust_ack_ns"] = BSContinuousClockWitness()[@"continuous_ns"] ?: @0;
    self->_rustStopped = YES; [self finishStop];
  }];
  [_controlConnection fenceToGeneration:_requestedStop completion:^(NSDictionary* fence) {
    if (!fence || [fence[@"stop_generation"] unsignedLongLongValue] != self->_requestedStop) {
      [self->_controlConnection invalidate]; [self->_tableConnection invalidate];
      [self unavailable:@"Control fence acknowledgement unavailable. Connections have been closed."]; return;
    }
    if ([self->_smokeMode isEqual:@"workload"]) self->_result[@"stop_helper_ack_ns"] = BSContinuousClockWitness()[@"continuous_ns"] ?: @0;
    self->_helperStopped = YES; [self finishStop];
    [self lifecycleHeldStopReady];
  }];
}
- (void)finishStop {
  if (!_rustStopped || !_helperStopped) return;
  _stopping = NO;
  _status.stringValue = @"Stopped. Permitted saved rows remain; fresh observation and review are required before Save.";
  [self updateButtons];
  if ([_smokeMode isEqual:@"drafts"]) {
    _result[@"stop_cleared_review"] = @(!_review && _source.string.length == 0 && _exact.string.length == 0);
    _result[@"table_workflow"] = @"pass"; _quit();
  } else if ([_smokeMode isEqual:@"workload"]) [self finishWorkloadProbe];
  else if ([_smokeMode isEqual:@"lifecycle-stop"] && _lifecycleStep == 3) {
    [self lifecycleSnapshot:@"stop_reconciled"];
    [self lifecycleFinish];
  }
}
- (BOOL)beginWorkloadProbe {
  NSDictionary* sample = BSContinuousClockWitness();
  _captureStart = [sample[@"continuous_ns"] unsignedLongLongValue];
  _lastTick = _captureStart; _maxTickGap = 0; _captureCompleted = NO;
  if (!sample || _captureStart > UINT64_MAX - 20000000) { [self unavailable:@"Native workload clock unavailable."]; return NO; }
  _stopTarget = _captureStart + 20000000;
  _result[@"capture_started_ns"] = @(_captureStart); _result[@"stop_target_ns"] = @(_stopTarget);
  __weak BSOwnedTableControls* weakSelf = self;
  _workloadTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:YES block:^(NSTimer*) { [weakSelf workloadTick]; }];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
    if (!self->_closing) [self stop:nil];
  });
  return YES;
}
- (void)workloadTick {
  NSDictionary* sample = BSContinuousClockWitness(); uint64_t now = [sample[@"continuous_ns"] unsignedLongLongValue];
  if (!sample || now < _lastTick) { _maxTickGap = UINT64_MAX; return; }
  _maxTickGap = std::max(_maxTickGap, now - _lastTick); _lastTick = now;
}
- (void)finishWorkloadProbe {
  if (!_captureCompleted || !_rustStopped || !_helperStopped || _closing) return;
  _result[@"capture_workload"] = @"recorded"; _result[@"table_workflow"] = @"pass"; _quit();
}
- (BOOL)lifecycle { return [_smokeMode hasPrefix:@"lifecycle-"]; }
- (void)configureLifecycleReleasePath:(NSString*)path {
  if ([self lifecycle] && path.isAbsolutePath) _lifecycleReleasePath = [path copy];
}
- (NSDictionary*)lifecycleSnapshot:(NSString*)name {
  NSDictionary* sample = @{@"stage": name, @"clock": BSContinuousClockWitness() ?: @{},
      @"browser_id": @(_browser ? _browser->GetIdentifier() : 0), @"epoch": @(_epoch),
      @"source_length": @(_source.string.length), @"exact_length": @(_exact.string.length),
      @"review_present": @(_review != nil), @"list_count": @(_commitIDs.count),
      @"observe": @(_observe.enabled), @"save": @(_save.enabled), @"retention": @(_retention.enabled),
      @"refresh": @(_refresh.enabled), @"saved": @(_saved.enabled), @"delete": @(_delete.enabled),
      @"stop": @(_stop.enabled), @"busy": @(_busy), @"stopping": @(_stopping),
      @"rust_generation": @(_tableConnection.stopGeneration),
      @"helper_generation": @(_controlConnection.acknowledgedGeneration)};
  if (!_lifecycleSamples) _lifecycleSamples = [NSMutableArray array];
  [_lifecycleSamples addObject:sample]; _result[@"lifecycle_samples"] = _lifecycleSamples;
  return sample;
}
- (BOOL)lifecycleRequire:(BOOL)condition reason:(NSString*)reason {
  if (condition) return YES;
  _result[@"native_lifecycle"] = @"failed"; _result[@"lifecycle_failure"] = reason;
  _status.stringValue = @"Owned lifecycle fixture failed.";
  fprintf(stderr, "BS_LIFECYCLE failed %s\n", reason.UTF8String); fflush(stderr);
  _quit(); return NO;
}
- (void)lifecycleFinish {
  _result[@"native_lifecycle"] = @"pass";
  [_lifecycleTimer invalidate]; _lifecycleTimer = nil;
  _quit();
}
- (void)lifecycleStartTimer {
  if (_lifecycleTimer) return;
  _lifecycleStartNs = [BSContinuousClockWitness()[@"continuous_ns"] unsignedLongLongValue];
  __weak BSOwnedTableControls* weakSelf = self;
  _lifecycleTimer = [NSTimer timerWithTimeInterval:0.01 repeats:YES block:^(NSTimer*) { [weakSelf lifecycleTick]; }];
  [NSRunLoop.mainRunLoop addTimer:_lifecycleTimer forMode:NSRunLoopCommonModes];
}
- (void)lifecycleReviewed {
  if (![self lifecycle]) return;
  [self lifecycleStartTimer];
  if ([_smokeMode isEqual:@"lifecycle-browser"] && _lifecycleStep == 0) {
    if (![self lifecycleRequire:[_source.string containsString:@"Value: Amber"] reason:@"initial_amber_missing"]) return;
    _lifecycleFirstObservation = _batch[@"rows"][0][@"fields"][0][@"source"][@"observation"];
    [self lifecycleSnapshot:@"amber_reviewed"]; _lifecycleStep = 1; [self lifecycleCreateBrowser:@"birch"];
  } else if ([_smokeMode isEqual:@"lifecycle-browser"] && _lifecycleStep == 10) {
    if (![self lifecycleRequire:_browser && _browser->GetIdentifier() == _lifecycleFirstBrowser &&
        [_source.string containsString:@"Value: Amber"] reason:@"extra_browser_capture_wrong_surface"]) return;
    _lifecycleFirstObservation = _batch[@"rows"][0][@"fields"][0][@"source"][@"observation"];
    [self lifecycleSnapshot:@"extra_reviewed"];
    _lifecycleStep = 2; [self observe:nil];
    _browser->GetMainFrame()->LoadURL([_origin stringByAppendingString:@"/birch"].UTF8String);
  } else if ([_smokeMode isEqual:@"lifecycle-browser"] && _lifecycleStep == 3) {
    NSDictionary* ref = _batch[@"rows"][0][@"fields"][0][@"source"][@"observation"];
    BOOL correct = [_source.string containsString:@"Value: Birch"] && [ref[@"surface_id"] isEqual:_lifecycleFirstObservation[@"surface_id"]] &&
        ![ref[@"document_id"] isEqual:_lifecycleFirstObservation[@"document_id"]];
    if (![self lifecycleRequire:correct reason:@"navigation_provenance_wrong"]) return;
    _result[@"navigation_refs"] = @[_lifecycleFirstObservation, ref];
    [self lifecycleSnapshot:@"birch_reviewed"]; _lifecycleStep = 4;
    // Matched Page.pdl: Page.crash crashes the owned renderer and generates a
    // minidump. This fixed fault command is unavailable to normal POC/model UI.
    int id = _browser->GetHost()->ExecuteDevToolsMethod(0, "Page.crash", CefDictionaryValue::Create());
    [self lifecycleRequire:id > 0 reason:@"crash_command_not_accepted"];
  } else if ([_smokeMode isEqual:@"lifecycle-stop"] && _lifecycleStep == 0) {
    _lifecycleStep = 1; [_retention selectItemAtIndex:1]; [self retentionChanged:nil];
  } else if ([_smokeMode isEqual:@"lifecycle-display"] && _lifecycleStep == 0) {
    [self lifecycleSnapshot:@"before_review_activation"];
    if (![self lifecycleRequire:_review && _save.enabled reason:@"review_activation_fixture_missing"]) return;
    [NSNotificationCenter.defaultCenter postNotificationName:NSApplicationDidBecomeActiveNotification object:NSApp];
    [self lifecycleSnapshot:@"after_review_activation"];
    if (![self lifecycleRequire:!_review && !_save.enabled && _source.string.length == 0 && _exact.string.length == 0
        reason:@"review_activation_not_retired"]) return;
    _lifecycleStep = -1; [self observe:nil];
  } else if ([_smokeMode isEqual:@"lifecycle-display"] && _lifecycleStep == -1) [self save:nil];
}
- (void)lifecycleCreateBrowser:(NSString*)page {
  CefWindowInfo window; window.runtime_style = CEF_RUNTIME_STYLE_CHROME;
  window.bounds = CefRect(160, 140, 900, 650); CefBrowserSettings settings;
  BOOL created = CefBrowserHost::CreateBrowser(window, _lifecycleClient,
      [_origin stringByAppendingFormat:@"/%@", page].UTF8String, settings, nullptr, nullptr);
  [self lifecycleRequire:created reason:@"extra_browser_create_failed"];
}
- (void)lifecycleBrowserLoaded:(CefRefPtr<CefBrowser>)browser {
  if (![_smokeMode isEqual:@"lifecycle-browser"] || _closing || [_result[@"native_lifecycle"] isEqual:@"failed"]) return;
  NSView* view = CAST_CEF_WINDOW_HANDLE_TO_NSVIEW(browser->GetHost()->GetWindowHandle());
  if (!_result[@"lifecycle_windows"]) _result[@"lifecycle_windows"] = [NSMutableArray array];
  [_result[@"lifecycle_windows"] addObject:@{@"browser_id": @(browser->GetIdentifier()), @"visible": @([view.window isVisible])}];
  if (_lifecycleStep == 1 && browser->GetIdentifier() == _lifecycleExtraBrowser) {
    _result[@"browser_ids"] = @[@(_lifecycleFirstBrowser), @(_lifecycleExtraBrowser)];
    [self lifecycleSnapshot:@"extra_loaded"];
    if (![self lifecycleRequire:_browser && _browser->GetIdentifier() == _lifecycleFirstBrowser && _observe.enabled
        reason:@"extra_browser_retargeted"]) return;
    // Another native window may legitimately activate the app and retire its
    // cached display. A fresh real capture must still read selected Amber.
    _lifecycleStep = 10; [self observe:nil];
  } else if (_lifecycleStep == 5 && browser->GetIdentifier() == _lifecycleLaterBrowser) {
    _result[@"later_browser_id"] = @(_lifecycleLaterBrowser);
    [self lifecycleSnapshot:@"later_browser_loaded"];
    if (![self lifecycleRequire:!_browser && !_observe.enabled && _source.string.length == 0 &&
        _exact.string.length == 0 reason:@"retired_browser_implicitly_reselected"]) return;
    [self lifecycleFinish];
  }
}
- (void)lifecycleSavedRead:(NSString*)commit {
  if (![_smokeMode isEqual:@"lifecycle-display"]) return;
  if (!_lifecycleReadGuards) _lifecycleReadGuards = [NSMutableArray array];
  [_lifecycleReadGuards addObject:_guard]; _result[@"lifecycle_read_guards"] = _lifecycleReadGuards;
  if (_lifecycleStep == -1) {
    _result[@"lifecycle_commit_id"] = commit; _result[@"lifecycle_original_guard"] = _guard;
    _lifecycleStep = 1; [self refreshSaved:nil]; return;
  }
  if (_lifecycleStep == 1 || _lifecycleStep == 2) {
    NSString* stage = _lifecycleStep == 1 ? @"activation" : @"session";
    [self lifecycleSnapshot:[@"before_" stringByAppendingString:stage]];
    if (_lifecycleStep == 1) [NSNotificationCenter.defaultCenter postNotificationName:NSApplicationDidBecomeActiveNotification object:NSApp];
    else [NSWorkspace.sharedWorkspace.notificationCenter postNotificationName:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
    [self lifecycleSnapshot:[@"after_" stringByAppendingString:stage]];
    if (![self lifecycleRequire:_source.string.length == 0 && _exact.string.length == 0 && !_review &&
        _commitIDs.count == 0 && !_saved.enabled && !_save.enabled reason:@"activation_display_or_list_not_retired"]) return;
    ++_lifecycleStep; [self refreshSaved:nil];
  } else if (_lifecycleStep == 3) {
    if (![self lifecycleRequire:[_guard isEqual:_result[@"lifecycle_original_guard"]] reason:@"saved_deadline_extended"]) return;
    [_expiryTimer invalidate]; _expiryTimer = nil;
    [self lifecycleSnapshot:@"before_expiry_wait"]; _lifecycleStep = 4;
  }
}
- (void)lifecycleHeldStopReady {
  if (![_smokeMode isEqual:@"lifecycle-stop"] || _lifecycleStep != 2 || !_helperStopped || !_lifecycleOldOrdinary) return;
  NSDictionary* sample = [self lifecycleSnapshot:@"stop_while_rust_held"];
  BOOL disabled = !_observe.enabled && !_save.enabled && !_retention.enabled && !_refresh.enabled && !_saved.enabled && !_delete.enabled;
  if (![self lifecycleRequire:disabled && _stopping && !_rustStopped && _tableConnection.stopGeneration == 0 &&
      _controlConnection.acknowledgedGeneration == 1 && [sample[@"source_length"] unsignedLongLongValue] == 0 &&
      [sample[@"exact_length"] unsignedLongLongValue] == 0 reason:@"held_stop_or_old_callback_unsafe"]) return;
  _lifecycleStep = 3;
  fprintf(stderr, "BS_LIFECYCLE stop_held rust=%d\n", _tableConnection.childPid); fflush(stderr);
}
- (void)lifecycleTick {
  if (_closing || [_result[@"native_lifecycle"] isEqual:@"failed"]) return;
  NSDictionary* witness = BSContinuousClockWitness(); uint64_t now = [witness[@"continuous_ns"] unsignedLongLongValue];
  if (![self lifecycleRequire:witness && now >= _lifecycleStartNs && now - _lifecycleStartNs < 20000000000 reason:@"lifecycle_deadline"]) return;
  if ([_smokeMode isEqual:@"lifecycle-browser"] && _lifecycleStep == 2 && _loaded && _observe.enabled) {
    _lifecycleStep = 3; [self observe:nil];
  } else if ([_smokeMode isEqual:@"lifecycle-stop"] && _lifecycleStep == 1 && _lifecycleHeldOrdinary &&
      [[NSFileManager defaultManager] fileExistsAtPath:_lifecycleReleasePath]) {
    _lifecycleStep = 2; [self stop:nil];
    void (^old)(void) = _lifecycleHeldOrdinary; _lifecycleHeldOrdinary = nil;
    old(); _lifecycleOldOrdinary = YES; [self lifecycleSnapshot:@"old_ordinary_callback"]; [self lifecycleHeldStopReady];
  } else if ([_smokeMode isEqual:@"lifecycle-display"] && _lifecycleStep == 4 &&
      now >= [_guard[@"valid_until_ns"] unsignedLongLongValue]) {
    [self lifecycleSnapshot:@"expired_before_wake"];
    if (![self lifecycleRequire:_source.string.length > 0 reason:@"wake_fixture_did_not_hold_display"]) return;
    [NSWorkspace.sharedWorkspace.notificationCenter postNotificationName:NSWorkspaceDidWakeNotification object:nil];
    [self lifecycleSnapshot:@"expired_after_wake"];
    if (![self lifecycleRequire:_source.string.length == 0 && _exact.string.length == 0 && !_save.enabled &&
        !_saved.enabled && _commitIDs.count == 0 reason:@"wake_expired_display_not_retired"]) return;
    [self lifecycleFinish];
  }
}
- (void)quit:(id)sender { _quit(); }
- (void)maybeSmoke {
  if (!_smokeMode || _smokeStarted || !_loaded || !_ready || _closing) return;
  _smokeStarted = YES;
  // Actual native actions; no synthetic keyboard/mouse or page evaluate.
  [self later:^{
    if ([self->_smokeMode isEqual:@"reopen"]) [self refreshSaved:nil];
    else [self observe:nil];
  }];
}
- (void)closeWithCompletion:(void (^)(void))completion {
  if (_closing) return;
  _closing = YES; _closed = [completion copy]; [self retireDisplay]; [self clearList];
  [_expiryTimer invalidate]; _expiryTimer = nil;
  [_workloadTimer invalidate]; _workloadTimer = nil;
  [_lifecycleTimer invalidate]; _lifecycleTimer = nil; _lifecycleHeldOrdinary = nil; _lifecycleClient = nullptr;
  [NSNotificationCenter.defaultCenter removeObserver:_activationObserver]; _activationObserver = nil;
  [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:_wakeObserver]; _wakeObserver = nil;
  [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:_sessionObserver]; _sessionObserver = nil;
  if (_reader) { [_reader close]; _reader = nil; } _browser = nullptr;
  NSDictionary* witness = BSContinuousClockWitness();
  uint64_t now = [witness[@"continuous_ns"] unsignedLongLongValue];
  _closeDeadline = witness && now <= UINT64_MAX - 5000000000 ? now + 5000000000 : 0;
  _status.stringValue = @"Closing the table store cleanly…"; [self attemptClose];
}
- (void)finishClose:(BOOL)clean {
  if (_closeFinished) return; _closeFinished = YES;
  _result[@"table_closed"] = @(clean);
  if (!clean) { _status.stringValue = @"Close failed. Store recovery remains dirty or unknown."; fprintf(stderr, "Bow Shock table close failed; recovery remains dirty or unknown.\n"); }
  [_controlConnection invalidate]; [_tableConnection invalidate];
  void (^done)(void) = _closed; _closed = nil; if (done) done();
}
- (void)attemptClose {
  NSDictionary* witness = BSContinuousClockWitness();
  if (!witness || [witness[@"continuous_ns"] unsignedLongLongValue] >= _closeDeadline || !_tableConnection.connected) {
    [self finishClose:NO]; return;
  }
  [_tableConnection closeWithCompletion:^(NSDictionary* reply) {
    if (Reply(reply, @"table_closed")) {
      [self->_tableConnection shutdownWithCompletion:^(NSDictionary* shutdown) { [self finishClose:Reply(shutdown, @"shutdown")]; }];
    } else if (reply && self->_tableConnection.connected) {
      [self later:^{ [self attemptClose]; }];
    } else [self finishClose:NO];
  }];
}
- (void)finishTermination {
  [_controlConnection invalidate]; [_tableConnection invalidate];
  [_controlConnection waitForTermination]; [_tableConnection waitForTermination];
  [_panel orderOut:nil];
}
@end
