#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "control_connection.h"
#include <atomic>
#include <memory>
#include <cstdio>
#include <fcntl.h>
#include <signal.h>
#include <unistd.h>

int main(int argc, char** argv) {
  @autoreleasepool {
    if (argc != 3) return 2;
    id activity = [NSProcessInfo.processInfo beginActivityWithOptions:
        NSActivityUserInitiated | NSActivityLatencyCritical reason:@"Control connection oracle"];
    NSString* mode = @(argv[2]);
    int extra = open("/dev/null", O_RDONLY); // Deliberately not CLOEXEC; child must not inherit it.
    if (extra >= 0 && extra < 3) {
      int moved = fcntl(extra, F_DUPFD_CLOEXEC, 3); close(extra); extra = moved;
      if (extra >= 0) fcntl(extra, F_SETFD, 0);
    }
    auto alive = std::make_shared<std::atomic_bool>(true);
    auto presented = std::make_shared<std::atomic_bool>(false);
    BSControlConnection* link = [[BSControlConnection alloc]
        initWithExecutableURL:[mode isEqual:@"bad_url"] ? [NSURL URLWithString:@"https://invalid.test"] :
            [NSURL fileURLWithPath:@(argv[1])]
        runId:[mode isEqual:@"bad_run"] ? @"bad\nrun" : @"owned-control-run"
        authorityAliveProvider:^{ return alive->load(); }];
    __weak BSControlConnection* weakLink = link;
    link.disconnectHandler = ^{
      BSControlConnection* current = weakLink;
      printf("DISCONNECTED\nREASON %s\n", current.failureReason.UTF8String); fflush(stdout);
    };
    if ([mode isEqual:@"delay_start"]) usleep(2100000);
    [link startWithCompletion:^(NSDictionary* reply) {
      printf("INIT %s PID %d\n", reply ? "ok" : "nil", link.childPid); fflush(stdout);
      if (reply) presented->store(true);
      if (reply && [mode isEqual:@"fault"]) {
        NSString* releasePath = [[@(argv[1]) stringByDeletingPathExtension] stringByAppendingString:@".release"];
        int release = open(releasePath.fileSystemRepresentation, O_WRONLY | O_CREAT | O_TRUNC, 0600);
        if (release >= 0) { (void)write(release, "released", 8); close(release); }
      }
      if (!reply) { printf("INIT_REASON %s\n", link.failureReason.UTF8String); fflush(stdout); }
      if (reply && [mode isEqual:@"pause_self"]) raise(SIGSTOP);
      if (!reply) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
          [link waitForTermination]; printf("REAPED\nCHILD_EXIT %ld REASON %s\n",
              (long)link.childExitCode, link.failureReason.UTF8String); fflush(stdout);
          dispatch_async(dispatch_get_main_queue(), ^{ CFRunLoopStop(CFRunLoopGetMain()); });
        });
      }
      if (reply && [mode isEqual:@"stall_main"]) {
        puts("MAIN_STALLED"); fflush(stdout); usleep(1200000);
        puts("MAIN_RESUMED"); fflush(stdout);
      }
    }];
    if ([mode isEqual:@"invalidate"]) {
      NSString* readyPath = [[@(argv[1]) stringByDeletingPathExtension] stringByAppendingString:@".ready"];
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (int i = 0; i < 150 && access(readyPath.fileSystemRepresentation, F_OK) != 0; ++i) usleep(10000);
        if (access(readyPath.fileSystemRepresentation, F_OK) != 0) { puts("READY_MISSING"); fflush(stdout); }
        dispatch_async(dispatch_get_main_queue(), ^{
          CFAbsoluteTime before = CFAbsoluteTimeGetCurrent(); [link invalidate];
          printf("INVALIDATE_SECONDS %.6f\n", CFAbsoluteTimeGetCurrent() - before); fflush(stdout);
        });
      });
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      // Exercise live supervision after the actual native initialization ACK,
      // rather than revoking authority while the helper is still cold-starting.
      if (![mode isEqual:@"delay_start"]) {
        for (int i = 0; i < 220; ++i) {
          if ([mode isEqual:@"late_main"] ? link.connected : presented->load()) break;
          usleep(10000);
        }
      }
      usleep(350000);
      if ([mode isEqual:@"normal"] || [mode isEqual:@"stall_main"]) {
        printf("LIVE %d\n", link.connected); fflush(stdout);
        [link fenceToGeneration:7 completion:^(NSDictionary* reply) {
          printf("FENCE %s %llu\n", reply ? "ok" : "nil",
              [reply[@"stop_generation"] unsignedLongLongValue]); fflush(stdout);
        }];
        if ([mode isEqual:@"stall_main"]) {
          [link fenceToGeneration:8 completion:^(NSDictionary* reply) {
            printf("BUSY %s\n", reply ? "ok" : "nil"); fflush(stdout);
          }];
        }
        for (int i = 0; i < 30 && link.acknowledgedGeneration != 7; ++i) usleep(10000);
        printf("WORKER_FENCE %llu LIVE %d\n", link.acknowledgedGeneration, link.connected); fflush(stdout);
        if ([mode isEqual:@"stall_main"]) {
          [link fenceToGeneration:9 completion:^(NSDictionary* reply) {
            printf("BACKLOG %s\n", reply ? "ok" : "nil"); fflush(stdout);
          }];
        }
        [link fenceToGeneration:0 completion:^(NSDictionary* reply) {
          printf("STALE %s\n", reply ? "ok" : "nil"); fflush(stdout);
        }];
        if ([mode isEqual:@"normal"]) usleep(100000);
      }
      if (![mode isEqual:@"delay_start"]) {
        alive->store(false);
        for (int i = 0; i < 40 && link.connected; ++i) usleep(10000);
        printf("AUTHORITY_LOST LIVE %d PID %d\n", link.connected, link.childPid); fflush(stdout);
        [link waitForTermination]; printf("REAPED\nCHILD_EXIT %ld REASON %s\n",
            (long)link.childExitCode, link.failureReason.UTF8String); fflush(stdout);
        dispatch_async(dispatch_get_main_queue(), ^{ CFRunLoopStop(CFRunLoopGetMain()); });
      }
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      [link invalidate]; [link waitForTermination]; puts("GUARD"); fflush(stdout);
      dispatch_async(dispatch_get_main_queue(), ^{ CFRunLoopStop(CFRunLoopGetMain()); });
    });
    if ([mode isEqual:@"late_main"]) usleep(1000000);
    CFRunLoopRun(); [link waitForTermination];
    if (extra >= 0) close(extra);
    [NSProcessInfo.processInfo endActivity:activity];
    return 0;
  }
}
