#import <Cocoa/Cocoa.h>
#include "include/cef_browser.h"

NS_ASSUME_NONNULL_BEGIN
@interface BSLivePanel : NSObject
@property(nonatomic, readonly) NSPanel* panel;
- (instancetype)initWithBlackbirdURL:(NSURL*)executable sessionURL:(NSURL*)session
    workingDirectoryURL:(NSURL*)directory model:(NSString*)model
    result:(NSMutableDictionary*)result smokeObjective:(NSString* _Nullable)objective
    smoke:(BOOL)smoke quit:(void (^)(void))quit;
- (void)attachBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)mainLoadStartedForBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)mainLoadEndedForBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)rendererTerminatedForBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)browserClosing:(CefRefPtr<CefBrowser>)browser;
- (void)closeWithCompletion:(void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
