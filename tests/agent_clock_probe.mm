// Owned fixture: actual native witness, optionally delayed after sampling.
#import "continuous_clock.h"
#include <cstdio>
#include <unistd.h>

int main(int argc, char** argv) {
  @autoreleasepool {
    if (argc != 1) return 1;
    NSDictionary* witness = BSContinuousClockWitness();
    if (!witness) return 1;
    NSString* marker = [[NSString stringWithUTF8String:argv[0]] stringByAppendingString:@".delay"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:marker]) usleep(250000);
    NSData* encoded = [NSJSONSerialization dataWithJSONObject:witness options:0 error:nil];
    if (!encoded || fwrite(encoded.bytes, 1, encoded.length, stdout) != encoded.length ||
        fputc('\n', stdout) == EOF || fflush(stdout) != 0) return 1;
  }
  return 0;
}
