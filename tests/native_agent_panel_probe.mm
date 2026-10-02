#import "agent_panel.h"
#import "continuous_clock.h"
#include <unistd.h>

static void Require(BOOL ok, const char* reason) { if (!ok) { fprintf(stderr, "%s\n", reason); exit(1); } }
@interface ClosedPeer : BSTableConnection
@property(nonatomic) NSMutableArray* calls;
@property(nonatomic, copy) void (^pending)(NSDictionary*);
@property(nonatomic) NSDictionary* submitted;
- (instancetype)init;
- (void)reply:(NSDictionary*)reply;
@end
@implementation ClosedPeer
- (instancetype)init {
  self = [super initWithExecutableURL:[NSURL fileURLWithPath:@"/owned/controller"] databaseURL:[NSURL fileURLWithPath:@"/owned/db"]
      clockProbeURL:[NSURL fileURLWithPath:@"/owned/clock"] ownedOrigin:@"http://127.0.0.1:1"];
  _calls = [NSMutableArray array]; return self;
}
- (BOOL)connected { return YES; }
- (void)agentMetadataWithCompletion:(void (^)(NSDictionary*))completion { Require(!_pending,"overlapping operation"); [_calls addObject:@"metadata"]; _pending = completion; }
- (void)startAgentReview:(NSDictionary*)review candidateIDs:(NSArray*)ids objective:(NSString*)objective ttlMs:(uint64_t)ttl publicationGuard:(NSDictionary*)guard completion:(void (^)(NSDictionary*))completion {
  Require(!_pending,"overlapping operation"); [_calls addObject:@"start"]; _submitted = @{@"review":review,@"ids":ids,@"objective":objective,@"ttl":@(ttl),@"guard":guard}; _pending=completion;
}
- (void)statusAgent:(NSString*)task completion:(void (^)(NSDictionary*))completion { Require(!_pending,"overlapping operation"); [_calls addObject:@"status"]; Require([task isEqual:@"task"],"wrong status identity"); _pending=completion; }
- (void)reply:(NSDictionary*)reply { void (^callback)(NSDictionary*) = _pending; _pending=nil; Require(callback != nil,"missing operation"); callback(reply); }
@end

