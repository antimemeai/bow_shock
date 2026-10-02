#import <Cocoa/Cocoa.h>
#import "controller_connection.h"
#import "observation.h"
#import "continuous_clock.h"
#import "table_controls.h"

#include "include/cef_app.h"
#include "include/base/cef_callback.h"
#include "include/base/cef_bind.h"
#include "include/cef_application_mac.h"
#include "include/cef_browser.h"
#include "include/cef_command_line.h"
#include "include/cef_display_handler.h"
#include "include/cef_life_span_handler.h"
#include "include/cef_load_handler.h"
#include "include/cef_request_handler.h"
#include "include/cef_task.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

class BrowserClient;
static CefRefPtr<BrowserClient> client;
static NSMutableDictionary* smokeResult;
static NSString* smokeOutput;
static NSString* initialURL;
static NSString* sandboxProbe;
static NSString* sandboxProbeOutside;
static BSControllerConnection* controller;
static BSNativeObservation* observation;
static NSString* observationOrigin;
static NSArray<NSString*>* observationFields;
static NSArray<NSString*>* observationMarkers;
static BOOL pauseObservationAtStart;
static BSOwnedTableControls* tableControls;
static NSString* tableOrigin;
static NSString* tableDatabase;
static NSString* tableSmokeMode;

static void SmokeStage(const char* stage) {
  if (smokeOutput) fprintf(stderr, "BS_LIFETIME %s\n", stage);
}

@interface BowShockApplication : NSApplication <CefAppProtocol> {
  BOOL _sending;
}
@end

@interface BowShockDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSPanel* controls;
@property(nonatomic, strong) NSTextField* status;
@property(nonatomic, strong) NSButton* stop;
@property(nonatomic) BOOL observationFinished;
- (void)closeBrowsers;
- (void)stopAll:(id)sender;
- (void)finishSmoke;
@end

static BowShockDelegate* delegate;

class BrowserClient final : public CefClient,
                            public CefLifeSpanHandler,
                            public CefLoadHandler,
                            public CefDisplayHandler,
                            public CefRequestHandler {
 public:
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }

  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override {
    CEF_REQUIRE_UI_THREAD();
    SmokeStage("browser_created");
    browsers_.push_back(browser);
    if (tableControls) [tableControls attachBrowser:browser];
    smokeResult[@"browser_created"] = @YES;
  }

  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override {
    CEF_REQUIRE_UI_THREAD();
    SmokeStage("browser_before_close");
    if (tableControls) [tableControls browserClosing:browser];
    if (observation) { [observation close]; observation = nil; }
    browsers_.erase(std::remove_if(browsers_.begin(), browsers_.end(),
                                  [&](const auto& item) { return item->IsSame(browser); }), browsers_.end());
    if (browsers_.empty()) {
      smokeResult[@"browser_closed"] = @YES;
      if (tableControls) [tableControls closeWithCompletion:^{ CefQuitMessageLoop(); }];
      else CefQuitMessageLoop();
    }
  }

  void OnTitleChange(CefRefPtr<CefBrowser>, const CefString& title) override {
    CEF_REQUIRE_UI_THREAD();
    if (smokeOutput && title.length() <= 4096) {
      smokeResult[@"loaded_title"] = [NSString stringWithUTF8String:title.ToString().c_str()];
    }
  }

  void OnLoadEnd(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int status) override {
    CEF_REQUIRE_UI_THREAD();
    if (frame->IsMain()) SmokeStage("main_load_ended");
    if (frame->IsMain() && tableControls) [tableControls mainLoadEndedForBrowser:browser];
    if (smokeOutput && frame->IsMain() && !smokeScheduled_) {
      smokeScheduled_ = true;
      smokeResult[@"load_status"] = @(status);
      NSView* view = CAST_CEF_WINDOW_HANDLE_TO_NSVIEW(browser->GetHost()->GetWindowHandle());
      smokeResult[@"native_window_visible"] = @([view.window isVisible]);
      if (observationOrigin) {
        NSString* surface = [NSString stringWithFormat:@"browser-%d", browser->GetIdentifier()];
        observation = [[BSNativeObservation alloc] initWithBrowser:browser runId:controller.runId
            surfaceId:surface allowedOrigin:observationOrigin fieldIds:observationFields
            secretMarkers:observationMarkers];
        observation.pauseAtFixtureStartForTesting = pauseObservationAtStart;
      }
      if (!tableControls)
        CefPostDelayedTask(TID_UI, CefCreateClosureTask(base::BindOnce([] { [delegate finishSmoke]; })), 1500);
    }
  }

  void OnLoadStart(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, TransitionType) override {
    CEF_REQUIRE_UI_THREAD();
    if (observation && frame->IsMain()) [observation nativeLifecycle:@"native_main_load_started"];
    if (tableControls && frame->IsMain()) [tableControls mainLoadStartedForBrowser:browser];
  }

  void OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser, TerminationStatus status, int, const CefString&) override {
    CEF_REQUIRE_UI_THREAD();
    if ([tableSmokeMode hasPrefix:@"lifecycle-"]) {
      if (!smokeResult[@"lifecycle_renderer_events"]) smokeResult[@"lifecycle_renderer_events"] = [NSMutableArray array];
      [smokeResult[@"lifecycle_renderer_events"] addObject:@{@"browser_id": @(browser->GetIdentifier()), @"crashed": @(status == TS_PROCESS_CRASHED)}];
    }
    if (observation) [observation nativeLifecycle:@"native_renderer_terminated"];
    if (tableControls) [tableControls rendererTerminatedForBrowser:browser];
  }

  void CloseAll() {
    CEF_REQUIRE_UI_THREAD();
    // The API permits synchronous OnBeforeClose, which mutates browsers_.
    auto closing = browsers_;
    for (auto& browser : closing) browser->GetHost()->CloseBrowser(false);
  }

 private:
  std::vector<CefRefPtr<CefBrowser>> browsers_;
  bool smokeScheduled_ = false;
  IMPLEMENT_REFCOUNTING(BrowserClient);
};

