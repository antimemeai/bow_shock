#import "continuous_clock.h"
#include <mach/mach_time.h>
#include <sys/sysctl.h>
#include <limits>

NSDictionary* BSContinuousClockWitness(void) {
  static NSString* bootId = []() -> NSString* {
    char bytes[128] = {};
    size_t length = sizeof(bytes);
    if (sysctlbyname("kern.bootsessionuuid", bytes, &length, nullptr, 0) != 0 ||
        length == 0 || length > sizeof(bytes) || bytes[length - 1] != '\0') return nil;
    NSString* text = [NSString stringWithUTF8String:bytes];
    NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:text];
    return uuid.UUIDString;
  }();
  if (!bootId) return nil;
  mach_timebase_info_data_t scale;
  if (mach_timebase_info(&scale) != KERN_SUCCESS || !scale.numer || !scale.denom) return nil;
  const __uint128_t nanoseconds = static_cast<__uint128_t>(mach_continuous_time()) *
      scale.numer / scale.denom;
  if (nanoseconds > std::numeric_limits<uint64_t>::max()) return nil;
  return @{@"boot_id": bootId, @"continuous_ns": @(static_cast<uint64_t>(nanoseconds))};
}
