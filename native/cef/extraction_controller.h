#import <Foundation/Foundation.h>
@class BSBlackbirdConnection;

NS_ASSUME_NONNULL_BEGIN
@interface OXExtractionController : NSObject
@property(nonatomic, readonly) BOOL busy;
@property(nonatomic, copy, nullable) void (^stateChanged)(void);
@property(nonatomic, copy, nullable) void (^finished)(void);
- (instancetype)initWithDataURL:(NSURL*)directory connection:(BSBlackbirdConnection*)connection result:(NSMutableDictionary*)result;
- (void)beginVisitWithURL:(NSString*)url title:(NSString*)title;
- (void)addReading:(NSDictionary*)reference;
- (void)readingFailed:(NSString*)message;
- (void)extract:(NSString*)objective;
- (BOOL)receiveEvent:(NSDictionary*)event;
- (void)showPreview;
- (void)stop;
- (void)closeWithCompletion:(void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
