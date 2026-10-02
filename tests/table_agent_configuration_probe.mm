#import <Foundation/Foundation.h>
#import "table_connection.h"
#import <CoreFoundation/CoreFoundation.h>

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    if (argc != 10) return 2;
    NSURL* (^url)(int) = ^NSURL*(int index) {
      return [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[index]]];
    };
    BOOL ordinary = strcmp(argv[9], "ordinary") == 0;
    BOOL invalid = strcmp(argv[9], "invalid") == 0;
    BSAgentConfiguration* agent = ordinary ? nil :
        [[BSAgentConfiguration alloc] initWithExecutableURL:invalid ? [NSURL URLWithString:@"https://codex.invalid/"] : url(4)
            workingDirectoryURL:url(5) userHomeURL:url(6) codexHomeURL:url(7) model:@"fixture-model"
            expectedAccountID:strcmp(argv[9], "configured") == 0 ? @"fixture-account" : nil];
    BSTableConnection* table = ordinary ?
        [[BSTableConnection alloc] initWithExecutableURL:url(1) databaseURL:url(2)
            clockProbeURL:url(3) ownedOrigin:@"https://fixture.test"] :
        [[BSTableConnection alloc] initWithExecutableURL:url(1) databaseURL:url(2)
            clockProbeURL:url(3) ownedOrigin:@"https://fixture.test" agentConfiguration:agent];
    __block BOOL passed = NO, finished = NO;
    [table startWithCompletion:^(NSDictionary* initial) {
      if (![initial[@"op"] isEqual:@"initialized"]) { finished = YES; CFRunLoopStop(CFRunLoopGetMain()); return; }
      [table pingWithCompletion:^(NSDictionary* ping) {
        if (![ping[@"op"] isEqual:@"pong"]) { CFRunLoopStop(CFRunLoopGetMain()); return; }
        [table shutdownWithCompletion:^(NSDictionary* reply) {
          passed = [reply[@"op"] isEqual:@"shutdown"]; CFRunLoopStop(CFRunLoopGetMain());
        }];
      }];
    }];
    if (!finished) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 6, false);
    [table waitForTermination];
    return passed ? 0 : 1;
  }
}
