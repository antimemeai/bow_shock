// Protocol-table inputs exercise the adapter, without constructing web pages.
#import "../native/cef/live_observation.mm"
#include <cstdio>
#include <cstdlib>
#include <dlfcn.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
static bool diskFull = false;
extern "C" ssize_t write(int fd, const void* bytes, size_t count) {
  char path[PATH_MAX];
  if (diskFull && fcntl(fd,F_GETPATH,path)==0 && strstr(path,"/documents/0.txt")) { errno=ENOSPC; return -1; }
  static auto realWrite = reinterpret_cast<ssize_t(*)(int,const void*,size_t)>(dlsym(RTLD_NEXT,"write"));
  return realWrite(fd,bytes,count);
}

static void Require(BOOL condition, const char* message) {
  if (!condition) { fprintf(stderr, "%s\n", message); exit(1); }
}

static NSMutableDictionary* Snapshot(NSString* ending) {
  NSArray* strings = @[@"root", @"Live title", @"https://example.org/", @"#document", @"HTML", @"BODY",
    @"FORM", @"#text", @"Café 🐦", @"INPUT", @"type", @"password", @"secret value", @"SPAN", @"hidden text",
    @"A", @"href", @"/docs", @"Read docs", @"TEXTAREA", @"editable secret", @"P", ending,
    @"block", @"visible", @"1", @"hidden"];
  NSArray* parents = @[@-1,@0,@1,@2,@3,@3,@5,@2,@7,@2,@9,@3,@11,@2,@13];
  NSArray* names = @[@3,@4,@5,@6,@7,@9,@7,@13,@7,@15,@7,@19,@7,@21,@7];
  NSMutableArray* types = [NSMutableArray array], *ids = [NSMutableArray array], *attrs = [NSMutableArray array];
  for (NSUInteger i=0; i<parents.count; ++i) {
    [types addObject:i==0?@9:([@[@4,@6,@8,@10,@12,@14] containsObject:@(i)]?@3:@1)];
    [ids addObject:@(i+1)]; [attrs addObject:i==5?@[@10,@11]:(i==9?@[@16,@17]:@[])];
  }
  NSMutableArray* indexes = [NSMutableArray array], *styles = [NSMutableArray array],
      *bounds = [NSMutableArray array], *texts = [NSMutableArray array];
  for (NSUInteger i=0; i<parents.count; ++i) {
    [indexes addObject:@(i)]; [styles addObject:@[@23,(i==7||i==8)?@26:@24,@25]];
    [bounds addObject:@[@10,@(i*20),@200,@18]];
    [texts addObject:i==4?@8:i==6?@12:i==8?@14:i==10?@18:i==12?@20:i==14?@22:@-1];
  }
  return [@{@"strings":strings,@"documents":@[@{@"frameId":@0,@"title":@1,@"baseURL":@2,
    @"nodes":@{@"parentIndex":parents,@"nodeName":names,@"nodeType":types,@"backendNodeId":ids,@"attributes":attrs},
    @"layout":@{@"nodeIndex":indexes,@"styles":styles,@"bounds":bounds,@"text":texts}}]} mutableCopy];
}
static BSLiveFrame* Frame() {
  NSString* error=nil;
  BSLiveFrame* frame=ReadFrame(@{@"frameTree":@{@"frame":@{@"id":@"root",@"loaderId":@"document",@"url":@"https://example.org/",@"securityOrigin":@"https://example.org"},@"childFrames":@[@{@"frame":@{@"id":@"child"}}]}},&error);
  Require(frame && !error,"valid external frame rejected"); return frame;
}
static NSMutableDictionary* ManyNodes(NSString* text, NSUInteger count) {
  NSMutableDictionary* snapshot=Snapshot(text);
  NSMutableDictionary* doc=[snapshot[@"documents"][0] mutableCopy];
  NSMutableDictionary* nodes=[doc[@"nodes"] mutableCopy], *layout=[doc[@"layout"] mutableCopy];
  for (NSString* key in nodes.allKeys) nodes[key]=[nodes[key] mutableCopy];
  for (NSString* key in layout.allKeys) layout[key]=[layout[key] mutableCopy];
  for (NSUInteger i=15;i<count;++i) {
    [nodes[@"parentIndex"] addObject:@13]; [nodes[@"nodeName"] addObject:@7];
    [nodes[@"nodeType"] addObject:@3]; [nodes[@"backendNodeId"] addObject:@(i+1)]; [nodes[@"attributes"] addObject:@[]];
    [layout[@"nodeIndex"] addObject:@(i)]; [layout[@"styles"] addObject:@[@23,@24,@25]];
    [layout[@"bounds"] addObject:@[@0,@(i*20),@200,@18]]; [layout[@"text"] addObject:@22];
  }
  doc[@"nodes"]=nodes; doc[@"layout"]=layout; snapshot[@"documents"]=@[doc]; return snapshot;
}
static id Load(NSURL* path) {
  NSError* error=nil;
  id value=[NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:path]
      options:NSPropertyListImmutable format:nil error:&error];
  Require(value && !error,"unable to read actual binary archive"); return value;
}
int main() { @autoreleasepool {
  NSString* error=nil;
  BSLivePage* page=Project(Snapshot(@"End"),Frame(),&error);
  Require(page && !error,"valid DOM/layout rejected");
  NSArray* blocks=page.documents[0][@"blocks"];
  Require(blocks.count==3 && [blocks[0][@"text"] isEqual:@"Café 🐦"],"ordinary rendered view changed");
  Require([blocks[1][@"link_url"] isEqual:@"https://example.org/docs"],"resolved link lost");
  NSString* large=[@"🕊é" stringByPaddingToLength:999999 withString:@"🕊é" startingAtIndex:0];
  NSMutableDictionary* snapshot=ManyNodes(large,1500);
  NSMutableArray* docs=[snapshot[@"documents"] mutableCopy]; [docs addObject:docs[0]]; snapshot[@"documents"]=docs;
  page=Project(snapshot,Frame(),&error);
  Require(page && page.documents.count==2,"child/document table discarded");
  blocks=page.documents[0][@"blocks"];
  Require(blocks.count==1488 && [blocks.lastObject[@"text"] isEqual:large],"fragment, byte or individual text cap survived");
  // Keep the on-disk regression useful without writing the repeated 1GiB view.
  snapshot=ManyNodes(@"tail 🐦",210000);
  page=Project(snapshot,Frame(),&error);
  Require(page && [page.documents[0][@"blocks"] count]==209988,"old node/work limit survived");
  snapshot=Snapshot(large); docs=[snapshot[@"documents"] mutableCopy]; [docs addObject:docs[0]]; snapshot[@"documents"]=docs;
  // More than the former24MiB callback allowance, preserved as an actual blob.
  NSString* huge=[@"source-" stringByPaddingToLength:25*1024*1024 withString:@"source-" startingAtIndex:0];
  NSMutableArray* strings=[snapshot[@"strings"] mutableCopy]; [strings addObject:huge]; snapshot[@"strings"]=strings;
  page=Project(snapshot,Frame(),&error); Require(page && !error,"complete large source rejected");
  NSURL* root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
  NSError* failure=nil;
  NSURL* path=BSWriteReading(root,@"complete",@{@"capture_id":@"complete"},snapshot,page.documents,&failure);
  Require(path && !failure,"complete archive write failed");
  NSDictionary* manifest=Load([path URLByAppendingPathComponent:@"reading.bplist"]);
  NSDictionary* dom=Load([path URLByAppendingPathComponent:@"dom.bplist"]);
  Require([manifest[@"documents"] count]==2 && [dom[@"documents"] isEqual:snapshot[@"documents"]],"source document columns changed or disappeared");
  NSDictionary* blob=dom[@"strings"][22];
  Require([blob isKindOfClass:NSDictionary.class],"large string stayed inline");
  NSData* actual=[NSData dataWithContentsOfURL:[path URLByAppendingPathComponent:blob[@"blob"]]];
  Require([actual isEqual:[large dataUsingEncoding:NSUTF8StringEncoding]],"large string blob lost bytes");
  NSDictionary* hugeBlob=[dom[@"strings"] lastObject];
  Require([[NSData dataWithContentsOfURL:[path URLByAppendingPathComponent:hugeBlob[@"blob"]]] isEqual:[huge dataUsingEncoding:NSUTF8StringEncoding]],"large callback source blob shortened");
  NSDictionary* view=manifest[@"documents"][0];
  NSData* text=[NSData dataWithContentsOfURL:[path URLByAppendingPathComponent:view[@"text_file"]]];
  NSDictionary* index=Load([path URLByAppendingPathComponent:view[@"blocks_file"]]);
  NSUInteger offset=[index[@"byte_offset"][2] unsignedIntegerValue], length=[index[@"byte_length"][2] unsignedIntegerValue];
  Require([[text subdataWithRange:NSMakeRange(offset,length)] isEqual:[large dataUsingEncoding:NSUTF8StringEncoding]],"text tail or byte-index range lost bytes");
  Require([view[@"text_bytes"] unsignedIntegerValue]==text.length,"stored text size differs from file");
  Require([dom[@"strings"][12] isEqual:@"secret value"] && [dom[@"strings"][20] isEqual:@"editable secret"],"full harvested source was redacted");
  Require(!BSWriteReading(root,@"complete",@{},snapshot,page.documents,&failure),"existing completed reading overwritten");
  Require([Load([path URLByAppendingPathComponent:@"dom.bplist"])[@"documents"] isEqual:snapshot[@"documents"]],"failed publication damaged original reading");
  diskFull=true; failure=nil;
  Require(!BSWriteReading(root,@"disk-full",@{},snapshot,page.documents,&failure),"disk-full write reported successful");
  diskFull=false;
  Require([failure.localizedDescription containsString:@"Write reading"],"write failure lost its error across autorelease pools");
  Require(![NSFileManager.defaultManager fileExistsAtPath:[root.path stringByAppendingPathComponent:@"disk-full"]],"failed write published a partial reading");
  NSURL* occupied=[root URLByAppendingPathComponent:@"not-a-directory"];
  [@"occupied" writeToURL:occupied atomically:YES encoding:NSUTF8StringEncoding error:nil];
  Require(!BSWriteReading(occupied,@"failure",@{},snapshot,page.documents,&failure),"failed archive destination reported successful");
  for (NSURL* entry in [NSFileManager.defaultManager contentsOfDirectoryAtURL:root includingPropertiesForKeys:nil options:0 error:nil])
    Require(![entry.lastPathComponent hasPrefix:@".reading-"],"failed write leaked staging directory");
  unichar surrogate=0xd800;
  NSString* unusual=[NSString stringWithCharacters:&surrogate length:1];
  NSDictionary* unusualSnapshot=Snapshot(unusual);
  BSLivePage* unusualPage=Project(unusualSnapshot,Frame(),&error);
  NSURL* unusualPath=BSWriteReading(root,@"utf16",@{},unusualSnapshot,unusualPage.documents,&failure);
  Require(unusualPath!=nil,"ill-formed source UTF-16 prevented retention");
  NSDictionary* unusualDom=Load([unusualPath URLByAppendingPathComponent:@"dom.bplist"]);
  NSDictionary* unusualBlob=unusualDom[@"strings"][22];
  const uint8_t expectedUnits[]={0,0xd8};
  Require([[NSData dataWithContentsOfURL:[unusualPath URLByAppendingPathComponent:unusualBlob[@"blob"]]] isEqual:[NSData dataWithBytes:expectedUnits length:2]],"source UTF-16 code units were changed");
  page.captureId=@"complete"; page.directoryURL=path;
  NSDictionary* reference=[page nativeValue];
  Require(![reference[@"text"] containsString:large] && [reference[@"reading"][@"manifest_path"] isEqual:[path.path stringByAppendingPathComponent:@"reading.bplist"]],"model notice inlined content or lost artifact path");
  NSMutableDictionary* malformed=Snapshot(@"End");
  NSMutableDictionary* doc=[malformed[@"documents"][0] mutableCopy];
  NSMutableDictionary* nodes=[doc[@"nodes"] mutableCopy]; nodes[@"parentIndex"]=@[@-1]; doc[@"nodes"]=nodes; malformed[@"documents"]=@[doc];
  error=nil; page=Project(malformed,Frame(),&error);
  Require(page && page.documents[0][@"view_error"],"malformed view lacked a specific error");
  NSURL* rawPath=BSWriteReading(root,@"malformed-view",@{},malformed,page.documents,&failure);
  Require(rawPath && [Load([rawPath URLByAppendingPathComponent:@"dom.bplist"])[@"documents"] isEqual:malformed[@"documents"]],"projection error discarded harvested source");
  Require([Load([rawPath URLByAppendingPathComponent:@"reading.bplist"])[@"views_complete"] isEqual:@NO],"incomplete text view reported complete");
  Require([HTTPURL(@"javascript:alert(1)",@"https://example.org/") isEqual:@""],"executable link exposed as HTTP URL");
  [NSFileManager.defaultManager removeItemAtURL:root error:nil];
  puts("complete native reading archive/projection passed");
} }
