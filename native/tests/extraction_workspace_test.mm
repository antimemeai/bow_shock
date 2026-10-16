#import "../cef/extraction_workspace.h"
#import "../cef/extraction_preview.h"
#include <cerrno>
#include <cstdlib>
#include <cstdio>
#include <dlfcn.h>
#include <cstring>

static bool failActivation = false;
extern "C" int link(const char* from, const char* to) {
  if (failActivation && std::strstr(to,"/events/")) { errno = ENOSPC; return -1; }
  using Link = int (*)(const char*,const char*);
  static auto actual = reinterpret_cast<Link>(dlsym(RTLD_NEXT,"link"));
  return actual(from,to);
}

static void Check(bool value, const char* message) {
  if (!value) { fprintf(stderr,"FAIL: %s\n",message); std::exit(1); }
}
int main(int argc, char** argv) { @autoreleasepool {
  NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
  NSURL* root = [NSURL fileURLWithPath:path isDirectory:YES];
  OXExtractionWorkspace* store = [[OXExtractionWorkspace alloc] initWithRootURL:root];
  NSError* error = nil;
  NSDictionary* visit = [store createVisitWithURL:@"https://www.python.org/" title:@"Python" error:&error];
  Check(visit != nil,"create visit");
  NSDictionary* attempt = [store createAttemptForVisit:visit readings:@[] objective:@"Organize page"
      recipe:nil phase:@"initial" predecessor:nil feedback:@"" error:&error];
  Check(attempt != nil,"create attempt");
  NSDictionary* original = @{@"page_type":@"Project home",@"applicability":@"Project landing pages",@"instructions":@"Group project resources"};
  NSDictionary* first = [store saveRecipe:original attempt:attempt error:&error];
  Check(first != nil,"save whole first recipe");
  NSData* firstBytes = [NSData dataWithContentsOfFile:first[@"path"]];
  NSDictionary* revised = @{@"page_type":@"Project home",@"applicability":@"Project landing pages",@"instructions":@"Group resources and include news"};
  NSDictionary* second = [store saveRecipe:revised attempt:attempt error:&error];
  Check(second && ![first[@"id"] isEqual:second[@"id"]],"successor has new identity");
  Check([second[@"predecessor_id"] isEqual:first[@"id"]],"successor links previous active recipe");
  Check([firstBytes isEqual:[NSData dataWithContentsOfFile:first[@"path"]]],"old recipe unchanged");
  store = [[OXExtractionWorkspace alloc] initWithRootURL:root];
  NSArray* recipes = [store recipes:&error];
  Check(recipes.count == 2,"restart retains both recipes");
  Check([recipes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary* recipe, NSDictionary*) {
    return [recipe[@"active"] boolValue] && [recipe[@"id"] isEqual:second[@"id"]];
  }]].count == 1,"restart recovers active successor");
  failActivation = true;
  Check(![store saveRecipe:revised attempt:attempt error:&error],"failed activation is reported");
  failActivation = false;
  recipes = [[[OXExtractionWorkspace alloc] initWithRootURL:root] recipes:&error];
  Check(recipes.count == 3,"failed activation retains complete unactivated successor");
  Check([recipes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary* recipe, NSDictionary*) {
    return [recipe[@"active"] boolValue] && [recipe[@"id"] isEqual:second[@"id"]];
  }]].count == 1,"failed activation keeps previous active choice");
  Check(!OXWriteArtifact([@"overwrite" dataUsingEncoding:NSUTF8StringEncoding],
      [NSURL fileURLWithPath:first[@"path"]],&error),"exclusive writes reject overwrite");
  Check([firstBytes isEqual:[NSData dataWithContentsOfFile:first[@"path"]]],"failed write preserves old bytes");
  NSDictionary* manifests = @{@"capture":@{@"documents":@[@{@"text_bytes":@12}]}};
  NSDictionary* document = @{@"format":@"oxcart.extraction",@"version":@1,@"title":@"Organized",
      @"blocks":@[@{@"kind":@"paragraph",@"text":@"Observed text",@"interpretation":@"observed",
        @"sources":@[@{@"capture_id":@"capture",@"document":@0,@"byte_offset":@0,@"byte_length":@12}]}],
      @"issues":@[],@"assessment":@"ready",@"recipe":original};
  Check(OXValidateExtraction(document,manifests,&error),"valid document with actual source extent");
  NSArray* sourceMap = nil;
  NSAttributedString* rendered = OXRenderExtractionDocument(document,&sourceMap);
  Check([rendered.string containsString:@"Observed text"] && [rendered.string containsString:@"Source 1"],"actual preview renders content and source link");
  Check(sourceMap.count == 1 && [sourceMap[0][@"capture_id"] isEqual:@"capture"],"renderer retains source identity");
  NSMutableDictionary* diverse = [document mutableCopy];
  NSDictionary* citation = @{@"interpretation":@"observed",@"sources":@[@{@"capture_id":@"capture"}]};
  NSMutableArray* blocks = [NSMutableArray array];
  for (NSDictionary* content in @[@{@"kind":@"heading",@"text":@"Section"},
      @{@"kind":@"paragraph",@"text":@"<script>literal 🙂</script>"},
      @{@"kind":@"record",@"fields":@[@{@"label":@"Author",@"value":@"Maya"}]},
      @{@"kind":@"list",@"items":@[@"First",@"Last item"]},
      @{@"kind":@"table",@"columns":@[@"Name",@"Value"],@"rows":@[@[@"Tail",@"Final cell"]]}]) {
    NSMutableDictionary* block = [content mutableCopy];
    if (![block[@"kind"] isEqual:@"heading"]) [block addEntriesFromDictionary:citation];
    [blocks addObject:block];
  }
  diverse[@"blocks"] = blocks;
  Check(OXValidateExtraction(diverse,manifests,&error),"all supported result shapes validate");
  rendered = OXRenderExtractionDocument(diverse,&sourceMap);
  for (NSString* text in @[@"Section",@"<script>literal 🙂</script>",@"Author: Maya",@"Last item",@"Final cell"])
    Check([rendered.string containsString:text],"renderer retains full source-supported content as literal text");
  [NSApplication sharedApplication];
  OXExtractionPreview* preview = [[OXExtractionPreview alloc] init];
  NSDictionary* artifacts = [preview presentAttempt:attempt document:diverse failure:nil];
  Check(artifacts.count == 4,"actual native view exports all renderer artifacts");
  Check([[[NSString alloc] initWithData:artifacts[@"preview.txt"] encoding:NSUTF8StringEncoding] containsString:@"Final cell"],"display export retains table tail");
  NSData* pdf = artifacts[@"preview.pdf"];
  Check(pdf.length >= 5 && memcmp(pdf.bytes,"%PDF-",5) == 0,"native view produces actual PDF");
  if (argc > 1) {
    NSURL* directory = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES];
    for (NSString* name in artifacts) Check(OXWriteArtifact(artifacts[name],[directory URLByAppendingPathComponent:name],&error),"retain native preview artifacts");
  }
  [preview close];
  NSMutableDictionary* invalid = [document mutableCopy];
  invalid[@"blocks"] = @[@{@"kind":@"paragraph",@"text":@"Oops",@"interpretation":@"observed",
      @"sources":@[@{@"capture_id":@"foreign"}]}];
  Check(!OXValidateExtraction(invalid,manifests,&error),"foreign capture rejected");
  invalid[@"blocks"] = @[@{@"kind":@"paragraph",@"text":@"Oops",@"interpretation":@"observed",
      @"sources":@[@{@"capture_id":@"capture",@"document":@0,@"byte_offset":@11,@"byte_length":@2}]}];
  Check(!OXValidateExtraction(invalid,manifests,&error),"out of bounds source rejected");
  NSData* malformed = [@"broken model output" dataUsingEncoding:NSUTF8StringEncoding];
  Check(OXWriteArtifact(malformed,[NSURL fileURLWithPath:attempt[@"result_path"]],&error),"write invalid submission");
  Check(![store receiveResultForAttempt:attempt response:@"Finished" outcome:@"completed" error:&error],"invalid result rejected");
  NSURL* preserved = [[NSURL fileURLWithPath:attempt[@"directory"]] URLByAppendingPathComponent:@"received.bplist"];
  Check([malformed isEqual:[NSData dataWithContentsOfURL:preserved]],"invalid original retained");
  [[NSFileManager defaultManager] removeItemAtURL:root error:nil];
  puts("immutable recipes, activation restart, source validation and failed-result retention passed");
}}
