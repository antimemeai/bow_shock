#import "../native/cef/table_connection.mm"
#import <Foundation/Foundation.h>
#include <iostream>

namespace {
NSDictionary* Descriptor() {
  return @{@"runtime":@"codex", @"version":@"0.160.0", @"role":@"trusted_coding_peer",
      @"placement":@"hosted", @"model":@"fixture-model", @"provider":@"openai",
      @"account_ref":@"fixture-account", @"account_type":@"chatgpt", @"protocol_version":@1,
      @"account_verification":@"measured_backend_reference", @"structured_output":@"unverified",
      @"history":@"fresh_only", @"steer":@"unsupported", @"cancellation":@"host_retirement_and_owned_child_kill"};
}
NSDictionary* Payload(NSString* op, NSDictionary* fields) {
  NSMutableDictionary* value = [@{@"version":@1,@"op":op,@"run_id":@"owned-run",@"id":@1,@"stop_generation":@0} mutableCopy];
  [value addEntriesFromDictionary:fields]; return value;
}
bool Accept(NSString* request, NSDictionary* fields, NSDictionary* reply, NSDictionary* guard) {
  BSTablePending* pending = [BSTablePending new];
  NSMutableDictionary* value = [@{@"version":@1,@"op":request,@"id":@1} mutableCopy];
  [value addEntriesFromDictionary:fields]; pending.request = value; pending.approvalGuard = guard;
  NSData* frame = Encode(reply);
  return Decode([frame subdataWithRange:NSMakeRange(0,frame.length-1)],pending,@"owned-run",0,0) != nil;
}
void Require(bool actual, bool expected, const char* label) {
  if (actual != expected) { std::cerr << label << '\n'; std::exit(1); }
}
}
int main() {
  @autoreleasepool {
    NSDictionary* witness = BSContinuousClockWitness();
    if (!witness) return 2;
    NSDictionary* guard = @{@"boot_id":witness[@"boot_id"],@"valid_until_ns":@([witness[@"continuous_ns"] unsignedLongLongValue]+1000000000)};
    NSDictionary* ready = Payload(@"agent_metadata",@{@"state":@"ready",@"descriptor":Descriptor()});
    Require(Accept(@"agent_metadata",@{},ready,nil),true,"valid ready metadata refused");
    Require(Accept(@"agent_metadata",@{},Payload(@"agent_metadata",@{@"state":@"opening",@"descriptor":NSNull.null}),nil),true,"opening metadata refused");
    NSMutableDictionary* badDescriptor = [Descriptor() mutableCopy]; badDescriptor[@"command"] = @"execute";
    Require(Accept(@"agent_metadata",@{},Payload(@"agent_metadata",@{@"state":@"ready",@"descriptor":badDescriptor}),nil),false,"unknown descriptor field accepted");
    badDescriptor = [Descriptor() mutableCopy]; badDescriptor[@"role"] = @"constrained_browser_model";
    Require(Accept(@"agent_metadata",@{},Payload(@"agent_metadata",@{@"state":@"ready",@"descriptor":badDescriptor}),nil),false,"unverified role accepted");
    Require(Accept(@"agent_metadata",@{},Payload(@"agent_metadata",@{@"state":@"opening",@"descriptor":Descriptor()}),nil),false,"opening descriptor accepted");
    NSDictionary* startFields = @{@"candidate_ids":@[@"r0f0"],@"review":@{@"staging_id":@"stage",@"version":@1,@"content":@"opaque"}};
    Require(Accept(@"agent_start",startFields,Payload(@"agent_started",@{@"task_id":@"task",@"publication_guard":guard,@"candidate_ids":@[@"r0f0"]}),guard),true,"valid start refused");
    Require(Accept(@"agent_start",startFields,Payload(@"agent_started",@{@"task_id":@"task",@"publication_guard":guard,@"candidate_ids":@[@"r0f1"]}),guard),false,"changed selected IDs accepted");
    NSMutableDictionary* extended = [guard mutableCopy]; extended[@"valid_until_ns"] = @([guard[@"valid_until_ns"] unsignedLongLongValue]+1);
    Require(Accept(@"agent_start",startFields,Payload(@"agent_started",@{@"task_id":@"task",@"publication_guard":extended,@"candidate_ids":@[@"r0f0"]}),guard),false,"extended original source lifetime accepted");
    extended = [guard mutableCopy]; extended[@"boot_id"] = NSUUID.UUID.UUIDString;
    Require(Accept(@"agent_start",startFields,Payload(@"agent_started",@{@"task_id":@"task",@"publication_guard":extended,@"candidate_ids":@[@"r0f0"]}),guard),false,"different source boot accepted");
    NSDictionary* observation = @{@"run_id":@"owned-run",@"surface_id":@"browser-1",@"frame_id":@"frame",@"document_id":@"doc",@"capture_id":@"capture",@"security_origin":@"https://fixture.test",@"attachment_generation":@1,@"activation_generation":@1,@"node_generation":@1,@"capture_start_ns":@1,@"capture_end_ns":@2};
    NSDictionary* field = @{@"name":@"name",@"state":@{@"kind":@"value",@"source":@"Allowed",@"value":@"Allowed"},@"source":@{@"observation":observation,@"node_id":@1,@"visibility":@"layout-present-occlusion-unknown",@"normalization":@"text-trim-v1",@"fragment":@"Allowed"}};
    NSDictionary* batch = @{@"schema_version":@"owned-product-v1",@"pattern_version":@"owned-field-ids-v1",@"partial":@YES,@"rows":@[@{@"fields":@[field]}]};
    NSMutableDictionary* status = [@{@"task_id":@"task",@"state":@"running",@"export_disposition":@"not_transmitted",@"publication_guard":NSNull.null,@"proposal":NSNull.null,@"code":NSNull.null} mutableCopy];
    Require(Accept(@"agent_status",@{@"task_id":@"task"},Payload(@"agent_status",status),nil),true,"running null guard refused");
    status[@"state"] = @"candidate"; status[@"export_disposition"] = @"provider_retained_unknown"; status[@"publication_guard"] = guard;
    status[@"proposal"] = @{@"candidate_ids":@[@"r0f0"],@"batch":batch,@"explanation":@"Selected recorded name."};
    Require(Accept(@"agent_status",@{@"task_id":@"task"},Payload(@"agent_status",status),nil),true,"valid guarded candidate refused");
    NSDictionary* validProposal = status[@"proposal"];
    status[@"proposal"] = @{@"candidate_ids":@[@"r0f0",@"r0f0"],@"batch":batch,@"explanation":@"Duplicate"};
    Require(Accept(@"agent_status",@{@"task_id":@"task"},Payload(@"agent_status",status),nil),false,"duplicate candidate IDs accepted");
    status[@"proposal"] = @{@"candidate_ids":@[@"r0f0",@"r0f1"],@"batch":batch,@"explanation":@"Mismatch"};
    Require(Accept(@"agent_status",@{@"task_id":@"task"},Payload(@"agent_status",status),nil),false,"field count mismatch accepted");
    status[@"proposal"] = validProposal;
    Require(Accept(@"agent_status",@{@"task_id":@"different"},Payload(@"agent_status",status),nil),false,"wrong task accepted");
    status[@"publication_guard"] = NSNull.null;
    Require(Accept(@"agent_status",@{@"task_id":@"task"},Payload(@"agent_status",status),nil),false,"unguarded candidate accepted");
    status[@"publication_guard"] = guard; status[@"state"] = @"running";
    Require(Accept(@"agent_status",@{@"task_id":@"task"},Payload(@"agent_status",status),nil),false,"running candidate accepted");
    status[@"state"] = @"no_match"; status[@"proposal"] = NSNull.null;
    Require(Accept(@"agent_status",@{@"task_id":@"task"},Payload(@"agent_status",status),nil),true,"guarded no-match refused");
    Require(Accept(@"agent_cancel",@{@"task_id":@"task"},Payload(@"agent_canceled",@{@"task_id":@"task",@"export_disposition":@"not_transmitted"}),nil),true,"cancel refused");
    Require(Accept(@"agent_status",@{@"task_id":@"task"},Payload(@"agent_error",@{@"code":@"unknown_task"}),nil),true,"closed error refused");
    Require(Accept(@"agent_status",@{@"task_id":@"task"},Payload(@"agent_error",@{@"code":@"repair_and_execute"}),nil),false,"unknown error accepted");
    Require(Accept(@"table_status",@{@"commit_id":NSNull.null},Payload(@"agent_error",@{@"code":@"unknown_task"}),nil),false,"agent error crossed table operation");
    BSTableConnection* connection = [[BSTableConnection alloc] initWithExecutableURL:[NSURL fileURLWithPath:@"/unused"]
        databaseURL:[NSURL fileURLWithPath:@"/unused-db"] clockProbeURL:[NSURL fileURLWithPath:@"/unused-clock"] ownedOrigin:@"https://fixture.test"];
    __block BOOL rejected = NO;
    [connection startAgentReview:startFields[@"review"] candidateIDs:@[@"r0f0"] objective:@"Select name" ttlMs:1000 publicationGuard:guard completion:^(NSDictionary* reply) {
      rejected = [reply[@"reason"] isEqual:@"invalid_request"];
    }];
    Require(rejected,true,"unconfigured agent export admitted");
    std::cout << "Closed native agent decoder passed.\n";
  }
}
