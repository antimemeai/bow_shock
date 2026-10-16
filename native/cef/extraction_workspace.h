#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// All methods perform synchronous IO; the controller calls them on one serial worker.
@interface OXExtractionWorkspace : NSObject
@property(nonatomic, readonly) NSURL* rootURL;
- (instancetype)initWithRootURL:(NSURL*)root;
- (nullable NSDictionary*)createVisitWithURL:(NSString*)url title:(NSString*)title error:(NSError**)error;
- (BOOL)record:(NSString*)kind fields:(NSDictionary*)fields error:(NSError**)error;
- (nullable NSDictionary*)createAttemptForVisit:(NSDictionary*)visit readings:(NSArray*)readings
    objective:(NSString*)objective recipe:(nullable NSDictionary*)recipe phase:(NSString*)phase
    predecessor:(nullable NSDictionary*)predecessor feedback:(NSString*)feedback error:(NSError**)error;
- (nullable NSDictionary*)receiveResultForAttempt:(NSDictionary*)attempt response:(NSString*)response
    outcome:(NSString*)outcome error:(NSError**)error;
- (BOOL)savePreview:(NSDictionary<NSString*, NSData*>*)files forAttempt:(NSDictionary*)attempt error:(NSError**)error;
- (nullable NSDictionary*)saveRecipe:(NSDictionary*)candidate attempt:(NSDictionary*)attempt error:(NSError**)error;
- (nullable NSArray<NSDictionary*>*)recipes:(NSError**)error;
@end

FOUNDATION_EXPORT NSString* OXExtractionFormatGuide(void);
FOUNDATION_EXPORT BOOL OXValidateExtraction(NSDictionary* document, NSDictionary* manifests, NSError** error);
FOUNDATION_EXPORT BOOL OXWriteArtifact(NSData* bytes, NSURL* destination, NSError** error);
NS_ASSUME_NONNULL_END
