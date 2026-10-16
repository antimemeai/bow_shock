#import <Cocoa/Cocoa.h>
#import "live_panel.h"

#include "include/cef_app.h"
#include "include/cef_application_mac.h"
#include "include/cef_browser.h"
#include "include/cef_command_line.h"
#include "include/cef_display_handler.h"
#include "include/cef_focus_handler.h"
#include "include/cef_life_span_handler.h"
#include "include/cef_load_handler.h"
#include "include/cef_request_handler.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

class BrowserClient;
static CefRefPtr<BrowserClient> client;
static BSLivePanel* livePanel;
static NSString* initialURL;
static NSString* smokeOutput;
static NSString* smokeObjective;
static NSURL* blackbirdExecutable;
static NSURL* blackbirdSession;
static NSURL* workingDirectory;
static NSString* selectedModel;
static NSMutableDictionary* runResult;
static BOOL closing;

@interface BowShockApplication : NSApplication <CefAppProtocol> {
  BOOL _sending;
}
@end
@interface OxcartDelegate : NSObject <NSApplicationDelegate>
- (void)closeBrowsers;
@end
static OxcartDelegate* delegate;

class BrowserClient final : public CefClient,
                            public CefLifeSpanHandler,
                            public CefLoadHandler,
                            public CefDisplayHandler,
                            public CefRequestHandler,
                            public CefFocusHandler {
 public:
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }
  CefRefPtr<CefFocusHandler> GetFocusHandler() override { return this; }
  bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
      CefProcessId source, CefRefPtr<CefProcessMessage> message) override {
    CEF_REQUIRE_UI_THREAD();
    return source == PID_RENDERER && [livePanel receiveInputForBrowser:browser frame:frame message:message];
  }
  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override {
    CEF_REQUIRE_UI_THREAD();
    browsers_.push_back(browser); runResult[@"browser_created"] = @YES;
    [livePanel attachBrowser:browser];
  }
  void OnGotFocus(CefRefPtr<CefBrowser> browser) override {
    CEF_REQUIRE_UI_THREAD(); [livePanel attachBrowser:browser];
  }
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override {
    CEF_REQUIRE_UI_THREAD(); [livePanel browserClosing:browser];
    browsers_.erase(std::remove_if(browsers_.begin(), browsers_.end(),
        [&](const auto& item) { return item->IsSame(browser); }), browsers_.end());
    if (browsers_.empty()) {
      runResult[@"browser_closed"] = @YES;
      [livePanel closeWithCompletion:^{ CefQuitMessageLoop(); }];
    } else if (!closing) [livePanel attachBrowser:browsers_.back()];
  }
  void OnLoadStart(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
                   TransitionType) override {
    CEF_REQUIRE_UI_THREAD();
    if (frame->IsMain()) [livePanel mainLoadStartedForBrowser:browser];
  }
  void OnLoadEnd(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int status) override {
    CEF_REQUIRE_UI_THREAD();
    if (frame->IsMain()) {
      runResult[@"load_status"] = @(status);
      [livePanel mainLoadEndedForBrowser:browser];
    }
  }
  void OnLoadError(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
                   ErrorCode code, const CefString& error, const CefString&) override {
    CEF_REQUIRE_UI_THREAD();
    if (!frame->IsMain() || code == ERR_ABORTED) return;
    runResult[@"load_error"] = [NSString stringWithUTF8String:error.ToString().c_str()];
    if (smokeOutput) [delegate closeBrowsers];
    else [livePanel mainLoadEndedForBrowser:browser];
  }
  void OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser, TerminationStatus,
                                 int, const CefString&) override {
    CEF_REQUIRE_UI_THREAD(); [livePanel rendererTerminatedForBrowser:browser];
  }
  void OnTitleChange(CefRefPtr<CefBrowser>, const CefString& title) override {
    CEF_REQUIRE_UI_THREAD();
    runResult[@"title"] = [NSString stringWithUTF8String:title.ToString().c_str()] ?: @"";
  }
  void closeAll() {
    CEF_REQUIRE_UI_THREAD();
    const auto browsers = browsers_;
    for (const auto& browser : browsers) browser->GetHost()->CloseBrowser(false);
  }
 private:
  std::vector<CefRefPtr<CefBrowser>> browsers_;
  IMPLEMENT_REFCOUNTING(BrowserClient);
};
class BrowserApp final : public CefApp, public CefBrowserProcessHandler {
 public:
  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }
  void OnContextInitialized() override {
    CEF_REQUIRE_UI_THREAD();
    client = new BrowserClient;
    CefWindowInfo window; window.runtime_style = CEF_RUNTIME_STYLE_CHROME;
    NSRect screen = NSScreen.mainScreen.visibleFrame;
    window.bounds = CefRect(12, 50, static_cast<int>(screen.size.width * 0.62),
                            static_cast<int>(screen.size.height - 70));
    CefBrowserSettings settings;
    if (!CefBrowserHost::CreateBrowser(window, client, initialURL.UTF8String, settings, nullptr, nullptr)) {
      runResult[@"browser_creation_failed"] = @YES;
      [livePanel closeWithCompletion:^{ CefQuitMessageLoop(); }];
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
  [livePanel nativeInputEvent:event];
  [super sendEvent:event];
}
- (void)terminate:(id)sender { (void)sender; [delegate closeBrowsers]; }
@end
@implementation OxcartDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  (void)notification; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
  [NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication*)app { (void)app; return YES; }
- (void)closeBrowsers {
  if (closing) return;
  closing = YES;
  if (client) client->closeAll();
  else [livePanel closeWithCompletion:^{ CefQuitMessageLoop(); }];
}
@end
int main(int argc, char** argv) {
  CefScopedLibraryLoader loader; if (!loader.LoadInMain()) return 1;
  @autoreleasepool {
    [BowShockApplication sharedApplication];
    if (![NSApp isKindOfClass:BowShockApplication.class]) return 1;
    CefRefPtr<CefCommandLine> command = CefCommandLine::CreateCommandLine();
    command->InitFromArgv(argc, argv);
    auto text = [&](const char* key) -> NSString* {
      const auto value = command->GetSwitchValue(key).ToString();
      return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
    };
    initialURL = text("bs-url") ?: @"https://news.ycombinator.com/";
    smokeOutput = text("ox-smoke-output"); smokeObjective = text("ox-smoke-objective");
    NSString* executable = text("ox-blackbird") ?: [NSHomeDirectory()
        stringByAppendingPathComponent:@"projects/blackbird/build/release/blackbird"];
    NSString* directory = text("ox-cwd") ?: NSFileManager.defaultManager.currentDirectoryPath;
    NSString* session = text("ox-session") ?: [NSHomeDirectory()
        stringByAppendingPathComponent:@"Library/Application Support/Oxcart/blackbird"];
    selectedModel = text("ox-model") ?: @"gpt-6.1-sol";
    if (!executable.isAbsolutePath || !directory.isAbsolutePath || !session.isAbsolutePath ||
        (smokeOutput && !smokeOutput.isAbsolutePath)) {
      fprintf(stderr, "Oxcart executable, session, working directory and output paths must be absolute.\n"); return 1;
    }
    blackbirdExecutable = [NSURL fileURLWithPath:executable];
    blackbirdSession = [NSURL fileURLWithPath:session]; workingDirectory = [NSURL fileURLWithPath:directory];
    runResult = [@{@"browser_created": @NO, @"browser_closed": @NO, @"cef_shutdown": @NO} mutableCopy];
    runResult[@"smoke_extraction"] = @(command->HasSwitch("ox-smoke-extraction"));
    runResult[@"record_input_on_start"] = @(command->HasSwitch("ox-record-input"));
    NSString* profile = text("bs-profile") ?: [NSHomeDirectory()
        stringByAppendingPathComponent:@"Library/Application Support/Oxcart/profile"];
    NSError* error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:profile
        withIntermediateDirectories:YES attributes:nil error:&error]) {
      fprintf(stderr, "Unable to create Oxcart profile directory: %s\n", error.localizedDescription.UTF8String); return 1;
    }
    char* resolved = realpath(profile.fileSystemRepresentation, nullptr);
    if (!resolved) return 1;
    const std::string canonicalProfile(resolved); free(resolved);
    CefSettings settings; settings.no_sandbox = false;
    settings.command_line_args_disabled = true; settings.remote_debugging_port = 0;
    settings.log_severity = LOGSEVERITY_ERROR;
    CefString(&settings.root_cache_path) = canonicalProfile;
    CefString(&settings.cache_path) = canonicalProfile + "/Default";
    CefString(&settings.log_file) = canonicalProfile + "/cef.log";
    delegate = [[OxcartDelegate alloc] init]; NSApp.delegate = delegate;
    livePanel = [[BSLivePanel alloc] initWithBlackbirdURL:blackbirdExecutable sessionURL:blackbirdSession
        workingDirectoryURL:workingDirectory model:selectedModel result:runResult
        smokeObjective:smokeObjective smoke:smokeOutput != nil quit:^{ [delegate closeBrowsers]; }];
    CefRefPtr<BrowserApp> app = new BrowserApp;
    if (!CefInitialize(CefMainArgs(argc, argv), settings, app, nullptr)) return CefGetExitCode();
    CefRunMessageLoop();
    client = nullptr; app = nullptr; CefShutdown(); runResult[@"cef_shutdown"] = @YES;
    if (smokeOutput) {
      NSData* data = [NSPropertyListSerialization dataWithPropertyList:runResult
          format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
      if (!data || ![data writeToFile:smokeOutput options:NSDataWritingAtomic error:&error]) return 1;
    }
    [livePanel.panel orderOut:nil]; livePanel = nil;
    NSApp.delegate = nil; delegate = nil;
  }
  return 0;
}
