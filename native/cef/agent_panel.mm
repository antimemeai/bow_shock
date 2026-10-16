#import "agent_panel.h"
#import "continuous_clock.h"

namespace {
BOOL Text(id value, NSUInteger maximum, BOOL empty = NO) {
  if (![value isKindOfClass:NSString.class]) return NO;
  NSData* bytes=[value dataUsingEncoding:NSUTF8StringEncoding]; return bytes && bytes.length<=maximum && (empty || bytes.length>0);
}
id Snapshot(id value, NSUInteger maximum) {
  if (![NSJSONSerialization isValidJSONObject:value]) return nil;
  NSData* bytes=[NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:nil];
  return bytes && bytes.length<=maximum ? [NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil] : nil;
}
NSString* JSON(id value) { NSData* bytes=[NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil]; return bytes ? [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] : @""; }
BOOL Descriptor(NSDictionary* value, BSAgentConfiguration* config) {
  if (![value isKindOfClass:NSDictionary.class] || value.count!=14 || !config) return NO;
  NSDictionary* fixed=@{@"runtime":@"codex",@"version":@"0.162.1",@"role":@"trusted_coding_peer",@"placement":@"hosted",@"provider":@"openai",@"account_type":@"chatgpt",@"protocol_version":@1,@"account_verification":@"measured_backend_reference",@"structured_output":@"unverified",@"history":@"fresh_only",@"steer":@"unsupported",@"cancellation":@"host_retirement_and_owned_child_kill"};
  for (NSString* key in fixed) if (![value[key] isEqual:fixed[key]]) return NO;
  if (![value[@"protocol_version"] isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value[@"protocol_version"])==CFBooleanGetTypeID()) return NO;
  const char* numberType=[value[@"protocol_version"] objCType]; if (numberType[0]=='d' || numberType[0]=='f') return NO;
  return Text(value[@"model"],256) && [value[@"model"] isEqual:config.model] && Text(value[@"account_ref"],256) &&
      (!config.expectedAccountID || [value[@"account_ref"] isEqual:config.expectedAccountID]);
}
NSButton* Button(NSView* view, NSString* title, id target, SEL action, NSRect frame) {
  NSButton* button=[NSButton buttonWithTitle:title target:target action:action]; button.frame=frame; [view addSubview:button]; return button;
}
}

