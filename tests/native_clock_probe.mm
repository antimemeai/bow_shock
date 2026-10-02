#import "continuous_clock.h"
#include <cstdio>

int main() {
  @autoreleasepool {
    NSDictionary* witness = BSContinuousClockWitness();
    if (!witness) return 1;
    NSData* encoded = [NSJSONSerialization dataWithJSONObject:witness options:0 error:nil];
    if (!encoded || fwrite(encoded.bytes, 1, encoded.length, stdout) != encoded.length ||
        fputc('\n', stdout) == EOF || fflush(stdout) != 0) return 1;
  }
  return 0;
}
