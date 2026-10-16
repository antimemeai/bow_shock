#import <Cocoa/Cocoa.h>
NS_ASSUME_NONNULL_BEGIN
/// Snapshot before AppKit dispatch; nil for event types this recorder does not cover.
FOUNDATION_EXPORT NSDictionary* _Nullable OXNativeInputFields(NSEvent* event);
NS_ASSUME_NONNULL_END
