#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Complete DOMSnapshot tables plus independently indexed document text views.
/// Large strings are externalized, never shortened. Returns the published directory.
FOUNDATION_EXPORT NSURL* _Nullable BSWriteReading(
    NSURL* root, NSString* captureID, NSDictionary* metadata,
    NSDictionary* snapshot, NSArray<NSDictionary*>* documents, NSError** error);
NS_ASSUME_NONNULL_END
