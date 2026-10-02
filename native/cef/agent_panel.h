#import <AppKit/AppKit.h>
#import "table_connection.h"

NS_ASSUME_NONNULL_BEGIN
/// Native selected-source proposal UI. No approval, Save or page effects.
@interface BSAgentPanel : NSObject
@property(nonatomic, readonly) NSPanel* panel;
@property(nonatomic, readonly) BOOL busy;
@property(nonatomic, readonly, nullable) NSString* taskID;
@property(nonatomic, readonly, nullable) NSDictionary* proposal;
@property(nonatomic, readonly) BOOL canAsk;
@property(nonatomic, readonly) NSString* state;
@property(nonatomic, readonly, nullable) NSDictionary* metadata;
@property(nonatomic, readonly) NSString* previewText;
@property(nonatomic, readonly) NSString* disclosureCaption;
@property(nonatomic, copy, nullable) void (^busyChanged)(BOOL busy);
@property(nonatomic, copy, nullable) void (^requestRevocation)(void);
@property(nonatomic, copy, nullable) void (^proposalHandler)(NSDictionary* batch, NSDictionary* guard, NSArray<NSString*>* selectedIDs);
- (instancetype)initWithConnection:(BSTableConnection*)connection
    configuration:(BSAgentConfiguration* _Nullable)configuration;
- (void)setReview:(NSDictionary*)review publicationGuard:(NSDictionary*)guard batch:(NSDictionary*)batch;
- (void)updateAvailability:(BOOL)available;
/// Clears native publication first, then revokes started/in-flight work.
- (void)retire;
/// Clears a completed task without redundant revocation; active calls revoke.
- (void)consumeProposal;
/// Native checkbox selection; accepts only IDs generated from this snapshot.
- (BOOL)setSelectedCandidateIDs:(NSArray<NSString*>*)candidateIDs;
- (BOOL)setObjective:(NSString*)objective;
- (void)ask:(nullable id)sender;
- (void)useProposal:(nullable id)sender;
@end
NS_ASSUME_NONNULL_END