@implementation BSAgentPanel {
  BSTableConnection* _connection;
  BSAgentConfiguration* _configuration;
  NSPanel* _panel;
  NSTextField* _status;
  NSTextField* _objective;
  NSTextField* _disclosure;
  NSTextView* _preview;
  NSButton* _ask;
  NSButton* _use;
  NSMutableDictionary<NSString*,NSButton*>* _checks;
  NSDictionary* _review;
  NSDictionary* _guard;
  NSDictionary* _batch;
  NSDictionary* _metadata;
  NSDictionary* _proposal;
  NSDictionary* _taskGuard;
  NSArray<NSString*>* _selected;
  NSString* _taskID;
  NSString* _state;
  NSString* _disclosureCaption;
  NSTimer* _timer;
  NSTimer* _expiryTimer;
  BOOL _available, _busy, _inflight, _active, _metadataFinished;
  uint64_t _epoch, _metadataStart;
}
- (instancetype)initWithConnection:(BSTableConnection*)connection configuration:(BSAgentConfiguration*)configuration {
  self=[super init]; if (!self) return nil;
  _connection=connection; _configuration=configuration; _checks=[NSMutableDictionary dictionary]; _selected=@[];
  _state=configuration?@"opening":@"unconfigured"; _disclosureCaption=@"No fields submitted by this panel.";
  _panel=[[NSPanel alloc] initWithContentRect:NSMakeRect(80,100,550,660) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
  _panel.title=@"Bow Shock · selected-source proposal"; _panel.releasedWhenClosed=NO;
  NSView* view=_panel.contentView;
  _status=[NSTextField wrappingLabelWithString:configuration?@"Agent metadata will open when the table is ready.":@"Agent unconfigured. The deterministic table controls remain available."];
  _status.frame=NSMakeRect(16,570,518,74); [view addSubview:_status];
  _objective=[[NSTextField alloc] initWithFrame:NSMakeRect(16,378,518,30)]; _objective.placeholderString=@"What should Codex select?"; _objective.stringValue=@"Select the useful captured fields for this table."; [view addSubview:_objective];
  NSScrollView* scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(16,85,518,282)]; scroll.hasVerticalScroller=YES;
  _preview=[[NSTextView alloc] initWithFrame:NSMakeRect(0,0,518,282)]; _preview.editable=NO; _preview.font=[NSFont userFixedPitchFontOfSize:11]; scroll.documentView=_preview; [view addSubview:scroll];
  _disclosure=[NSTextField wrappingLabelWithString:_disclosureCaption]; _disclosure.frame=NSMakeRect(16,39,518,42); [view addSubview:_disclosure];
  _ask=Button(view,@"Ask Codex",self,@selector(ask:),NSMakeRect(16,5,170,30));
  _use=Button(view,@"Use proposal · new Review",self,@selector(useProposal:),NSMakeRect(205,5,329,30));
  [self buttons]; return self;
}
- (NSPanel*)panel { return _panel; }
- (BOOL)busy { return _busy; }
- (BOOL)canAsk { [self buttons]; return _ask.enabled; }
- (NSString*)taskID { return _taskID; }
- (NSDictionary*)proposal { return _proposal; }
- (NSDictionary*)metadata { return _metadata; }
- (NSString*)state { return _state; }
- (NSString*)previewText { return _preview.string; }
- (NSString*)disclosureCaption { return _disclosureCaption; }
- (BOOL)current { return _review && _batch && [BSTableConnection publicationGuardIsCurrent:_guard]; }
- (void)buttons {
  BOOL source=_available && _connection.connected && [self current];
  _ask.enabled=source && !_busy && _metadata && !_active && _selected.count>0;
  _use.enabled=source && !_busy && _proposal && [BSTableConnection publicationGuardIsCurrent:_taskGuard];
  _objective.enabled=source && !_busy && !_active;
  for (NSButton* check in _checks.allValues) check.enabled=source && !_busy && !_active;
}
- (void)busyValue:(BOOL)value { BOOL changed=_busy!=value; _busy=value; [self buttons]; if (changed && self.busyChanged) self.busyChanged(value); }
- (void)clearPublication {
  ++_epoch; [_timer invalidate]; _timer=nil; [_expiryTimer invalidate]; _expiryTimer=nil;
  _review=nil; _guard=nil; _batch=nil; _proposal=nil; _taskGuard=nil; _taskID=nil; _selected=@[];
  for (NSButton* check in _checks.allValues) [check removeFromSuperview]; [_checks removeAllObjects];
  _preview.string=@""; _state=@"retired"; _status.stringValue=@"Captured source retired. Observe and review again.";
  [self buttons];
}
- (void)retire {
  BOOL revoke=_active; _active=NO; [self clearPublication];
  [self busyValue:_inflight];
  if (revoke && self.requestRevocation) self.requestRevocation();
}
- (void)consumeProposal {
  // Running or in-flight work must cross the normal revocation boundary.
  if (_inflight || (_active && ![@[@"candidate",@"no_match",@"failed",@"canceled",@"expired"] containsObject:_state])) { [self retire]; return; }
  _active=NO; [self clearPublication]; [self busyValue:NO];
}
- (void)setReview:(NSDictionary*)review publicationGuard:(NSDictionary*)guard batch:(NSDictionary*)batch {
  BOOL retiringTask=_active;
  [self retire];
  // Revocation may synchronously retire the enclosing table decision. Do not
  // install this new source across that authority change; require fresh Review.
  if (retiringTask) return;
  NSDictionary* copiedBatch=Snapshot(batch,16384); NSDictionary* copiedReview=Snapshot(review,65536); NSDictionary* copiedGuard=Snapshot(guard,512);
  if (!copiedBatch || !copiedReview || ![BSTableConnection publicationGuardIsCurrent:copiedGuard] || !Text(copiedReview[@"content"],65536)) return;
  NSDictionary* content=[NSJSONSerialization JSONObjectWithData:[copiedReview[@"content"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
  if (![content isKindOfClass:NSDictionary.class] || ![content[@"batch"] isEqual:copiedBatch] || ![copiedBatch[@"rows"] isKindOfClass:NSArray.class] || [copiedBatch[@"rows"] count]==0 || [copiedBatch[@"rows"] count]>2) return;
  NSArray* names=@[@"name",@"price",@"note",@"sku",@"quantity",@"private"];
  for (id row in copiedBatch[@"rows"]) {
    if (![row isKindOfClass:NSDictionary.class] || ![row[@"fields"] isKindOfClass:NSArray.class] || [row[@"fields"] count]!=6) return;
    for (NSUInteger f=0;f<6;++f) {
      id field=row[@"fields"][f]; if (![field isKindOfClass:NSDictionary.class] || ![field[@"name"] isEqual:names[f]] ||
          ![field[@"state"] isKindOfClass:NSDictionary.class] || ![field[@"source"] isKindOfClass:NSDictionary.class]) return;
      if (f==5 && (![field[@"state"][@"kind"] isEqual:@"inaccessible"] || field[@"source"][@"fragment"])) return;
    }
  }
  _review=copiedReview; _guard=copiedGuard; _batch=copiedBatch;
  NSMutableArray* defaults=[NSMutableArray array];
  for (NSUInteger r=0;r<[copiedBatch[@"rows"] count];++r) for (NSUInteger f=0;f<6;++f) {
    NSString* id=[NSString stringWithFormat:@"r%luf%lu",(unsigned long)r,(unsigned long)f];
    NSButton* check=[NSButton checkboxWithTitle:[NSString stringWithFormat:@"Row %lu · %@",(unsigned long)r+1,names[f]] target:self action:@selector(selectionChanged:)];
    check.frame=NSMakeRect(16+r*260,540-f*21,255,21); _checks[id]=check; [_panel.contentView addSubview:check]; if (f<2) [defaults addObject:id];
  }
  _state=_metadata?@"ready":(_configuration?(_metadataFinished?@"unavailable":@"opening"):@"unconfigured");
  if (_metadata) [self showReadyMetadata];
  else _status.stringValue=_metadataFinished?@"Agent unavailable. Deterministic controls remain available.":
      (_configuration?@"Agent metadata opening; captured fields remain local until Ask.":@"Agent unconfigured. Deterministic controls remain available.");
  [self applySelection:defaults];
  __weak BSAgentPanel* weakSelf=self;
  _expiryTimer=[NSTimer timerWithTimeInterval:.1 repeats:YES block:^(NSTimer*) { [weakSelf watch]; }];
  [NSRunLoop.mainRunLoop addTimer:_expiryTimer forMode:NSRunLoopCommonModes];
}
- (void)updateAvailability:(BOOL)available {
  _available=available; [self buttons];
  if (available && _configuration && !_metadataFinished && !_inflight && !_busy && !_timer) [self metadataRequest];
}
- (BOOL)setSelectedCandidateIDs:(NSArray<NSString*>*)ids {
  if (_busy || _active || ![ids isKindOfClass:NSArray.class] || ids.count>12) return NO;
  NSMutableSet* seen=[NSMutableSet set]; for (id token in ids) { if (![token isKindOfClass:NSString.class] || !_checks[token] || [seen containsObject:token]) return NO; [seen addObject:token]; }
  [self applySelection:ids]; return YES;
}
- (BOOL)setObjective:(NSString*)objective {
  [self buttons];
  if (!_objective.enabled || !Text(objective,2048)) return NO;
  _objective.stringValue=[objective copy]; return YES;
}
- (void)applySelection:(NSArray<NSString*>*)ids {
  NSSet* seen=[NSSet setWithArray:ids];
  NSMutableArray* ordered=[NSMutableArray array]; for (NSString* token in [_checks.allKeys sortedArrayUsingSelector:@selector(compare:)]) { _checks[token].state=[seen containsObject:token]?NSControlStateValueOn:NSControlStateValueOff; if ([seen containsObject:token]) [ordered addObject:token]; }
  _selected=[ordered copy]; [self preview]; [self buttons];
}
- (void)selectionChanged:(id)sender {
  (void)sender; NSMutableArray* ids=[NSMutableArray array]; for (NSString* token in [_checks.allKeys sortedArrayUsingSelector:@selector(compare:)]) if (_checks[token].state==NSControlStateValueOn) [ids addObject:token]; [self setSelectedCandidateIDs:ids];
}
- (NSDictionary*)subset:(NSArray*)ids {
  if (![ids isKindOfClass:NSArray.class] || ids.count==0 || ids.count>12 || [NSSet setWithArray:ids].count!=ids.count) return nil;
  for (id token in ids) if (![_selected containsObject:token]) return nil;
  NSMutableArray* rows=[NSMutableArray array];
  for (NSUInteger r=0;r<[_batch[@"rows"] count];++r) { NSMutableArray* fields=[NSMutableArray array]; for (NSUInteger f=0;f<6;++f) if ([ids containsObject:[NSString stringWithFormat:@"r%luf%lu",(unsigned long)r,(unsigned long)f]]) [fields addObject:_batch[@"rows"][r][@"fields"][f]]; if (fields.count) [rows addObject:@{@"fields":fields}]; }
  return @{@"schema_version":_batch[@"schema_version"],@"pattern_version":_batch[@"pattern_version"],@"partial":@YES,@"rows":rows};
}
- (void)preview {
  NSDictionary* subset=[self subset:_selected];
  _preview.string=subset?JSON(@{@"candidate_ids":_selected,@"batch":subset}):@"Select captured fields before Ask.";
}
- (void)timerFor:(SEL)selector {
  [_timer invalidate]; __weak BSAgentPanel* weakSelf=self;
  _timer=[NSTimer timerWithTimeInterval:.1 repeats:NO block:^(NSTimer*) { BSAgentPanel* strong=weakSelf; if (strong) { strong->_timer=nil; if (selector==@selector(metadataRequest)) [strong metadataRequest]; else [strong poll]; } }];
  [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}
- (void)metadataRequest {
  if ((!_available && !_busy) || !_connection.connected || !_configuration || _inflight || _metadataFinished) { [self busyValue:NO]; return; }
  NSDictionary* clock=BSContinuousClockWitness(); uint64_t now=[clock[@"continuous_ns"] unsignedLongLongValue];
  if (!_metadataStart) _metadataStart=now;
  if (!clock || now<_metadataStart || now-_metadataStart>=30000000000) { _metadataFinished=YES; _state=@"unavailable"; _status.stringValue=@"Agent metadata unavailable. Deterministic controls remain available."; [self busyValue:NO]; return; }
  _inflight=YES; [self busyValue:YES]; uint64_t epoch=_epoch;
  [_connection agentMetadataWithCompletion:^(NSDictionary* reply) {
    self->_inflight=NO;
    if (epoch!=self->_epoch) { [self busyValue:NO]; return; }
    if ([reply[@"op"] isEqual:@"agent_metadata"] && [reply[@"state"] isEqual:@"opening"]) {
      self->_state=@"opening"; [self timerFor:@selector(metadataRequest)]; [self busyValue:NO]; return;
    }
    self->_metadataFinished=YES;
    if ([reply[@"op"] isEqual:@"agent_metadata"] && [reply[@"state"] isEqual:@"ready"] && Descriptor(reply[@"descriptor"],self->_configuration)) {
      self->_metadata=Snapshot(reply[@"descriptor"],4096); self->_state=@"ready";
      [self showReadyMetadata];
    } else { self->_state=@"unavailable"; self->_status.stringValue=@"Agent unavailable. Deterministic controls remain available."; }
    [self busyValue:NO];
  }];
}
- (void)showReadyMetadata {
  _status.stringValue=[NSString stringWithFormat:@"Codex %@ · trusted coding peer · hosted OpenAI\nModel: %@ · ChatGPT account: %@\nFresh task only; source selection is explicit.",_metadata[@"version"],_metadata[@"model"],_metadata[@"account_ref"]];
}
- (BOOL)taskCurrent:(NSDictionary*)guard {
  return [self current] && [BSTableConnection publicationGuardIsCurrent:guard] && [guard[@"boot_id"] isEqual:_guard[@"boot_id"]] &&
      [guard[@"valid_until_ns"] unsignedLongLongValue]<=[_guard[@"valid_until_ns"] unsignedLongLongValue] &&
      (!_taskGuard || [guard isEqual:_taskGuard]);
}
- (void)ask:(id)sender {
  (void)sender; [self buttons]; if (!_ask.enabled || _selected.count==0) return;
  if (!Text(_objective.stringValue,2048)) { _status.stringValue=@"Enter a short objective describing what Codex should select."; return; }
  [_timer invalidate]; _timer=nil;
  uint64_t epoch=_epoch; _active=YES; _inflight=YES; _state=@"requesting";
  _disclosureCaption=@"Selected fields may have been disclosed; retirement cannot retract provider copies."; _disclosure.stringValue=_disclosureCaption;
  [self busyValue:YES];
  [_connection startAgentReview:_review candidateIDs:_selected objective:_objective.stringValue ttlMs:60000 publicationGuard:_guard completion:^(NSDictionary* reply) {
    self->_inflight=NO; if (epoch!=self->_epoch) { [self busyValue:NO]; return; }
    if (![reply[@"op"] isEqual:@"agent_started"] || !Text(reply[@"task_id"],256) || ![reply[@"candidate_ids"] isEqual:self->_selected] || ![self taskCurrent:reply[@"publication_guard"]]) { [self fail]; return; }
    self->_taskID=[reply[@"task_id"] copy]; self->_taskGuard=Snapshot(reply[@"publication_guard"],512); self->_state=@"running";
    self->_status.stringValue=@"Task running. Use will create a table for your review. Save remains separate."; [self timerFor:@selector(poll)];
  }];
}
- (void)fail { [self retire]; _state=@"unavailable"; _status.stringValue=@"Agent result unavailable or no longer grounded. Observe and review again."; }
- (void)poll {
  if (_inflight) return;
  if (!_active || ![self taskCurrent:_taskGuard]) { [self fail]; return; }
  _inflight=YES; uint64_t epoch=_epoch;
  [_connection statusAgent:_taskID completion:^(NSDictionary* reply) {
    self->_inflight=NO; if (epoch!=self->_epoch) { [self busyValue:NO]; return; }
    if (![reply[@"op"] isEqual:@"agent_status"] || ![reply[@"task_id"] isEqual:self->_taskID] || ![self taskCurrent:self->_taskGuard]) { [self fail]; return; }
    NSString* state=reply[@"state"];
    if ([state isEqual:@"running"]) { [self timerFor:@selector(poll)]; return; }
    if ([state isEqual:@"candidate"] && [self taskCurrent:reply[@"publication_guard"]]) {
      NSDictionary* candidate=Snapshot(reply[@"proposal"],20000); NSDictionary* expected=[self subset:candidate[@"candidate_ids"]];
      if (!candidate || !expected || ![candidate[@"batch"] isEqual:expected] || !Text(candidate[@"explanation"],2048,YES)) { [self fail]; return; }
      self->_proposal=candidate; self->_state=@"candidate"; self->_preview.string=JSON(@{@"candidate_ids":candidate[@"candidate_ids"],@"batch":expected,@"explanation":candidate[@"explanation"]});
      self->_status.stringValue=@"Proposal ready. Use creates a table for your review. Save remains separate.";
    } else if ([@[@"no_match",@"failed",@"canceled",@"expired"] containsObject:state]) {
      if ([state isEqual:@"no_match"] && ![self taskCurrent:reply[@"publication_guard"]]) { [self fail]; return; }
      self->_state=state; self->_status.stringValue=[state isEqual:@"no_match"]?@"No matching selection. Adjust your objective after a fresh Review.":@"Task ended without a usable proposal. A fresh Review is required.";
    } else { [self fail]; return; }
    [self busyValue:NO];
  }];
}
- (void)watch {
  if (!_review) return;
  if (!_connection.connected || ![self current] || (_active && _taskGuard && ![self taskCurrent:_taskGuard])) { [self retire]; return; }
  [self buttons];
}
- (void)useProposal:(id)sender {
  (void)sender; [self buttons];
  if (!_use.enabled || !_proposal || ![self taskCurrent:_taskGuard]) {
    if (_review && (![self current] || (_active && _taskGuard && ![self taskCurrent:_taskGuard]))) [self retire]; return;
  }
  NSDictionary* batch=[self subset:_proposal[@"candidate_ids"]];
  if (!batch || ![batch isEqual:_proposal[@"batch"]]) { [self fail]; return; }
  NSDictionary* guard=_taskGuard; NSArray* ids=_proposal[@"candidate_ids"]; [self consumeProposal];
  if (self.proposalHandler) self.proposalHandler(batch,guard,ids);
}
- (void)dealloc { [_timer invalidate]; [_expiryTimer invalidate]; }
@end
