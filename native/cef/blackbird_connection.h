#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// One Blackbird application process. Commands and events are framed BBM2 values.
/// IO, process termination and reap run off the UI thread. All events/completions
/// arrive on the main queue. An instance has one lifetime; create another to retry.
@interface BSBlackbirdConnection : NSObject
@property(atomic, readonly, getter=isReady) BOOL ready;
/// A turn is pending or active (an idle ready child is not running).
@property(atomic, readonly, getter=isRunning) BOOL running;
@property(nonatomic, copy, nullable) void (^eventHandler)(NSDictionary* event);
- (instancetype)initWithExecutableURL:(NSURL*)executableURL
                          sessionURL:(NSURL*)sessionURL
                 workingDirectoryURL:(NSURL*)workingDirectoryURL
                               model:(NSString*)model;
@property(atomic, readonly, copy, nullable) NSString* activeRequestID;
- (void)start;
/// Returns nil if disconnected/not ready, already busy (unless steer), or full.
/// Steer replaces the active turn with a NEW id. Ignore old finals for UI state.
- (nullable NSString*)sendObjective:(NSString*)objective
                      observations:(NSArray<NSDictionary*>*)observations
                             steer:(BOOL)steer;
- (void)cancel;
- (void)closeWithCompletion:(nullable void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
