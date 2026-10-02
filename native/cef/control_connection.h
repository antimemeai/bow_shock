#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Private control-only helper. No input/effect authority or generic RPC.
@interface BSControlConnection : NSObject
@property(nonatomic, readonly) NSString* runId;
@property(nonatomic, readonly) BOOL connected;
/// Original PID metadata, never a live signal handle.
@property(nonatomic, readonly) pid_t childPid;
/// Accepted helper fence metadata, not an authority/grant counter.
@property(nonatomic, readonly) uint64_t acknowledgedGeneration;
/// Bounded static phase diagnostic; never contains path/run/page/wire text.
@property(nonatomic, readonly) NSString* failureReason;
/// Actual owned reap result (exit code, or128+signal), -1 until known.
@property(nonatomic, readonly) NSInteger childExitCode;
@property(nonatomic, copy, nullable) void (^disconnectHandler)(void);
/// Provider is invoked on the worker: thread-safe, nonblocking, no UI/CEF calls.
- (instancetype)initWithExecutableURL:(NSURL*)url runId:(NSString*)runId
    authorityAliveProvider:(BOOL (^)(void))provider NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (void)startWithCompletion:(void (^)(NSDictionary* _Nullable))completion;
/// Mirrors a strictly newer caller-owned Stop fence; does not create authority.
- (void)fenceToGeneration:(uint64_t)generation
    completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)invalidate;
/// Final teardown after live UI ends; joins the worker's actual owned reap.
- (void)waitForTermination;
@end
NS_ASSUME_NONNULL_END
