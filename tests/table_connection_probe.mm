#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "table_connection.h"
#import "continuous_clock.h"
#include <cstdio>
#include <signal.h>

static void Print(NSString* label, NSDictionary* reply) {
  printf("%s %s\n", label.UTF8String, reply ? [reply[@"op"] UTF8String] : "nil"); fflush(stdout);
  if (reply) {
    NSData* bytes = [NSJSONSerialization dataWithJSONObject:reply options:0 error:nil];
    printf("RESULT %s\n", [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding].UTF8String); fflush(stdout);
  }
}

static void Finish(BSTableConnection* connection) {
  [connection closeWithCompletion:^(NSDictionary* closed) {
    Print(@"CLOSE", closed);
    [connection shutdownWithCompletion:^(NSDictionary* reply) {
      Print(@"SHUTDOWN", reply);
      if ([reply[@"op"] isEqual:@"shutdown"]) CFRunLoopStop(CFRunLoopGetCurrent());
    }];
  }];
}
static void PollSaved(BSTableConnection* connection, NSString* commit) {
  [connection statusCommit:commit completion:^(NSDictionary* state) {
    if ([state[@"op"] isEqual:@"table_status"] && ![state[@"state"] isEqual:@"committed"])
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ PollSaved(connection, commit); });
    else if ([state[@"state"] isEqual:@"committed"]) [connection readCommit:commit completion:^(NSDictionary* read) {
      Print(@"READ", read);
      [connection listWithCompletion:^(NSDictionary* listed) { Print(@"LIST", listed); Finish(connection); }];
    }];
    else Print(@"STATUS", state);
  }];
}
static void StageFixture(BSTableConnection* connection) {
  NSDictionary* witness = BSContinuousClockWitness();
  NSDictionary* observation = @{@"run_id": connection.runId, @"surface_id": @"owned-surface", @"frame_id": @"owned-frame",
      @"document_id": @"owned-doc", @"capture_id": @"owned-capture", @"security_origin": @"https://fixture.test",
      @"attachment_generation": @1, @"activation_generation": @1, @"node_generation": @1,
      @"capture_start_ns": witness[@"continuous_ns"], @"capture_end_ns": witness[@"continuous_ns"]};
  NSDictionary* field = @{@"name": @"name", @"state": @{@"kind": @"value", @"source": @"native-owned-marker", @"value": @"native-owned-marker"},
      @"source": @{@"observation": observation, @"node_id": @1, @"visibility": @"layout-present-occlusion-unknown",
      @"normalization": @"identity", @"fragment": @"native-owned-marker"}};
  NSDictionary* batch = @{@"schema_version": @"fixture-v1", @"pattern_version": @"literal-v1", @"partial": @YES,
      @"rows": @[@{@"fields": @[field]}]};
  [connection stageBatch:batch completion:^(NSDictionary* staged) {
    Print(@"STAGE", staged);
    if (!staged[@"staging_id"]) return;
    [connection reviewStaging:staged[@"staging_id"] retentionMs:30000 completion:^(NSDictionary* review) {
      Print(@"REVIEW", review); if (![review[@"op"] isEqual:@"table_reviewed"]) return;
      [connection approveReview:review[@"review"] publicationGuard:review[@"publication_guard"] completion:^(NSDictionary* approval) {
        Print(@"APPROVE", approval); if (!approval[@"approval_id"]) return;
        [connection commitApproval:approval[@"approval_id"] completion:^(NSDictionary* committed) {
          Print(@"COMMIT", committed); if (committed[@"commit_id"]) PollSaved(connection, committed[@"commit_id"]);
        }];
      }];
    }];
  }];
}
static void Ready(BSTableConnection* connection, BOOL reopen) {
  [connection statusCommit:nil completion:^(NSDictionary* reply) {
    if ([reply[@"op"] isEqual:@"table_status"] && ![reply[@"health"] isEqual:@"ready"])
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ Ready(connection, reopen); });
    else if ([reply[@"health"] isEqual:@"ready"]) [connection scopeOrigin:@"https://fixture.test" completion:^(NSDictionary* scoped) {
      Print(@"SCOPE", scoped); if (![scoped[@"op"] isEqual:@"table_scoped"]) return;
      if (!reopen) StageFixture(connection);
      else [connection listWithCompletion:^(NSDictionary* listed) {
        Print(@"LIST", listed); if (![listed[@"commit_ids"] count]) return;
        [connection readCommit:listed[@"commit_ids"][0] completion:^(NSDictionary* read) { Print(@"READ", read); Finish(connection); }];
      }];
    }];
    else Print(@"STATUS", reply);
  }];
}
int main(int argc, char** argv) {
  @autoreleasepool {
    if (argc != 5) return 64;
    id activity = [NSProcessInfo.processInfo beginActivityWithOptions:
        NSActivityUserInitiated | NSActivityLatencyCritical reason:@"Table connection direct oracle"];
    NSString* mode = @(argv[4]);
    BSTableConnection* connection = [[BSTableConnection alloc]
        initWithExecutableURL:[NSURL fileURLWithPath:@(argv[1])]
        databaseURL:[NSURL fileURLWithPath:@(argv[2])]
        clockProbeURL:[NSURL fileURLWithPath:@(argv[3])]
        ownedOrigin:@"https://fixture.test"];
    if ([mode isEqual:@"sigchld"]) signal(SIGCHLD, SIG_IGN);
    connection.pauseAtStartForTesting = [mode isEqual:@"pause"];
    connection.disconnectHandler = ^{ puts("DISCONNECTED"); fflush(stdout); };
    [connection startWithCompletion:^(NSDictionary* reply) {
      Print(@"INIT", reply);
      // The child's inherited disposition has already been captured at spawn.
      // Restore the parent's sole-reap precondition before any child exit.
      if ([mode isEqual:@"sigchld"]) signal(SIGCHLD, SIG_DFL);
      if (![reply[@"op"] isEqual:@"initialized"]) return;
      if ([mode isEqual:@"rust"] || [mode isEqual:@"reopen"]) Ready(connection, [mode isEqual:@"reopen"]);
      if ([mode isEqual:@"normal"]) [connection pingWithCompletion:^(NSDictionary* pong) { Print(@"PING", pong); }];
      if ([mode isEqual:@"review"] || [mode isEqual:@"parallel"] || [mode isEqual:@"stale"] || [mode isEqual:@"busy_ui"]) {
        if ([mode isEqual:@"busy_ui"]) {
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            puts("UI_BUSY"); fflush(stdout); usleep(1200000); puts("UI_RESUMED"); fflush(stdout);
          });
        }
        [connection reviewStaging:@"stage-1" retentionMs:1000 completion:^(NSDictionary* reviewed) {
          Print(@"REVIEW", reviewed);
          if ([mode isEqual:@"review"] && [reviewed[@"op"] isEqual:@"table_reviewed"])
            [connection approveReview:reviewed[@"review"] publicationGuard:reviewed[@"publication_guard"] completion:^(NSDictionary* approved) {
              Print(@"APPROVE", approved);
              [connection closeWithCompletion:^(NSDictionary* closed) {
                Print(@"CLOSE", closed);
                [connection shutdownWithCompletion:^(NSDictionary* stopped) { Print(@"SHUTDOWN", stopped); }];
              }];
            }];
        }];
        if ([mode isEqual:@"parallel"]) {
          [connection stopAllWithCompletion:^(NSDictionary* stop) { Print(@"STOP", stop); }];
          [connection readCommit:@"blocked-third" completion:^(NSDictionary* refused) { Print(@"BUSY", refused); }];
          [connection stopAllWithCompletion:^(NSDictionary* refused) { Print(@"BUSY_STOP", refused); }];
        }
      }
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      puts("HEARTBEAT"); fflush(stdout);
      if ([mode isEqual:@"invalidate"]) { [connection invalidate]; puts("INVALIDATED"); fflush(stdout); }
    });
    const int64_t traceLimit = ([mode isEqual:@"rust"] || [mode isEqual:@"reopen"]) ? 7000 : 2600;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, traceLimit * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      puts("HEARTBEAT_LATE"); fflush(stdout);
      printf("CONNECTED %d\n", connection.connected); fflush(stdout);
      [connection invalidate]; CFRunLoopStop(CFRunLoopGetCurrent());
    });
    CFRunLoopRun();
    [connection waitForTermination];
    printf("CHILD_PID %d\n", connection.childPid); fflush(stdout);
    puts("JOINED"); fflush(stdout);
    [NSProcessInfo.processInfo endActivity:activity];
    return 0;
  }
}
