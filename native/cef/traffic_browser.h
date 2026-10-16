#import <Cocoa/Cocoa.h>
#include "include/cef_browser.h"
NS_ASSUME_NONNULL_BEGIN
@interface OXTrafficBrowser : NSObject
@property(nonatomic, readonly) NSURL* directoryURL;
- (instancetype)initWithBrowser:(CefRefPtr<CefBrowser>)browser rootURL:(NSURL*)root;
- (void)show;
- (void)markContext:(NSDictionary*)context;
- (void)stop;
- (void)closeWithCompletion:(void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
