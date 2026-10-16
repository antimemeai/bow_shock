#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSAttributedString* OXRenderExtractionDocument(NSDictionary* document, NSArray* _Nullable* _Nullable sources);
@interface OXExtractionPreview : NSObject <NSTextViewDelegate>
@property(nonatomic, copy, nullable) void (^actionHandler)(NSString* action, NSDictionary* fields);
- (NSDictionary<NSString*,NSData*>*)presentAttempt:(NSDictionary*)attempt
    document:(nullable NSDictionary*)document failure:(nullable NSString*)failure;
- (void)setWorking:(BOOL)working message:(NSString*)message;
- (void)setRecipes:(NSArray<NSDictionary*>*)recipes selectedID:(nullable NSString*)identity;
- (void)showSource:(NSString*)text title:(NSString*)title selection:(NSRange)selection;
- (void)show;
- (void)close;
@end
NS_ASSUME_NONNULL_END
