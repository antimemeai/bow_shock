#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bootstrap-only child link: finite operations, one pending request, bounded IO.
@interface BSControllerConnection : NSObject
@property(nonatomic, readonly) NSString* runId;
/// Original child PID for smoke metadata, not a live handle or signal authority.
@property(nonatomic, readonly) pid_t childPid;
@property(nonatomic, copy, nullable) void (^disconnectHandler)(void);
- (instancetype)initWithExecutableURL:(NSURL*)url;
- (void)startWithCompletion:(void (^)(NSDictionary* _Nullable))completion;
- (void)sendOperation:(NSString*)operation completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)invalidate;
/// Final teardown only, after the live UI/message loop has ended. Joins reap.
- (void)waitForTermination;
@end

NS_ASSUME_NONNULL_END
