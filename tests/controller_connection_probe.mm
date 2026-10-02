#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "controller_connection.h"
#include <stdio.h>

int main(int argc, char** argv) {
  @autoreleasepool {
    // This command-line .app has no visible window. Keep its test UI timers
    // active instead of allowing App Nap to coalesce the supervisory heartbeat.
    id activity = [NSProcessInfo.processInfo beginActivityWithOptions:
        NSActivityUserInitiated | NSActivityLatencyCritical reason:@"Native connection oracle"];
    NSString* mode = argc > 1 ? @(argv[1]) : @"normal";
    BSControllerConnection* link = [[BSControllerConnection alloc] init];
    if ([link respondsToSelector:NSSelectorFromString(@"setDisconnectHandler:")]) {
      [link setValue:^{ puts("DISCONNECTED"); fflush(stdout); } forKey:@"disconnectHandler"];
    }
    [link startWithCompletion:^(NSDictionary* reply) {
      printf("INIT %s\n", reply ? "ok" : "nil"); fflush(stdout);
      printf("CHILD_PID %d\n", link.childPid); fflush(stdout);
      if ([mode isEqual:@"trace"] && reply) {
        [link sendOperation:@"ping" completion:^(NSDictionary* ping) {
          printf("PING %s\n", ping ? "ok" : "nil"); fflush(stdout);
          [link sendOperation:@"stop_all" completion:^(NSDictionary* stop) {
            printf("STOP %s\n", stop ? "ok" : "nil"); fflush(stdout);
            [link sendOperation:@"shutdown" completion:^(NSDictionary* shutdown) {
              printf("SHUTDOWN %s\n", shutdown ? "ok" : "nil"); fflush(stdout);
            }];
          }];
        }];
      }
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      puts("HEARTBEAT"); fflush(stdout);
      if ([mode isEqual:@"invalidate"] || [mode isEqual:@"join"]) {
        CFAbsoluteTime before = CFAbsoluteTimeGetCurrent();
        [link invalidate];
        printf("INVALIDATED %.6f\n", CFAbsoluteTimeGetCurrent() - before); fflush(stdout);
        if ([mode isEqual:@"join"]) CFRunLoopStop(CFRunLoopGetCurrent());
      }
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      puts("HEARTBEAT_LATE"); fflush(stdout);
      [link invalidate];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3800 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      puts("DONE"); fflush(stdout); exit(0);
    });
    CFRunLoopRun();
    [link waitForTermination];
    printf("CHILD_PID %d\n", link.childPid); fflush(stdout);
    puts("JOINED"); fflush(stdout);
    [NSProcessInfo.processInfo endActivity:activity];
  }
}