static NSDictionary* Descriptor(void) {
  return @{@"runtime":@"codex",@"version":@"0.160.0",@"role":@"trusted_coding_peer",@"placement":@"hosted",@"model":@"test-model",@"provider":@"openai",@"account_ref":@"test-account",@"account_type":@"chatgpt",@"protocol_version":@1,@"account_verification":@"measured_backend_reference",@"structured_output":@"unverified",@"history":@"fresh_only",@"steer":@"unsupported",@"cancellation":@"host_retirement_and_owned_child_kill"};
}
static NSDictionary* Batch(void) {
  NSMutableArray* rows=[NSMutableArray array];
  for (NSUInteger r=0;r<2;++r) {
    NSMutableArray* fields=[NSMutableArray array];
    NSArray* names=@[@"name",@"price",@"note",@"sku",@"quantity",@"private"];
    for (NSUInteger f=0;f<6;++f) {
      NSString* value=[NSString stringWithFormat:@"OWNED-%lu-%lu",(unsigned long)r,(unsigned long)f];
      NSDictionary* observation=@{@"run_id":@"owned-run",@"surface_id":@"surface",@"frame_id":@"frame",@"document_id":@"doc",@"capture_id":@"capture",@"security_origin":@"http://127.0.0.1:1",@"attachment_generation":@1,@"activation_generation":@1,@"node_generation":@1,@"capture_start_ns":@1,@"capture_end_ns":@2};
      NSMutableDictionary* source=[@{@"observation":observation,@"node_id":f==5?NSNull.null:@(f+1),@"visibility":@"layout-present-occlusion-unknown",@"normalization":@"identity"} mutableCopy];
      if (f!=5) source[@"fragment"]=value;
      [fields addObject:@{@"name":names[f],@"state":f==5?@{@"kind":@"inaccessible"}:@{@"kind":@"value",@"source":value,@"value":value},@"source":source}];
    }
    [rows addObject:@{@"fields":fields}];
  }
  return @{@"schema_version":@"owned-product-v1",@"pattern_version":@"owned-field-ids-v1",@"partial":@YES,@"rows":rows};
}
static NSDictionary* Review(NSDictionary* batch) {
  NSData* bytes=[NSJSONSerialization dataWithJSONObject:@{@"batch":batch,@"retention_ms":@600000} options:0 error:nil];
  return @{@"staging_id":@"stage",@"version":@1,@"content":[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding]};
}
static NSDictionary* Guard(uint64_t delta) { NSDictionary* clock=BSContinuousClockWitness(); return @{@"boot_id":clock[@"boot_id"],@"valid_until_ns":@([clock[@"continuous_ns"] unsignedLongLongValue]+delta)}; }
static BSAgentConfiguration* Config(void) { return [[BSAgentConfiguration alloc] initWithExecutableURL:[NSURL fileURLWithPath:@"/owned/codex"] workingDirectoryURL:[NSURL fileURLWithPath:@"/owned/work"] userHomeURL:[NSURL fileURLWithPath:@"/owned/home"] codexHomeURL:[NSURL fileURLWithPath:@"/owned/codex-home"] model:@"test-model" expectedAccountID:@"test-account"]; }
static BSAgentPanel* Ready(ClosedPeer* peer, NSDictionary* guard, NSDictionary* batch) {
  BSAgentPanel* panel=[[BSAgentPanel alloc] initWithConnection:peer configuration:Config()];
  [panel setReview:Review(batch) publicationGuard:guard batch:batch]; [panel updateAvailability:YES];
  Require(panel.busy,"metadata not busy"); [peer reply:@{@"op":@"agent_metadata",@"state":@"ready",@"descriptor":Descriptor()}];
  Require(panel.canAsk && !panel.busy && panel.metadata != nil,"ready metadata not actionable"); return panel;
}
static NSDictionary* Proposal(NSDictionary* batch, NSArray* ids) {
  NSMutableArray* rows=[NSMutableArray array];
  for (NSUInteger r=0;r<[batch[@"rows"] count];++r) { NSMutableArray* fields=[NSMutableArray array]; for (NSUInteger f=0;f<6;++f) if ([ids containsObject:[NSString stringWithFormat:@"r%luf%lu",(unsigned long)r,(unsigned long)f]]) [fields addObject:batch[@"rows"][r][@"fields"][f]]; if (fields.count) [rows addObject:@{@"fields":fields}]; }
  return @{@"candidate_ids":ids,@"batch":@{@"schema_version":batch[@"schema_version"],@"pattern_version":batch[@"pattern_version"],@"partial":@YES,@"rows":rows},@"explanation":@"Selected original evidence."};
}
static void Start(ClosedPeer* peer, BSAgentPanel* panel, NSDictionary* guard, NSString* testCase) {
  [panel ask:nil]; Require(panel.busy && [peer.calls.lastObject isEqual:@"start"],"Ask did not start");
  [peer reply:@{@"op":@"agent_started",@"task_id":@"task",@"candidate_ids":peer.submitted[@"ids"],@"publication_guard":guard}];
  Require(panel.busy && [panel.taskID isEqual:@"task"],"running task not busy");
  NSUInteger iterations=0,serviced=0; NSDictionary* pollStart=BSContinuousClockWitness();
  uint64_t pollLimit=[pollStart[@"continuous_ns"] unsignedLongLongValue]+2000000000;
  while (!peer.pending && [BSContinuousClockWitness()[@"continuous_ns"] unsignedLongLongValue]<pollLimit) { ++iterations; if ([[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]]) ++serviced; }
  if (!([peer.calls.lastObject isEqual:@"status"] && peer.pending)) {
    NSTimer* timer=[panel valueForKey:@"timer"];
    NSDictionary* details=@{@"case":testCase,@"calls":peer.calls,@"state":panel.state,@"busy":@(panel.busy),@"task":panel.taskID?:NSNull.null,@"pending":@(peer.pending!=nil),@"guard":guard,@"actual_clock":BSContinuousClockWitness()?:@{},@"poll_start":pollStart?:@{},@"loop_iterations":@(iterations),@"serviced":@(serviced),@"inflight":[panel valueForKey:@"inflight"],@"active":[panel valueForKey:@"active"],@"timer_present":@(timer!=nil),@"timer_valid":@(timer.valid),@"timer_fire_remaining":timer?@([timer.fireDate timeIntervalSinceNow]):NSNull.null};
    NSData* bytes=[NSJSONSerialization dataWithJSONObject:details options:NSJSONWritingSortedKeys error:nil];
    fprintf(stderr,"STATUS_POLL_FAILURE %s\n",[[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] UTF8String]);
  }
  Require([peer.calls.lastObject isEqual:@"status"] && peer.pending,"missing finite status poll");
}
static NSDictionary* Status(NSDictionary* guard, NSDictionary* proposal) { return @{@"op":@"agent_status",@"task_id":@"task",@"state":@"candidate",@"export_disposition":@"provider_retained_unknown",@"publication_guard":guard,@"proposal":proposal,@"code":NSNull.null}; }
static void Drain(double duration) { NSDate* until=[NSDate dateWithTimeIntervalSinceNow:duration]; while ([until timeIntervalSinceNow]>0) [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; }

int main(void) { @autoreleasepool {
  id activity=[NSProcessInfo.processInfo beginActivityWithOptions:NSActivityUserInitiated|NSActivityLatencyCritical reason:@"Owned windowless AppKit oracle"];
  [NSApplication sharedApplication]; NSDictionary* batch=Batch(); NSDictionary* guard=Guard(60000000000);
  ClosedPeer* peer=[[ClosedPeer alloc] init]; BSAgentPanel* panel=Ready(peer,guard,batch);
  Require([panel.previewText containsString:@"OWNED-0-0"] && [panel.previewText containsString:@"OWNED-1-1"] && ![panel.previewText containsString:@"OWNED-0-2"],"default preview exposed excluded field");
  NSString* originalPreview=panel.previewText;
  Require(![panel setSelectedCandidateIDs:@[@"r9f0"]] && ![panel setSelectedCandidateIDs:@[@"r0f0",@"r0f0"]] && [panel.previewText isEqual:originalPreview],"invalid native selection accepted or changed preview");
  NSTextField* objective=[panel valueForKey:@"objective"];
  for (NSString* invalid in @[@"",[@"x" stringByPaddingToLength:2049 withString:@"x" startingAtIndex:0],[@"é" stringByPaddingToLength:1025 withString:@"é" startingAtIndex:0]]) {
    objective.stringValue=invalid; [panel ask:nil]; Require(!panel.busy && peer.calls.count==1,"objective byte bound bypassed");
  }
  objective.stringValue=@"Select useful original fields.";
  Require(![panel setObjective:@""] && [panel setObjective:@"Select the explicitly supplied fields."],"named objective bounds/action failed");
  [panel setSelectedCandidateIDs:@[@"r0f0",@"r1f1",@"r0f5"]];
  Require([panel.previewText containsString:@"inaccessible"] && ![panel.previewText containsString:@"OWNED-0-1"],"explicit preview selection failed");
  __block NSUInteger revocations=0,uses=0; panel.requestRevocation=^{++revocations;};
  panel.proposalHandler=^(NSDictionary* proposed,NSDictionary* usedGuard,NSArray* ids){ Require([proposed isEqual:Proposal(batch,ids)[@"batch"]] && [usedGuard isEqual:guard],"Use fabricated fields/guard"); ++uses; };
  Start(peer,panel,guard,@"positive_use"); [peer reply:Status(guard,Proposal(batch,@[@"r0f0",@"r1f1"]))];
  Require(!panel.busy && panel.proposal && [panel.disclosureCaption containsString:@"disclosed"],"complete proposal unavailable");
  [panel useProposal:nil]; Require(uses==1 && revocations==0 && !panel.proposal && !panel.taskID,"Use did not consume without extra Stop"); [panel retire]; Require(revocations==0,"post-Use retirement revoked consumed candidate");

  // Caller mutation cannot alter retained source or the exact immutable Review.
  NSMutableDictionary* mutableBatch=[NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:batch options:0 error:nil] options:NSJSONReadingMutableContainers error:nil];
  NSDictionary* exactOriginalReview=Review(mutableBatch);
  peer=[[ClosedPeer alloc] init]; panel=[[BSAgentPanel alloc] initWithConnection:peer configuration:Config()];
  [panel setReview:exactOriginalReview publicationGuard:guard batch:mutableBatch]; [panel updateAvailability:YES];
  [peer reply:@{@"op":@"agent_metadata",@"state":@"ready",@"descriptor":Descriptor()}];
  mutableBatch[@"rows"][0][@"fields"][0][@"state"][@"value"]=@"MUTATED_AFTER_CAPTURE";
  Require(![panel.previewText containsString:@"MUTATED_AFTER_CAPTURE"],"caller mutation changed native preview");
  [panel ask:nil]; Require([peer.submitted[@"review"] isEqual:exactOriginalReview],"caller mutation changed submitted Review"); [panel retire]; [peer reply:nil];

  // Retirement during metadata clears fields but keeps truthful in-flight busy.
  peer=[[ClosedPeer alloc] init]; panel=[[BSAgentPanel alloc] initWithConnection:peer configuration:Config()];
  panel.requestRevocation=^{++revocations;}; [panel setReview:Review(batch) publicationGuard:guard batch:batch]; [panel updateAvailability:YES]; [panel retire];
  Require(panel.busy && panel.previewText.length==0 && revocations==0,"metadata retirement invented revocation/finished call");
  [peer reply:@{@"op":@"agent_metadata",@"state":@"ready",@"descriptor":Descriptor()}]; Require(!panel.busy && !panel.canAsk && panel.previewText.length==0,"late metadata restored source");

  // New immutable source does not free an occupied metadata slot. The old
  // callback cannot clear a subsequent busy state through reentrant outer UI.
  peer=[[ClosedPeer alloc] init]; panel=[[BSAgentPanel alloc] initWithConnection:peer configuration:Config()];
  [panel setReview:Review(batch) publicationGuard:guard batch:batch]; [panel updateAvailability:YES];
  [panel setReview:Review(batch) publicationGuard:guard batch:batch];
  Require(panel.busy && peer.calls.count==1 && [panel.previewText containsString:@"OWNED-1-1"],"metadata replacement lost selection or freed slot");
  __weak BSAgentPanel* weakPanel=panel; panel.busyChanged=^(BOOL busy){ if (!busy) [weakPanel updateAvailability:YES]; };
  [peer reply:@{@"op":@"agent_metadata",@"state":@"ready",@"descriptor":Descriptor()}];
  Require(panel.busy && peer.calls.count==2,"old metadata completion cleared new request busy");
  [peer reply:@{@"op":@"agent_metadata",@"state":@"ready",@"descriptor":Descriptor()}]; Require(panel.canAsk && !panel.busy,"new metadata/source unavailable");

  // Opening metadata continues under the parent's ordinary-control busy gate.
  peer=[[ClosedPeer alloc] init]; panel=[[BSAgentPanel alloc] initWithConnection:peer configuration:Config()]; [panel setReview:Review(batch) publicationGuard:guard batch:batch];
  __weak BSAgentPanel* openingPanel=panel; panel.busyChanged=^(BOOL busy){ [openingPanel updateAvailability:!busy]; }; [panel updateAvailability:YES];
  [peer reply:@{@"op":@"agent_metadata",@"state":@"opening",@"descriptor":NSNull.null}];
  Require(!panel.busy && !panel.canAsk,"metadata opening blocked deterministic controls between calls");
  NSDate* openingLimit=[NSDate dateWithTimeIntervalSinceNow:1]; while (!peer.pending && [openingLimit timeIntervalSinceNow]>0) Drain(.01);
  if (!(panel.busy && peer.pending && peer.calls.count==2)) fprintf(stderr,"opening state=%s busy=%d calls=%lu pending=%d\n",panel.state.UTF8String,panel.busy,(unsigned long)peer.calls.count,peer.pending!=nil);
  Require(panel.busy && peer.pending && peer.calls.count==2,"metadata opening deadlocked parent busy gate");
  [peer reply:@{@"op":@"agent_metadata",@"state":@"ready",@"descriptor":Descriptor()}]; Require(panel.canAsk,"opening metadata did not become ready");

  // In-flight Start revoked once; its late acknowledgement cannot revive source.
  peer=[[ClosedPeer alloc] init]; panel=Ready(peer,guard,batch); panel.requestRevocation=^{++revocations;}; [panel ask:nil]; [panel retire]; [panel retire];
  Require(revocations==1 && panel.busy && panel.previewText.length==0,"Start retirement wrong revocation/busy");
  [peer reply:@{@"op":@"agent_started",@"task_id":@"task",@"candidate_ids":peer.submitted[@"ids"],@"publication_guard":guard}];
  Require(!panel.busy && !panel.taskID && !panel.proposal && [panel.disclosureCaption containsString:@"disclosed"],"late Start resurrected task/disclosure erased");

  // Old poll after Stop/source replacement cannot install its completed data.
  peer=[[ClosedPeer alloc] init]; panel=Ready(peer,guard,batch); __block NSUInteger pollRevocations=0; panel.requestRevocation=^{++pollRevocations;}; Start(peer,panel,guard,@"retired_old_poll"); [panel retire];
  [panel setReview:Review(batch) publicationGuard:guard batch:batch]; Require(panel.busy && !panel.canAsk,"old poll prematurely freed slot");
  [peer reply:Status(guard,Proposal(batch,@[@"r0f0"]))]; Require(pollRevocations==1 && !panel.proposal && !panel.taskID && !panel.busy && panel.canAsk,"retired poll restored proposal or lost new source");

  // Typed role/model/account metadata, not configuration alone, gates Ask.
  for (NSString* key in @[@"role",@"model",@"account_ref",@"protocol_version",@"floating_version"]) {
    peer=[[ClosedPeer alloc] init]; panel=[[BSAgentPanel alloc] initWithConnection:peer configuration:Config()]; [panel setReview:Review(batch) publicationGuard:guard batch:batch]; [panel updateAvailability:YES];
    NSMutableDictionary* descriptor=[Descriptor() mutableCopy];
    if ([key isEqual:@"floating_version"]) descriptor[@"protocol_version"]=@1.0;
    else descriptor[key]=[key isEqual:@"protocol_version"]?@YES:@"wrong";
    [peer reply:@{@"op":@"agent_metadata",@"state":@"ready",@"descriptor":descriptor}]; Require(!panel.canAsk && !panel.busy && !panel.metadata,"untrusted metadata actionable");
  }

  // Completed terminal task consumption permits a deterministic action without
  // pretending an active or outstanding operation was consumed.
  for (NSString* terminal in @[@"no_match",@"failed",@"canceled",@"expired"]) {
    peer=[[ClosedPeer alloc] init]; panel=Ready(peer,guard,batch); __block NSUInteger consumedRevoke=0; panel.requestRevocation=^{++consumedRevoke;}; Start(peer,panel,guard,[@"terminal_" stringByAppendingString:terminal]);
    [peer reply:@{@"op":@"agent_status",@"task_id":@"task",@"state":terminal,@"export_disposition":@"provider_retained_unknown",@"publication_guard":[terminal isEqual:@"no_match"]?guard:NSNull.null,@"proposal":NSNull.null,@"code":[terminal isEqual:@"failed"]?@"provider_unavailable":NSNull.null}];
    Require(!panel.busy && [panel.state isEqual:terminal] && !panel.proposal,"terminal task fabricated success"); [panel consumeProposal]; [panel retire]; Require(consumedRevoke==0 && !panel.taskID,"completed consume sent redundant Stop");
  }

  // Unselected field, generated value, wrong identity/guard and expired Use fail.
  for (NSUInteger attack=0;attack<5;++attack) {
    peer=[[ClosedPeer alloc] init]; panel=Ready(peer,guard,batch); panel.requestRevocation=^{++revocations;}; Start(peer,panel,guard,[NSString stringWithFormat:@"attack_%lu",(unsigned long)attack]);
    NSMutableDictionary* status=[Status(guard,Proposal(batch,@[@"r0f0"])) mutableCopy];
    if (attack==0) status[@"proposal"]=Proposal(batch,@[@"r0f2"]);
    if (attack==1) { NSMutableDictionary* altered=[batch mutableCopy]; NSMutableArray* rows=[batch[@"rows"] mutableCopy]; NSMutableArray* fields=[rows[0][@"fields"] mutableCopy]; NSMutableDictionary* field=[fields[0] mutableCopy]; field[@"state"]=@{@"kind":@"value",@"source":@"GENERATED",@"value":@"GENERATED"}; fields[0]=field; rows[0]=@{@"fields":fields}; altered[@"rows"]=rows; status[@"proposal"]=Proposal(altered,@[@"r0f0"]); }
    if (attack==2) status[@"task_id"]=@"other";
    if (attack==3) status[@"publication_guard"]=Guard(90000000000);
    [peer reply:status];
    if (attack<4) Require(!panel.proposal && !panel.canAsk,"invalid proposal retained/actionable");
    else { [panel retire]; [panel useProposal:nil]; Require(!panel.proposal,"retired proposal used"); }
  }
  // Real native expiry, not a fake clock, prevents Use after display lifetime.
  NSDictionary* shortGuard=Guard(3000000000); peer=[[ClosedPeer alloc] init]; panel=Ready(peer,shortGuard,batch);
  __block NSUInteger expiredUse=0, expiredRevoke=0; panel.proposalHandler=^(NSDictionary*,NSDictionary*,NSArray*){++expiredUse;}; panel.requestRevocation=^{++expiredRevoke;};
  Start(peer,panel,shortGuard,@"expired_use"); [peer reply:Status(shortGuard,Proposal(batch,@[@"r0f0"]))]; Require(panel.proposal,"short-lived candidate missing");
  while ([BSTableConnection publicationGuardIsCurrent:shortGuard]) usleep(5000);
  [panel useProposal:nil]; Require(expiredUse==0 && expiredRevoke==1 && !panel.canAsk && !panel.proposal && panel.previewText.length==0,"real expired Use restored source or skipped revoke");
  shortGuard=Guard(3000000000); peer=[[ClosedPeer alloc] init]; panel=Ready(peer,shortGuard,batch); Start(peer,panel,shortGuard,@"native_expiry_watch"); [peer reply:Status(shortGuard,Proposal(batch,@[@"r0f0"]))];
  NSDate* expiryLimit=[NSDate dateWithTimeIntervalSinceNow:4]; while (panel.proposal && [expiryLimit timeIntervalSinceNow]>0) Drain(.01);
  Require(!panel.proposal && panel.previewText.length==0,"completed display did not retire on native expiry");
  // Pending wire ownership remains busy even when native expiry retires source.
  shortGuard=Guard(150000000); peer=[[ClosedPeer alloc] init]; panel=Ready(peer,shortGuard,batch); [panel ask:nil];
  expiryLimit=[NSDate dateWithTimeIntervalSinceNow:2]; while (panel.previewText.length && [expiryLimit timeIntervalSinceNow]>0) Drain(.01);
  Require(panel.previewText.length==0 && panel.busy && !panel.taskID,"in-flight expiry freed wire slot or retained source");
  [peer reply:@{@"op":@"agent_started",@"task_id":@"task",@"candidate_ids":peer.submitted[@"ids"],@"publication_guard":shortGuard}]; Require(!panel.busy && !panel.taskID,"expired Start resurrected task");
  [NSProcessInfo.processInfo endActivity:activity];
  NSLog(@"native_agent_panel state/epoch/grounding passed");
} return 0; }
