#import <Foundation/Foundation.h>
#include "include/cef_browser.h"

NS_ASSUME_NONNULL_BEGIN
/// A complete, locally retained Chromium reading. Payload lives in its archive.
@interface BSLivePage : NSObject
@property(nonatomic, copy, readonly) NSString* url;
@property(nonatomic, copy, readonly) NSString* title;
@property(nonatomic, copy, readonly) NSString* origin;
@property(nonatomic, copy, readonly) NSString* frameId;
@property(nonatomic, copy, readonly) NSString* documentId;
@property(nonatomic, copy, readonly) NSString* captureId;
@property(nonatomic, readonly) uint64_t captureStartNanos;
@property(nonatomic, readonly) uint64_t captureEndNanos;
@property(nonatomic, readonly) NSUInteger nodeCount;
@property(nonatomic, readonly) NSUInteger childFrameCount;
@property(nonatomic, readonly) NSUInteger blockCount;
@property(nonatomic, readonly) uint64_t textBytes;
@property(nonatomic, strong, readonly) NSURL* directoryURL;
@property(nonatomic, copy, readonly) NSArray<NSString*>* coverage;
/// A small reference for Blackbird; the harvested page is never inlined into IPC.
- (NSDictionary*)nativeValue;
@end
@interface BSLiveObservation : NSObject
- (instancetype)initWithBrowser:(CefRefPtr<CefBrowser>)browser readingsURL:(NSURL*)readings;
- (void)captureWithCompletion:(void (^)(BSLivePage* _Nullable page, NSString* _Nullable error))completion;
- (void)nativeLifecycle:(NSString*)reason;
- (void)cancel;
- (void)close;
@end
NS_ASSUME_NONNULL_END
