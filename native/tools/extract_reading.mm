#import <Cocoa/Cocoa.h>
#import "../cef/blackbird_connection.h"
#import "../cef/extraction_controller.h"
#import "../cef/extraction_workspace.h"

int main(int argc, const char* argv[]) { @autoreleasepool {
  if (argc != 6) { fputs("Usage: extract-reading BLACKBIRD READING DATA_DIR CWD OBJECTIVE\n",stderr); return 2; }
  [NSApplication sharedApplication];
  NSMutableArray<NSString*>* args = [NSMutableArray array];
  for (int i=1;i<argc;++i) [args addObject:[NSString stringWithUTF8String:argv[i]]];
  NSURL* binary = [NSURL fileURLWithPath:args[0]], *reading = [NSURL fileURLWithPath:args[1] isDirectory:YES];
  NSURL* data = [NSURL fileURLWithPath:args[2] isDirectory:YES], *cwd = [NSURL fileURLWithPath:args[3] isDirectory:YES];
  NSURL* manifestURL = [reading URLByAppendingPathComponent:@"reading.bplist"];
  NSError* error = nil;
  NSData* source = [NSData dataWithContentsOfURL:manifestURL options:0 error:&error];
  NSDictionary* manifest = source ? [NSPropertyListSerialization propertyListWithData:source options:0 format:nil error:&error] : nil;
  if (![manifest isKindOfClass:NSDictionary.class] || ![manifest[@"format"] isEqual:@"oxcart.reading"] || ![manifest[@"capture_id"] isKindOfClass:NSString.class]) {
    fprintf(stderr,"Unreadable complete reading: %s\n",(error.localizedDescription ?: @"invalid format").UTF8String); return 2;
  }
  NSDictionary* reference = @{@"capture_id":manifest[@"capture_id"],@"url":manifestURL.absoluteString,
    @"title":@"Complete retained browser reading",@"text":[NSString stringWithFormat:@"Full reading guide: %@. Source manifest: %@. Choose whole files or ranges yourself.",[reading URLByAppendingPathComponent:@"README.txt"].path,manifestURL.path],
    @"reading":@{@"format":@"oxcart.reading",@"version":@1,@"directory":reading.path,@"manifest_path":manifestURL.path}};
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithDictionary:@{@"source_reading":reading.path,@"created_at":NSDate.date}];
  BSBlackbirdConnection* connection = [[BSBlackbirdConnection alloc] initWithExecutableURL:binary sessionURL:[data URLByAppendingPathComponent:@"blackbird"] workingDirectoryURL:cwd model:@"gpt-6.1-sol"];
  OXExtractionController* controller = [[OXExtractionController alloc] initWithDataURL:data connection:connection result:result];
  __block BOOL finished = NO, closing = NO, saved = YES;
  void (^finish)(void) = ^{
    if (closing) return; closing = YES;
    NSError* failure = nil;
    NSData* bytes = [NSPropertyListSerialization dataWithPropertyList:result format:NSPropertyListBinaryFormat_v1_0 options:0 error:&failure];
    NSURL* run = [[data URLByAppendingPathComponent:@"runs"] URLByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"bplist"]];
    if (!bytes || !OXWriteArtifact(bytes,run,&failure)) { saved = NO; fprintf(stderr,"Run result: %s\n",failure.localizedDescription.UTF8String); }
    dispatch_group_t group = dispatch_group_create(); dispatch_group_enter(group); dispatch_group_enter(group);
    [controller closeWithCompletion:^{ dispatch_group_leave(group); }];
    [connection closeWithCompletion:^{ dispatch_group_leave(group); }];
    dispatch_group_notify(group,dispatch_get_main_queue(),^{ finished = YES; });
  };
  controller.finished = finish;
  __weak OXExtractionController* weakController = controller;
  connection.eventHandler = ^(NSDictionary* event) {
    if ([weakController receiveEvent:event]) return;
    if ([event[@"type"] isEqual:@"ready"]) {
      [weakController beginVisitWithURL:manifest[@"url"] ?: @"" title:manifest[@"title"] ?: @"Retained browser visit"];
      [weakController addReading:reference]; [weakController extract:args[4]];
    } else if ([event[@"type"] isEqual:@"error"]) fprintf(stderr,"Blackbird: %s\n",[event[@"message"] UTF8String]);
    else if ([event[@"type"] isEqual:@"closed"] && !closing) { result[@"extraction_error"] = @"Blackbird closed before extraction completed"; finish(); }
  };
  [connection start];
  while (!finished) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
  connection.eventHandler = nil; controller.finished = nil;
  printf("Extraction workspace: %s\n",data.path.UTF8String);
  NSDictionary* extracted = result[@"extraction"];
  if (!saved || result[@"extraction_error"] || ![extracted[@"valid"] boolValue] || ![extracted[@"phase"] isEqual:@"tweak"]) {
    fprintf(stderr,"Extraction failed: %s\n",[result[@"extraction_error"] description].UTF8String); return 1;
  }
  printf("Initial + tweak rendered: %s\n",[extracted[@"directory"] UTF8String]); return 0;
}}
