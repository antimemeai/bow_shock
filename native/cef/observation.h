#import <Foundation/Foundation.h>
#include "include/cef_browser.h"

NS_ASSUME_NONNULL_BEGIN

/// Owned-loopback development reader. No general observation or effect powers.
@interface BSNativeObservation : NSObject
- (instancetype)initWithBrowser:(CefRefPtr<CefBrowser>)browser
    runId:(NSString*)runId surfaceId:(NSString*)surfaceId
    allowedOrigin:(NSString*)origin fieldIds:(NSArray<NSString*>*)fieldIds
    secretMarkers:(NSArray<NSString*>*)secretMarkers;
/// Smoke harness only: self-stop after capture begins, before native dispatch.
/// Default NO; the owned driver must resume this exact application process.
@property(nonatomic) BOOL pauseAtFixtureStartForTesting;
- (void)captureFixtureWithCompletion:(void (^)(NSDictionary*))completion;
/// Known native navigation/frame/renderer changes invalidate pending projections.
- (void)nativeLifecycle:(NSString*)reason;
/// UI-thread close before CEF shutdown; callbacks already queued become inert.
- (void)close;
@end

NS_ASSUME_NONNULL_END
