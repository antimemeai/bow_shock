#import <Foundation/Foundation.h>
#import "table_projection.h"
#include <cstdio>

int main() {
  @autoreleasepool {
    NSData* bytes = [NSFileHandle.fileHandleWithStandardInput readDataToEndOfFile];
    NSDictionary* record = [NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil];
    NSDictionary* batch = BSFixtureTableBatch(record, @"native-table-run", @"http://127.0.0.1:8123");
    NSData* output = [NSJSONSerialization dataWithJSONObject:batch ?: @{@"error": @"unavailable"}
        options:NSJSONWritingSortedKeys error:nil];
    if (!output || fwrite(output.bytes, 1, output.length, stdout) != output.length) return 1;
    fputc('\n', stdout);
  }
  return 0;
}
