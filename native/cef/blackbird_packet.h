#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Native Foundation values, encoded as Blackbird BBM2 (without stream length).
/// Supports strings, dictionaries with string keys, arrays, finite numbers, null.
FOUNDATION_EXPORT NSData* _Nullable BSBlackbirdEncodePacket(id value, NSError** error);
FOUNDATION_EXPORT id _Nullable BSBlackbirdDecodePacket(NSData* packet, NSError** error);
FOUNDATION_EXPORT const NSUInteger BSBlackbirdMaximumPacketBytes;
NS_ASSUME_NONNULL_END