class BrowserApp final : public CefApp, public CefBrowserProcessHandler {
 public:
  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }

  void OnBeforeChildProcessLaunch(CefRefPtr<CefCommandLine> command) override {
    if (sandboxProbe) command->AppendSwitchWithValue("bs-sandbox-probe", sandboxProbe.UTF8String);
    if (sandboxProbeOutside)
      command->AppendSwitchWithValue("bs-sandbox-probe-outside", sandboxProbeOutside.UTF8String);
  }

  void OnContextInitialized() override {
    CEF_REQUIRE_UI_THREAD();
    SmokeStage("context_initialized");
    client = new BrowserClient;
    CefWindowInfo window;
    window.runtime_style = CEF_RUNTIME_STYLE_CHROME;
    window.bounds = CefRect(80, 80, 1100, 780);
    CefBrowserSettings settings;
    if (!CefBrowserHost::CreateBrowser(window, client, initialURL.UTF8String, settings, nullptr, nullptr)) {
      smokeResult[@"browser_creation_failed"] = @YES;
      CefQuitMessageLoop();
    }
  }

  CefRefPtr<CefClient> GetDefaultClient() override { return client; }

 private:
  IMPLEMENT_REFCOUNTING(BrowserApp);
};

@implementation BowShockApplication
- (BOOL)isHandlingSendEvent { return _sending; }
- (void)setHandlingSendEvent:(BOOL)value { _sending = value; }
- (void)sendEvent:(NSEvent*)event {
  CefScopedSendingEvent scope;
  [super sendEvent:event];
}
- (void)terminate:(id)sender { [delegate closeBrowsers]; }
@end

@implementation BowShockDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
  [NSApp activateIgnoringOtherApps:YES];
}

