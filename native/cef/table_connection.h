#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Trusted startup selection. No credentials or page-controlled configuration.
@interface BSAgentConfiguration : NSObject
@property(nonatomic, readonly) NSURL* executableURL;
@property(nonatomic, readonly) NSURL* workingDirectoryURL;
@property(nonatomic, readonly) NSURL* userHomeURL;
@property(nonatomic, readonly) NSURL* codexHomeURL;
@property(nonatomic, readonly) NSString* model;
@property(nonatomic, readonly, nullable) NSString* expectedAccountID;
- (instancetype)initWithExecutableURL:(NSURL*)executableURL
    workingDirectoryURL:(NSURL*)workingDirectoryURL userHomeURL:(NSURL*)userHomeURL
    codexHomeURL:(NSURL*)codexHomeURL model:(NSString*)model
    expectedAccountID:(NSString* _Nullable)expectedAccountID NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// Closed trusted-parent table service link. No generic RPC, model or input power.
@interface BSTableConnection : NSObject
@property(nonatomic, readonly) NSString* runId;
/// Thread-safe, short-lock getter; cleared by worker before UI disconnection.
@property(nonatomic, readonly) BOOL connected;
/// Original PID metadata only; never a reusable signal handle.
@property(nonatomic, readonly) pid_t childPid;
/// Latest validated Stop acknowledgement, not an authority grant.
@property(nonatomic, readonly) uint64_t stopGeneration;
@property(nonatomic, copy, nullable) void (^disconnectHandler)(void);
#if defined(BS_TABLE_CONNECTION_TEST)
/// Owned oracle only; pause after deadline capture before worker dispatch.
@property(nonatomic) BOOL pauseAtStartForTesting;
#endif
- (instancetype)initWithExecutableURL:(NSURL*)executableURL
    databaseURL:(NSURL*)databaseURL clockProbeURL:(NSURL*)clockProbeURL
    ownedOrigin:(NSString*)ownedOrigin;
- (instancetype)initWithExecutableURL:(NSURL*)executableURL
    databaseURL:(NSURL*)databaseURL clockProbeURL:(NSURL*)clockProbeURL
    ownedOrigin:(NSString*)ownedOrigin agentConfiguration:(BSAgentConfiguration* _Nullable)agentConfiguration
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/// Initializes only. Caller polls status until Ready, then explicitly scopes.
- (void)startWithCompletion:(void (^)(NSDictionary* _Nullable))completion;
- (void)scopeOrigin:(NSString*)origin completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)stageBatch:(NSDictionary*)batch completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)reviseStaging:(NSString*)stagingID batch:(NSDictionary*)batch
    completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)reviewStaging:(NSString*)stagingID retentionMs:(uint64_t)retentionMs
    completion:(void (^)(NSDictionary* _Nullable))completion;
/// Guard is checked locally; only the exact Review is forwarded to Rust.
- (void)approveReview:(NSDictionary*)review publicationGuard:(NSDictionary*)guard
    completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)commitApproval:(NSString*)approvalID completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)statusCommit:(NSString* _Nullable)commitID completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)listWithCompletion:(void (^)(NSDictionary* _Nullable))completion;
- (void)readCommit:(NSString*)commitID completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)deleteCommit:(NSString*)commitID completion:(void (^)(NSDictionary* _Nullable))completion;
- (void)closeWithCompletion:(void (^)(NSDictionary* _Nullable))completion;
- (void)pingWithCompletion:(void (^)(NSDictionary* _Nullable))completion;
/// One urgent slot may coexist with one ordinary table operation.
- (void)stopAllWithCompletion:(void (^)(NSDictionary* _Nullable))completion;
- (void)shutdownWithCompletion:(void (^)(NSDictionary* _Nullable))completion;
/// Required again immediately before UI assignment. No cached/wall-clock fallback.
+ (BOOL)publicationGuardIsCurrent:(NSDictionary*)guard;
- (void)invalidate;
/// Final teardown after the UI/message loop; waits for actual owned reap.
- (void)waitForTermination;
@end

NS_ASSUME_NONNULL_END
