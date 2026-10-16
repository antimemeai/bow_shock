#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// One recording; calls enqueue in order. Chunking never samples or caps events.
@interface OXInputArchive : NSObject
@property(nonatomic, readonly) NSString* recordingID;
@property(nonatomic, readonly) NSURL* directoryURL;
@property(nonatomic, copy, nullable) void (^failed)(NSString* message);
- (instancetype)initWithRootURL:(NSURL*)root metadata:(NSDictionary*)metadata;
- (void)append:(NSString*)kind fields:(NSDictionary*)fields;
- (void)closeWithCompletion:(void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
