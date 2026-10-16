#import <Foundation/Foundation.h>
#include "include/cef_browser.h"

NS_ASSUME_NONNULL_BEGIN

/// One rendered text node. Bounds are document CSS coordinates, not input coordinates.
@interface BSLiveTextBlock : NSObject
@property(nonatomic, readonly) int64_t backendNodeId;
@property(nonatomic, copy, readonly) NSString* tagName;
@property(nonatomic, copy, readonly) NSString* text;
@property(nonatomic, copy, readonly) NSString* linkURL;
@property(nonatomic, readonly) NSRect bounds;
@end

/// A bounded root-document reading. Node identity is scoped to this capture.
@interface BSLivePage : NSObject
@property(nonatomic, copy, readonly) NSString* url;
@property(nonatomic, copy, readonly) NSString* title;
@property(nonatomic, copy, readonly) NSString* text;
/// Page.getFrameTree loader securityOrigin; effective window origin is unverified.
@property(nonatomic, copy, readonly) NSString* origin;
@property(nonatomic, copy, readonly) NSString* frameId;
@property(nonatomic, copy, readonly) NSString* documentId;
@property(nonatomic, copy, readonly) NSString* captureId;
@property(nonatomic, readonly) uint64_t captureStartNanos;
@property(nonatomic, readonly) uint64_t captureEndNanos;
@property(nonatomic, readonly) BOOL truncated;
@property(nonatomic, readonly) NSUInteger nodeCount;
@property(nonatomic, readonly) NSUInteger childFrameCount;
@property(nonatomic, copy, readonly) NSArray<BSLiveTextBlock*>* blocks;
@property(nonatomic, copy, readonly) NSArray<NSString*>* coverage;
@end

/// UI-thread lifecycle; protocol decoding and DOM projection run on a worker.
@interface BSLiveObservation : NSObject
- (instancetype)initWithBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)captureWithCompletion:(void (^)(BSLivePage* _Nullable page,
                                       NSString* _Nullable error))completion;
- (void)nativeLifecycle:(NSString*)reason;
/// Retires host capture immediately. Chromium's in-flight reader may still finish.
- (void)cancel;
- (void)close;
@end

NS_ASSUME_NONNULL_END
