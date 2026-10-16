// Protocol-table inputs exercise the adapter, without constructing web pages.
#import "../native/cef/live_observation.mm"
#include <cstdio>
#include <cstdlib>

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
static NSMutableDictionary* ManyNodes(NSString* text) {
  NSMutableDictionary* snapshot=Snapshot(text);
  NSMutableDictionary* doc=[snapshot[@"documents"][0] mutableCopy];
  NSMutableDictionary* nodes=[doc[@"nodes"] mutableCopy], *layout=[doc[@"layout"] mutableCopy];
  for (NSString* key in nodes.allKeys) nodes[key]=[nodes[key] mutableCopy];
  for (NSString* key in layout.allKeys) layout[key]=[layout[key] mutableCopy];
  for (NSUInteger i=15;i<315;++i) {
    [nodes[@"parentIndex"] addObject:@13]; [nodes[@"nodeName"] addObject:@7];
    [nodes[@"nodeType"] addObject:@3]; [nodes[@"backendNodeId"] addObject:@(i+1)]; [nodes[@"attributes"] addObject:@[]];
    [layout[@"nodeIndex"] addObject:@(i)]; [layout[@"styles"] addObject:@[@23,@24,@25]];
    [layout[@"bounds"] addObject:@[@0,@(i*20),@200,@18]]; [layout[@"text"] addObject:@22];
  }
  doc[@"nodes"]=nodes; doc[@"layout"]=layout; snapshot[@"documents"]=@[doc];
  return snapshot;
}
int main() { @autoreleasepool {
  NSString* error=nil;
  BSLivePage* page=Project(Snapshot(@"End"),Frame(),&error);
  Require(page && !error,"valid DOM/layout rejected");
  Require([page.text isEqual:@"Café 🐦\nRead docs\nEnd"],"form text/Unicode changed or hidden/password/editor contents escaped");
  Require(!page.truncated && page.blocks.count==3 && page.childFrameCount==1,"ordinary output coverage incorrect");
  Require([page.blocks[0].tagName isEqual:@"FORM"] && page.blocks[0].backendNodeId==5,"form-adjacent text lost source identity");
  Require([page.blocks[1].linkURL isEqual:@"https://example.org/docs"],"link did not resolve against document base");
  Require(NSEqualRects(page.blocks[1].bounds,NSMakeRect(10,200,200,18)),"document CSS bounds changed");
  Require(![page.text containsString:@"secret"] && ![page.text containsString:@"hidden"],"excluded content leaked");
  page.captureId=@"capture";
  NSDictionary* observation=[page nativeValue];
  Require([observation[@"links"] isEqual:@[@{@"url":@"https://example.org/docs",@"text":@"Read docs"}]],"rendered link destination/label lost on native observation boundary");
  Require([observation[@"links_truncated"] isEqual:@NO] && [observation[@"text"] isEqual:page.text],"native observation changed text or link coverage");
  NSMutableArray* linkedBlocks=[NSMutableArray array];
  for (NSUInteger i=0;i<65;++i) {
    BSLiveTextBlock* block=[BSLiveTextBlock new]; block.text=@"A link";
    block.linkURL=[NSString stringWithFormat:@"https://example.org/%lu",(unsigned long)i];
    [linkedBlocks addObject:block]; [linkedBlocks addObject:block];
  }
  page.blocks=linkedBlocks; observation=[page nativeValue];
  Require([observation[@"links"] count]==64 && [observation[@"links_truncated"] isEqual:@YES],"distinct rendered links were duplicated or silently omitted at the limit");

  NSString* longUnicode=[@"🕊é" stringByPaddingToLength:9999 withString:@"🕊é" startingAtIndex:0];
  page=Project(Snapshot(longUnicode),Frame(),&error);
  Require(page && page.truncated && [page.blocks.lastObject.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]<=kBlockBytes,"multibyte block limit failed");
  Require([page.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]<=kOutputBytes && ![page.text containsString:@"�"],"UTF-8 truncation corrupted output");
  page=Project(ManyNodes([@"x" stringByPaddingToLength:2048 withString:@"x" startingAtIndex:0]),Frame(),&error);
  Require(page && page.truncated && [page.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]==kOutputBytes,"total rendered text byte bound failed");
  page=Project(ManyNodes(@"x"),Frame(),&error);
  Require(page && page.truncated && page.blocks.count==kBlocks,"text block count bound failed");
  unichar surrogate=0xd800;
  BOOL invalidTruncated=NO;
  Require([Bounded([NSString stringWithCharacters:&surrogate length:1],100,invalidTruncated) isEqual:@""] && invalidTruncated,"non-UTF-8 string escaped output bounds");

  NSMutableDictionary* malformed=Snapshot(@"End");
  NSMutableDictionary* doc=[malformed[@"documents"][0] mutableCopy];
  NSMutableDictionary* nodes=[doc[@"nodes"] mutableCopy]; nodes[@"parentIndex"]=@[@-1]; doc[@"nodes"]=nodes; malformed[@"documents"]=@[doc];
  error=nil; Require(!Project(malformed,Frame(),&error) && error.length,"inconsistent columns accepted");
  Require([HTTPURL(@"javascript:alert(1)",@"https://example.org/") isEqual:@""],"executable link exposed as HTTP URL");
  Require([HTTPURL(@"http://[") isEqual:@""],"malformed URL accepted");
  Require([HTTPURL(@"https://user:secret@example.org/") isEqual:@"https://example.org/"],"URL credentials retained");
  puts("live observation protocol projection passed");
} }