- (void)showControls {
  if (tableOrigin && tableDatabase) {
    tableControls = [[BSOwnedTableControls alloc] initWithOrigin:tableOrigin
        databaseURL:[NSURL fileURLWithPath:tableDatabase] smokeMode:tableSmokeMode
        result:smokeResult quit:^{ [delegate closeBrowsers]; }];
    if ([tableSmokeMode hasPrefix:@"lifecycle-"])
      [tableControls configureLifecycleReleasePath:[smokeOutput stringByAppendingString:@".release"]];
    self.controls = tableControls.panel;
    [tableControls start];
    return;
  }
  self.controls = [[NSPanel alloc] initWithContentRect:NSMakeRect(1200, 200, 340, 200)
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
      backing:NSBackingStoreBuffered defer:NO];
  self.controls.title = @"Bow Shock controls";
  self.controls.releasedWhenClosed = NO;
  NSTextField* heading = [NSTextField labelWithString:@"Human browsing · bootstrap POC"];
  heading.frame = NSMakeRect(20, 160, 300, 24);
  [self.controls.contentView addSubview:heading];
  self.status = [NSTextField wrappingLabelWithString:@"Controller connecting…\nNo delegated powers."];
  self.status.frame = NSMakeRect(20, 90, 300, 60);
  [self.controls.contentView addSubview:self.status];
  self.stop = [NSButton buttonWithTitle:@"Stop all" target:self action:@selector(stopAll:)];
  self.stop.frame = NSMakeRect(20, 25, 130, 36);
  self.stop.enabled = NO;
  [self.controls.contentView addSubview:self.stop];
  NSButton* quit = [NSButton buttonWithTitle:@"Quit Bow Shock" target:self action:@selector(quit:)];
  quit.frame = NSMakeRect(165, 25, 150, 36);
  [self.controls.contentView addSubview:quit];
  [self.controls orderFront:nil];
  controller = [[BSControllerConnection alloc] init];
  controller.disconnectHandler = ^{
    self.stop.enabled = NO;
    self.status.stringValue = @"Controller disconnected.\nManual browsing remains available.";
    smokeResult[@"controller_disconnected"] = @YES;
  };
  [controller startWithCompletion:^(NSDictionary* reply) {
    smokeResult[@"controller_initialized"] = @(reply != nil);
    self.stop.enabled = reply != nil;
    self.status.stringValue = reply ? @"Controller connected.\nNo delegated powers." : @"Controller unavailable.\nManual browsing remains available.";
    if (reply) smokeResult[@"controller_pid"] = @(controller.childPid);
  }];
}

- (void)stopAll:(id)sender {
  self.stop.enabled = NO;
  [controller sendOperation:@"stop_all" completion:^(NSDictionary* reply) {
    self.stop.enabled = reply != nil;
    self.status.stringValue = reply ? @"Stop processed.\nNo active powers." : @"Controller disconnected.\nNo delegation available.";
    if (reply) smokeResult[@"controller_stop_generation"] = reply[@"stop_generation"];
  }];
}

- (void)quit:(id)sender { [self closeBrowsers]; }
- (void)closeBrowsers { if (client) client->CloseAll(); }
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication*)app { return YES; }

- (void)finishSmoke {
  if (observation && !self.observationFinished) {
    self.observationFinished = YES;
    [observation captureFixtureWithCompletion:^(NSDictionary* record) {
      smokeResult[@"observation"] = record;
      [self finishSmoke];
    }];
    return;
  }
  if (![smokeResult[@"controller_initialized"] boolValue]) {
    [self closeBrowsers];
    return;
  }
  [controller sendOperation:@"stop_all" completion:^(NSDictionary* reply) {
    if (reply) smokeResult[@"controller_stop_generation"] = reply[@"stop_generation"];
    [controller sendOperation:@"shutdown" completion:^(NSDictionary*) { [self closeBrowsers]; }];
  }];
}
@end

