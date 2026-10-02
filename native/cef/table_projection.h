#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Fixed owned-fixture schema; copies native evidence, never drives the page.
NSDictionary* _Nullable BSFixtureTableBatch(NSDictionary* observation,
    NSString* expectedRun, NSString* expectedOrigin);
NS_ASSUME_NONNULL_END
