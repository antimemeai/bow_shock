#import <Cocoa/Cocoa.h>
#import "table_connection.h"
#import "control_connection.h"
#include "include/cef_browser.h"

NS_ASSUME_NONNULL_BEGIN
/// Human controls for the owned immutable catalog. No delegated page effects.
@interface BSOwnedTableControls : NSObject
@property(nonatomic, readonly) NSPanel* panel;
@property(nonatomic, readonly) BSTableConnection* tableConnection;
@property(nonatomic, readonly, nullable) BSControlConnection* controlConnection;
- (instancetype)initWithOrigin:(NSString*)origin databaseURL:(NSURL*)databaseURL
    smokeMode:(NSString* _Nullable)smokeMode result:(NSMutableDictionary*)result
    quit:(void (^)(void))quit;
- (instancetype)initWithOrigin:(NSString*)origin databaseURL:(NSURL*)databaseURL
    smokeMode:(NSString* _Nullable)smokeMode result:(NSMutableDictionary*)result
    agentConfiguration:(BSAgentConfiguration* _Nullable)agentConfiguration quit:(void (^)(void))quit;
- (void)start;
- (void)attachBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)mainLoadStartedForBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)mainLoadEndedForBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)rendererTerminatedForBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)browserClosing:(CefRefPtr<CefBrowser>)browser;
/// Owned loopback lifecycle smoke only; ignored in the ordinary catalog POC.
- (void)configureLifecycleReleasePath:(NSString*)path;
- (void)configureAgentSmokePath:(NSString*)path;
/// Keep the live CEF loop until healthy table close/shutdown or visible failure.
- (void)closeWithCompletion:(void (^)(void))completion;
/// After the live CEF loop, reconcile actual owned processes.
- (void)finishTermination;
@end
NS_ASSUME_NONNULL_END
