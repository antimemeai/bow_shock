#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^OXTrafficReply)(BOOL success, NSDictionary* result);
typedef void (^OXTrafficTransport)(NSString* method, NSDictionary* parameters, OXTrafficReply completion);

/// Owns traffic state and storage on a serial worker. Public calls never wait for disk IO.
@interface OXTrafficSession : NSObject
@property(nonatomic, readonly) NSURL* directoryURL;
@property(nonatomic, copy, nullable) void (^changed)(NSDictionary* snapshot);
- (instancetype)initWithRootURL:(NSURL*)root transport:(OXTrafficTransport)transport;
- (void)start;
- (void)markContext:(NSDictionary*)context;
- (void)receiveEvent:(NSString*)method parameters:(NSDictionary*)parameters;
/// External CDP boundary, parsed on the worker rather than the browser thread.
- (void)receiveEvent:(NSString*)method protocolBytes:(NSData*)bytes;
- (void)armPattern:(NSString*)pattern requests:(BOOL)requests responses:(BOOL)responses;
- (void)forwardPause:(NSString*)pauseID;
/// Overrides: url/method/headers for requests, status/headers for responses; optional body_file.
- (void)applyPause:(NSString*)pauseID overrides:(NSDictionary*)overrides;
- (void)cancelPause:(NSString*)pauseID;
- (void)stop;
- (void)agentDetached;
/// Browser is already closing: retain partials; pending engine exchanges die with it.
- (void)closeWithCompletion:(void (^)(void))completion;
@end

FOUNDATION_EXPORT NSArray<NSDictionary*>* _Nullable OXTrafficParseHeaders(NSString* text, NSString* _Nullable * _Nullable error);
FOUNDATION_EXPORT NSString* OXTrafficHeaderText(id headers);
NS_ASSUME_NONNULL_END
