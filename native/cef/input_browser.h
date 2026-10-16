#import <Cocoa/Cocoa.h>
#include "include/cef_browser.h"
#include "include/cef_process_message.h"
NS_ASSUME_NONNULL_BEGIN
@interface OXInputBrowser : NSObject
@property(nonatomic, readonly, nullable) NSString* activeRecordingID;
@property(nonatomic, copy, nullable) void (^failed)(NSString* message);
- (instancetype)initWithBrowser:(CefRefPtr<CefBrowser>)browser rootURL:(NSURL*)root;
- (nullable NSURL*)startWithContext:(NSDictionary*)context;
- (void)stop;
- (void)markContext:(NSDictionary*)context;
- (void)nativeEvent:(NSEvent*)event;
- (BOOL)receiveFrame:(CefRefPtr<CefFrame>)frame message:(CefRefPtr<CefProcessMessage>)message;
- (void)rendererTerminated;
- (void)closeWithCompletion:(void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