int main(int argc, char** argv) {
  bool smokeRequested = false;
  for (int i = 1; i < argc; ++i)
    if (std::string(argv[i]).rfind("--bs-smoke-output=", 0) == 0) smokeRequested = true;
  if (smokeRequested) fprintf(stderr, "BS_LIFETIME app_entered_main\n");
  CefScopedLibraryLoader loader;
  if (!loader.LoadInMain()) return 1;
  if (smokeRequested) fprintf(stderr, "BS_LIFETIME framework_loaded\n");
  @autoreleasepool {
    [BowShockApplication sharedApplication];
    if (![NSApp isKindOfClass:BowShockApplication.class]) return 1;
    CefRefPtr<CefCommandLine> command = CefCommandLine::CreateCommandLine();
    command->InitFromArgv(argc, argv);
    auto text = [&](const char* key) -> NSString* {
      auto value = command->GetSwitchValue(key).ToString();
      return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
    };
    smokeOutput = text("bs-smoke-output");
    sandboxProbe = smokeOutput ? text("bs-sandbox-probe") : nil;
    sandboxProbeOutside = smokeOutput ? text("bs-sandbox-probe-outside") : nil;
    observationOrigin = smokeOutput ? text("bs-observation-origin") : nil;
    observationFields = [text("bs-observation-fields") componentsSeparatedByString:@","] ?: @[];
    observationMarkers = [text("bs-observation-markers") componentsSeparatedByString:@","] ?: @[];
    pauseObservationAtStart = smokeOutput && command->HasSwitch("bs-observation-pause-start");
    tableOrigin = text("bs-table-origin");
    tableDatabase = text("bs-table-db");
    tableSmokeMode = smokeOutput ? text("bs-table-smoke") : nil;
    if ((tableOrigin != nil) != (tableDatabase != nil) ||
        (tableDatabase && !tableDatabase.isAbsolutePath) ||
        (tableSmokeMode && ![@[@"save", @"reopen", @"drafts", @"workload", @"lifecycle-browser", @"lifecycle-stop", @"lifecycle-display"] containsObject:tableSmokeMode])) {
      fprintf(stderr, "Invalid owned table workflow configuration.\n"); return 1;
    }
    initialURL = text("bs-url") ?: @"about:blank";
    if ([tableSmokeMode hasPrefix:@"lifecycle-"]) {
      NSURL* owned = [NSURL URLWithString:tableOrigin];
      if (![owned.scheme isEqual:@"http"] || ![owned.host isEqual:@"127.0.0.1"] || !owned.port ||
          owned.user || owned.password || owned.query || owned.fragment || owned.path.length ||
          ![initialURL isEqual:[tableOrigin stringByAppendingString:@"/amber"]]) {
        fprintf(stderr, "Lifecycle smoke requires the owned loopback Amber catalog.\n"); return 1;
      }
    }
    smokeResult = [@{@"browser_created": @NO, @"browser_closed": @NO, @"cef_shutdown": @NO,
                     @"controller_initialized": @NO, @"controller_stop_generation": @0} mutableCopy];
    if (smokeOutput) smokeResult[@"clock_start"] = BSContinuousClockWitness() ?: @{};
    NSString* profile = text("bs-profile") ?: [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Bow Shock/POC"];
    NSError* profileError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:profile
        withIntermediateDirectories:YES attributes:nil error:&profileError]) {
      fprintf(stderr, "Unable to create Bow Shock profile directory.\n");
      return 1;
    }
    // Foundation normalizes some /private aliases back to /var. CEF's root
    // containment check uses POSIX canonical paths, so derive every path here.
    char* resolvedProfile = realpath(profile.fileSystemRepresentation, nullptr);
    if (!resolvedProfile) {
      fprintf(stderr, "Unable to resolve Bow Shock profile directory.\n");
      return 1;
    }
    const std::string canonicalProfile(resolvedProfile);
    free(resolvedProfile);
    CefSettings settings;
    settings.no_sandbox = false;
    settings.command_line_args_disabled = true;
    settings.remote_debugging_port = 0;
    settings.log_severity = LOGSEVERITY_ERROR;
    CefString(&settings.root_cache_path) = canonicalProfile;
    CefString(&settings.cache_path) = canonicalProfile + "/Default";
    CefString(&settings.log_file) = canonicalProfile + "/cef.log";
    delegate = [[BowShockDelegate alloc] init];
    NSApp.delegate = delegate;
    CefRefPtr<BrowserApp> app = new BrowserApp;
    SmokeStage("cef_initialize_start");
    if (!CefInitialize(CefMainArgs(argc, argv), settings, app, nullptr)) return CefGetExitCode();
    SmokeStage("cef_initialize_end");
    [delegate showControls];
    CefRunMessageLoop();
    SmokeStage("message_loop_returned");
    [controller invalidate];
    // The live UI loop is over. Finish owned-child reap before app process exit.
    SmokeStage("controller_join_start");
    [controller waitForTermination];
    [tableControls finishTermination];
    SmokeStage("controller_join_end");
    if (observation) { [observation close]; observation = nil; }
    client = nullptr;
    app = nullptr;
    SmokeStage("cef_shutdown_start");
    CefShutdown();
    SmokeStage("cef_shutdown_end");
    smokeResult[@"cef_shutdown"] = @YES;
    if (smokeOutput) {
      smokeResult[@"clock_end"] = BSContinuousClockWitness() ?: @{};
      NSData* result = [NSJSONSerialization dataWithJSONObject:smokeResult options:NSJSONWritingPrettyPrinted error:nil];
      if (![result writeToFile:smokeOutput atomically:YES]) return 1;
    }
    [delegate.controls orderOut:nil];
    NSApp.delegate = nil;
    delegate = nil;
    controller = nil;
    tableControls = nil;
  }
  return 0;
}
