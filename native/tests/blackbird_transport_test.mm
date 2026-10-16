#import "../cef/blackbird_connection.h"
#import "../cef/blackbird_packet.h"
#include <cerrno>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <initializer_list>
#include <unistd.h>

static void Check(bool condition, const char* problem) {
  if (!condition) { fprintf(stderr, "FAIL: %s\n", problem); exit(1); }
}
static NSData* Data(std::initializer_list<uint8_t> bytes) {
  return [NSData dataWithBytes:bytes.begin() length:bytes.size()];
}
static void PacketChecks() {
  Check([BSBlackbirdEncodePacket(@300, nullptr) isEqual:Data({'B','B','M',2,3,0xac,2})], "unsigned wire vector");
  Check([BSBlackbirdEncodePacket(@(-1), nullptr) isEqual:Data({'B','B','M',2,4,1})], "negative wire vector");
  Check([BSBlackbirdEncodePacket(@YES, nullptr) isEqual:Data({'B','B','M',2,2})], "boolean wire vector");
  Check([BSBlackbirdDecodePacket(Data({'B','B','M',2,8,64}), nullptr) isEqual:@"result_record"], "last word ID");
  Check([BSBlackbirdDecodePacket(Data({'B','B','M',2,8,1}), nullptr) isEqual:@"label"], "first word ID");
  Check([BSBlackbirdDecodePacket(Data({'B','B','M',2,11,0,0,0,0,0,0,0xf8,0x3f}), nullptr) isEqual:@1.5], "little-endian real");
  NSMutableData* identity = [Data({'B','B','M',2,7}) mutableCopy];
  for (uint8_t i = 0; i < 16; ++i) [identity appendBytes:&i length:1];
  Check([BSBlackbirdDecodePacket(identity, nullptr) isEqual:@"000102030405060708090a0b0c0d0e0f"], "identity wire vector");
  NSDictionary* native = @{@"url": @"https://example.org/é", @"truncated": @NO,
    @"timestamp": @(UINT64_MAX), @"minimum": @(INT64_MIN), @"rows": @[@1, NSNull.null, @1.5]};
  NSData* encoded = BSBlackbirdEncodePacket(native, nullptr);
  Check([BSBlackbirdDecodePacket(encoded, nullptr) isEqual:native], "native scalar/container values");
  for (NSUInteger cut = 0; cut < encoded.length; ++cut)
    Check(!BSBlackbirdDecodePacket([encoded subdataWithRange:NSMakeRange(0, cut)], nullptr), "every truncated prefix fails");
  for (NSData* invalid in @[
    Data({'B','B','M',1,0}), Data({'B','B','M',2,8,0}), Data({'B','B','M',2,8,65}),
    Data({'B','B','M',2,3,0x80,0}), Data({'B','B','M',2,4,0}),
    Data({'B','B','M',2,6,1,0xff}), Data({'B','B','M',2,5}), Data({'B','B','M',2,0,0}),
    Data({'B','B','M',2,10,2,6,1,'a',0,6,1,'a',0}),
    Data({'B','B','M',2,3,255,255,255,255,255,255,255,255,255,2})])
    Check(!BSBlackbirdDecodePacket(invalid, nullptr), "malformed wire rejected");
  Check(!BSBlackbirdEncodePacket(@(INFINITY), nullptr), "infinite real rejected");
  Check(!BSBlackbirdEncodePacket([NSDecimalNumber decimalNumberWithString:@"1.1"], nullptr), "decimal outside schema rejected");
  Check(!BSBlackbirdEncodePacket(@{@1: @"bad"}, nullptr), "nontext key rejected");
  NSString* boundary = [@"" stringByPaddingToLength:BSBlackbirdMaximumPacketBytes - 9 withString:@"x" startingAtIndex:0];
  Check(BSBlackbirdEncodePacket(boundary, nullptr).length == BSBlackbirdMaximumPacketBytes, "exact packet byte limit");
  Check(!BSBlackbirdEncodePacket([boundary stringByAppendingString:@"x"], nullptr), "encoding byte limit enforced");
  Check(!BSBlackbirdDecodePacket([NSMutableData dataWithLength:BSBlackbirdMaximumPacketBytes + 1], nullptr), "decoding byte limit enforced");
  NSMutableArray* deep = [NSMutableArray array]; NSMutableArray* cursor = deep;
  for (unsigned i = 0; i < 66; ++i) { NSMutableArray* next = [NSMutableArray array]; [cursor addObject:next]; cursor = next; }
  Check(!BSBlackbirdEncodePacket(deep, nullptr), "depth bounded");
}
static bool ReadAll(int fd, void* bytes, size_t length) {
  size_t at = 0;
  while (at < length) { ssize_t n = read(fd, static_cast<char*>(bytes) + at, length - at); if (n < 0 && errno == EINTR) continue; if (n <= 0) return false; at += n; }
  return true;
}
static void WriteAll(NSData* bytes, bool split = false) {
  NSUInteger at = 0;
  while (at < bytes.length) {
    ssize_t n = write(STDOUT_FILENO, static_cast<const char*>(bytes.bytes) + at, split ? 1 : bytes.length - at);
    if (n < 0 && errno == EINTR) continue; Check(n > 0, "child write"); at += n;
    if (split) usleep(200);
  }
}
static NSDictionary* Receive() {
  uint8_t prefix[4]; Check(ReadAll(STDIN_FILENO, prefix, 4), "child frame prefix");
  uint32_t length = (uint32_t(prefix[0]) << 24) | (uint32_t(prefix[1]) << 16) | (uint32_t(prefix[2]) << 8) | prefix[3];
  Check(length <= BSBlackbirdMaximumPacketBytes, "child frame bounded");
  NSMutableData* data = [NSMutableData dataWithLength:length]; Check(ReadAll(STDIN_FILENO, data.mutableBytes, length), "child frame payload");
  NSDictionary* value = BSBlackbirdDecodePacket(data, nullptr); Check([value isKindOfClass:NSDictionary.class], "child command map"); return value;
}
static void Send(NSDictionary* event, bool split = false) {
  NSData* data = BSBlackbirdEncodePacket(event, nullptr); uint32_t n = static_cast<uint32_t>(data.length);
  uint8_t prefix[] = {uint8_t(n >> 24), uint8_t(n >> 16), uint8_t(n >> 8), uint8_t(n)};
  NSMutableData* frame = [NSMutableData dataWithBytes:prefix length:4]; [frame appendData:data]; WriteAll(frame, split);
}
static void Child(NSString* test) {
  NSDictionary* open = Receive();
  Check([open[@"type"] isEqual:@"open"] && [open[@"model"] isEqual:@"test-model"] && [open[@"effort"] isEqual:@"high"], "open command contract");
  Check([open[@"session"] isEqual:@"/tmp/oxcart-blackbird-test-session"], "absolute session path");
  Check([[NSFileManager.defaultManager currentDirectoryPath] isEqual:@"/tmp"] || [[NSFileManager.defaultManager currentDirectoryPath] isEqual:@"/private/tmp"], "child working directory");
  Send(@{@"type": @"ready", @"id": open[@"id"], @"protocol": @1, @"model": @"test-model", @"session": open[@"session"]}, true);
  Send(@{@"type": @"status", @"id": open[@"id"], @"pid": @(getpid())});
  if ([test isEqual:@"overflow"]) { for (unsigned i = 0; i < 300; ++i) Send(@{@"type": @"status", @"id": open[@"id"], @"text": @"flood"}); pause(); exit(2); }
  if ([test isEqual:@"malformed"]) { WriteAll(Data({0,0,0,5,'B','A','D',2,0})); pause(); exit(2); }
  if ([test isEqual:@"oversize"]) { WriteAll(Data({0,64,0,1})); pause(); exit(2); }
  if ([test isEqual:@"truncated"]) { WriteAll(Data({0,0,0,8,'B','B'})); exit(0); }
  if ([test isEqual:@"stubborn"]) { signal(SIGTERM, SIG_IGN); while (true) pause(); }
  NSDictionary* turn = Receive();
  Check([turn[@"type"] isEqual:@"turn"] && [turn[@"objective"] isEqual:@"read live page"], "turn objective");
  Check([turn[@"observations"][0][@"capture_end_ns"] unsignedLongLongValue] == UINT64_MAX, "observation uint64 unchanged");
  if ([test isEqual:@"error-final"]) {
    Send(@{@"type":@"error",@"id":turn[@"id"],@"message":@"invalid_range",@"final_follows":@YES});
    NSDictionary* cancel = Receive(); Check([cancel[@"type"] isEqual:@"cancel"] && [cancel[@"id"] isEqual:turn[@"id"]],"failed admitted turn retains request ownership until final");
    Send(@{@"type":@"final",@"id":turn[@"id"],@"outcome":@"failed",@"text":@"Retained failed response"});
    NSDictionary* close = Receive(); Check([close[@"type"] isEqual:@"close"],"failed turn closes after final");
    Send(@{@"type":@"closed",@"id":close[@"id"]}); exit(0);
  }
  Send(@{@"type": @"text", @"id": turn[@"id"], @"text": @"hello"}, true);
  BOOL cancelledPending = [test isEqual:@"steer-cancel-pending"];
  if ([test hasPrefix:@"steer"]) {
    NSDictionary* replacement = Receive();
    Check([replacement[@"type"] isEqual:@"steer"] && ![replacement[@"id"] isEqual:turn[@"id"]], "steer has fresh ID");
    if ([test isEqual:@"steer-rejected"]) {
      Send(@{@"type": @"error", @"id": replacement[@"id"], @"message": @"busy"});
    } else {
      if (cancelledPending) { NSDictionary* cancel = Receive(); Check([cancel[@"type"] isEqual:@"cancel"] && [cancel[@"id"] isEqual:replacement[@"id"]], "cancel pending steer ID"); }
      Send(@{@"type": @"final", @"id": turn[@"id"], @"outcome": @"cancelled", @"text": @"hello"});
      turn = replacement;
      if (!cancelledPending) Send(@{@"type": @"text", @"id": turn[@"id"], @"text": @"hello"});
    }
  }
  if (!cancelledPending) { NSDictionary* cancel = Receive(); Check([cancel[@"type"] isEqual:@"cancel"] && [cancel[@"id"] isEqual:turn[@"id"]], "cancel active ID"); }
  Send(@{@"type": @"final", @"id": turn[@"id"], @"outcome": @"cancelled", @"text": cancelledPending ? @"" : @"hello"});
  NSDictionary* close = Receive(); Check([close[@"type"] isEqual:@"close"], "close command");
  Send(@{@"type": @"closed", @"id": close[@"id"]}, true);
}
static void ConnectionCheck(NSString* executable, NSString* test) {
  setenv("OXCART_TRANSPORT_TEST", test.UTF8String, 1);
  NSURL* executableURL = [NSURL fileURLWithPath:[test isEqual:@"missing"] ? @"/no/such/blackbird" : executable];
  BSBlackbirdConnection* connection = [[BSBlackbirdConnection alloc] initWithExecutableURL:executableURL
    sessionURL:[NSURL fileURLWithPath:@"/tmp/oxcart-blackbird-test-session"] workingDirectoryURL:[NSURL fileURLWithPath:@"/tmp"] model:@"test-model"];
  __block BOOL done = NO, final = NO, steered = NO; __block NSString* activeID = nil; __block NSUInteger errors = 0, closed = 0; __block pid_t pid = -1;
  __weak BSBlackbirdConnection* weakConnection = connection;
  connection.eventHandler = ^(NSDictionary* event) {
    BSBlackbirdConnection* connection = weakConnection;
    Check(NSThread.isMainThread, "callback main thread");
    if ([event[@"type"] isEqual:@"ready"]) {
      if ([test isEqual:@"success"] || [test hasPrefix:@"steer"] || [test isEqual:@"stubborn"] || [test isEqual:@"error-final"]) Check(connection.ready, "ready state before callback");
      if ([test isEqual:@"stubborn"]) [connection closeWithCompletion:^{ done = YES; }];
      else if ([test isEqual:@"success"] || [test hasPrefix:@"steer"] || [test isEqual:@"error-final"]) {
        activeID = [connection sendObjective:@"read live page" observations:@[@{@"capture_end_ns": @(UINT64_MAX)}] steer:NO];
        Check(activeID != nil && [connection.activeRequestID isEqual:activeID], "turn accepted and visible");
        Check([connection sendObjective:@"second" observations:@[] steer:NO] == nil, "busy turn rejected");
      }
    }
    if ([event[@"type"] isEqual:@"status"]) pid = [event[@"pid"] intValue];
    if ([event[@"type"] isEqual:@"text"]) {
      Check([event[@"text"] isEqual:@"hello"], "text preserved");
      if ([test hasPrefix:@"steer"] && !steered) {
        steered = YES;
        NSString* replacement = [connection sendObjective:@"replacement" observations:@[] steer:YES];
        Check(replacement != nil && ![replacement isEqual:activeID], "fresh steer ID returned");
        Check([connection sendObjective:@"too soon" observations:@[] steer:YES] == nil, "second pending steer rejected locally");
        if (![test isEqual:@"steer-rejected"]) activeID = replacement;
        if ([test isEqual:@"steer-cancel-pending"]) [connection cancel];
      } else { [connection cancel]; [connection cancel]; }
    }
    if ([event[@"type"] isEqual:@"final"]) {
      NSString* expected = [test isEqual:@"error-final"] ? @"Retained failed response" : [test isEqual:@"steer-cancel-pending"] && [event[@"id"] isEqual:activeID] ? @"" : @"hello";
      Check([event[@"text"] isEqual:expected] && [event[@"outcome"] isEqual:([test isEqual:@"error-final"] ? @"failed" : @"cancelled")], "final outcome preserved");
      if ([event[@"id"] isEqual:activeID]) { final = YES; [connection closeWithCompletion:^{ done = YES; }]; }
      else if (![test isEqual:@"steer-cancel-pending"]) Check(connection.running, "old final leaves replacement active");
    }
    if ([event[@"type"] isEqual:@"error"]) {
      ++errors;
      if ([test isEqual:@"steer-rejected"]) { Check(connection.running && [connection.activeRequestID isEqual:activeID], "rejected steer restores old active task"); [connection cancel]; }
      if ([test isEqual:@"error-final"]) { Check(connection.running && [connection.activeRequestID isEqual:activeID],"error before final does not release admitted request"); [connection cancel]; }
    }
    if ([event[@"type"] isEqual:@"closed"]) { ++closed; if (![test isEqual:@"success"] && ![test hasPrefix:@"steer"] && ![test isEqual:@"stubborn"] && ![test isEqual:@"error-final"]) done = YES; }
  };
  [connection start];
  if ([test isEqual:@"overflow"]) usleep(300000); // Deliberately stop the main consumer.
  NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:6];
  while (!done && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
  Check(done, "connection completes before deadline");
  Check(!connection.running && !connection.ready, "terminal state");
  Check(closed == 1, "one closed event");
  Check(errors == (([test isEqual:@"success"] || [test isEqual:@"steer"] || [test isEqual:@"steer-cancel-pending"] || [test isEqual:@"stubborn"]) ? 0 : 1), "error count");
  if ([test isEqual:@"success"] || [test hasPrefix:@"steer"] || [test isEqual:@"error-final"]) Check(final, "completed cancellation/failure final");
  if (pid > 0) { errno = 0; Check(kill(pid, 0) < 0 && errno == ESRCH, "child reaped before completion"); }
  [connection closeWithCompletion:nil]; connection.eventHandler = nil;
}
int main(int argc, char** argv) {
  @autoreleasepool {
    if (argc == 2 && strcmp(argv[1], "--application") == 0) { Child([NSString stringWithUTF8String:getenv("OXCART_TRANSPORT_TEST")]); return 0; }
    PacketChecks();
    NSString* executable = [NSString stringWithUTF8String:argv[0]];
    for (NSString* test in @[@"success", @"steer", @"steer-cancel-pending", @"steer-rejected", @"error-final", @"malformed", @"oversize", @"truncated", @"overflow", @"stubborn", @"missing"]) ConnectionCheck(executable, test);
    puts("Blackbird packet and process transport checks passed");
  }
}
