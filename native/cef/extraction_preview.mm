#import "extraction_preview.h"

namespace {
void Append(NSMutableAttributedString* result, NSString* text, CGFloat size, BOOL bold, NSColor* color) {
  [result appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:@{
      NSFontAttributeName:bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size],
      NSForegroundColorAttributeName:color}]];
}
NSTextView* TextArea(NSView* parent, NSRect frame, BOOL editable) {
  NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:frame];
  scroll.hasVerticalScroller = YES; scroll.borderType = NSBezelBorder;
  scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  NSTextView* text = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,frame.size.width,frame.size.height)];
  text.editable = editable; text.richText = !editable; text.selectable = YES;
  text.verticallyResizable = YES; text.horizontallyResizable = NO;
  text.minSize = NSMakeSize(0,frame.size.height); text.maxSize = NSMakeSize(CGFLOAT_MAX,CGFLOAT_MAX);
  text.autoresizingMask = NSViewWidthSizable;
  text.textContainer.widthTracksTextView = YES; text.textContainer.containerSize = NSMakeSize(frame.size.width,CGFLOAT_MAX);
  text.textContainerInset = NSMakeSize(14,14); text.font = [NSFont systemFontOfSize:13];
  scroll.documentView = text; [parent addSubview:scroll]; return text;
}
NSButton* Button(NSView* parent, NSString* title, id target, SEL action, NSRect frame) {
  NSButton* button = [NSButton buttonWithTitle:title target:target action:action]; button.frame = frame;
  [parent addSubview:button]; return button;
}
NSTextField* Label(NSView* parent, NSString* title, NSRect frame) {
  NSTextField* label = [NSTextField labelWithString:title]; label.frame = frame; [parent addSubview:label]; return label;
}
}

NSAttributedString* OXRenderExtractionDocument(NSDictionary* document, NSArray** outputSources) {
  NSMutableAttributedString* result = [[NSMutableAttributedString alloc] init];
  NSMutableArray* sources = [NSMutableArray array];
  Append(result,[document[@"title"] stringByAppendingString:@"\n\n"],25,YES,NSColor.textColor);
  if (![document[@"blocks"] count]) Append(result,@"No extracted content.\n\n",15,YES,NSColor.systemOrangeColor);
  for (NSDictionary* block in document[@"blocks"]) {
    NSString* kind = block[@"kind"];
    if ([kind isEqual:@"heading"]) { Append(result,[block[@"text"] stringByAppendingString:@"\n\n"],19,YES,NSColor.textColor); continue; }
    Append(result,[NSString stringWithFormat:@"%@\n",block[@"interpretation"]],10,NO,NSColor.secondaryLabelColor);
    if ([kind isEqual:@"paragraph"]) Append(result,[block[@"text"] stringByAppendingString:@"\n"],14,NO,NSColor.textColor);
    else if ([kind isEqual:@"list"]) {
      for (NSString* item in block[@"items"]) Append(result,[NSString stringWithFormat:@"• %@\n",item],14,NO,NSColor.textColor);
    } else if ([kind isEqual:@"record"]) {
      for (NSDictionary* field in block[@"fields"]) {
        Append(result,[field[@"label"] stringByAppendingString:@": "],14,YES,NSColor.textColor);
        Append(result,[field[@"value"] stringByAppendingString:@"\n"],14,NO,NSColor.textColor);
      }
    } else if ([kind isEqual:@"table"]) {
      NSTextTable* table = [[NSTextTable alloc] init]; table.numberOfColumns = [block[@"columns"] count];
      table.layoutAlgorithm = NSTextTableAutomaticLayoutAlgorithm; table.collapsesBorders = YES;
      NSMutableArray* rows = [NSMutableArray arrayWithObject:block[@"columns"]]; [rows addObjectsFromArray:block[@"rows"]];
      NSInteger rowIndex = 0;
      for (NSArray* row in rows) {
        NSInteger column = 0;
        for (NSString* cell in row) {
          NSTextTableBlock* box = [[NSTextTableBlock alloc] initWithTable:table startingRow:rowIndex rowSpan:1 startingColumn:column++ columnSpan:1];
          [box setWidth:5 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding];
          [box setWidth:0.5 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder];
          [box setBorderColor:NSColor.separatorColor];
          NSMutableParagraphStyle* paragraph = [[NSMutableParagraphStyle alloc] init]; paragraph.textBlocks = @[box];
          [result appendAttributedString:[[NSAttributedString alloc] initWithString:[cell stringByAppendingString:@"\n"]
              attributes:@{NSParagraphStyleAttributeName:paragraph,
                NSFontAttributeName:rowIndex == 0 ? [NSFont boldSystemFontOfSize:13] : [NSFont systemFontOfSize:13],
                NSForegroundColorAttributeName:NSColor.textColor}]];
        }
        ++rowIndex;
      }
    }
    for (NSDictionary* source in block[@"sources"]) {
      NSUInteger index = sources.count; [sources addObject:source];
      NSString* label = [NSString stringWithFormat:@"[Source %lu] ",(unsigned long)index+1];
      [result appendAttributedString:[[NSAttributedString alloc] initWithString:label attributes:@{
          NSLinkAttributeName:[NSURL URLWithString:[NSString stringWithFormat:@"oxcart-source:%lu",(unsigned long)index]],
          NSForegroundColorAttributeName:NSColor.linkColor,NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle),
          NSFontAttributeName:[NSFont systemFontOfSize:11]}]];
    }
    Append(result,@"\n\n",14,NO,NSColor.textColor);
  }
  Append(result,@"Coverage and unresolved issues\n",17,YES,NSColor.textColor);
  if (![document[@"issues"] count]) Append(result,@"No issues reported by the bot; inspect the result against the page.\n",13,NO,NSColor.secondaryLabelColor);
  for (NSString* issue in document[@"issues"]) Append(result,[NSString stringWithFormat:@"• %@\n",issue],13,NO,NSColor.textColor);
  Append(result,[NSString stringWithFormat:@"\nBot assessment: %@\n",document[@"assessment"]],12,YES,NSColor.secondaryLabelColor);
  if (outputSources) *outputSources = sources;
  return result;
}

@implementation OXExtractionPreview {
  NSWindow* _window;
  NSTextView* _text;
  NSTextView* _feedback;
  NSTextField* _status;
  NSPopUpButton* _history;
  NSButton* _revise;
  NSButton* _save;
  NSMutableArray* _attempts;
  NSDictionary* _displayed;
  NSArray* _sources;
  NSArray* _recipes;
  NSPanel* _recipePanel;
  NSPopUpButton* _recipeMenu;
  NSTextView* _recipeText;
  NSPanel* _sourcePanel;
  NSTextView* _sourceText;
  BOOL _working;
}
- (instancetype)init {
  if ((self = [super init])) {
    _attempts = [NSMutableArray array]; _recipes = @[];
    NSRect screen = NSScreen.mainScreen.visibleFrame;
    CGFloat width = MIN(920,screen.size.width-40), height = MIN(820,screen.size.height-60);
    _window = [[NSWindow alloc] initWithContentRect:NSMakeRect(30,NSMaxY(screen)-height-25,width,height)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    _window.title = @"Oxcart · Extraction preview"; _window.releasedWhenClosed = NO;
    NSView* content = _window.contentView;
    _history = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(16,height-46,width-165,29) pullsDown:NO];
    _history.target = self; _history.action = @selector(historyChanged:); [content addSubview:_history];
    Button(content,@"Recipes…",self,@selector(recipeBox:),NSMakeRect(width-135,height-46,119,29));
    _status = Label(content,@"Extract a page to begin.",NSMakeRect(16,height-73,width-32,22));
    _status.font = [NSFont systemFontOfSize:12]; _status.textColor = NSColor.secondaryLabelColor;
    _text = TextArea(content,NSMakeRect(16,171,width-32,height-252),NO); _text.delegate = self;
    Label(content,@"Describe a correction; selected preview text is included.",NSMakeRect(16,142,width-32,22));
    _feedback = TextArea(content,NSMakeRect(16,57,width-32,80),YES);
    _revise = Button(content,@"Revise with bot",self,@selector(revise:),NSMakeRect(width-155,16,139,32));
    _save = Button(content,@"Save recipe…",self,@selector(saveRecipe:),NSMakeRect(16,16,126,32));
    Button(content,@"Open attempt files",self,@selector(openFiles:),NSMakeRect(151,16,157,32));
    [self setWorking:NO message:@"Extract a page to begin."];
  }
  return self;
}
- (void)show { [_window makeKeyAndOrderFront:nil]; }
- (void)setWorking:(BOOL)working message:(NSString*)message {
  _working = working; _status.stringValue = message;
  _revise.enabled = !working && _displayed != nil;
  _save.enabled = !working && _displayed[@"document"] != nil;
}
- (void)display:(NSDictionary*)entry {
  _displayed = entry;
  NSDictionary* document = entry[@"document"];
  NSAttributedString* rendered;
  if (document) { NSArray* sources = nil; rendered = OXRenderExtractionDocument(document,&sources); _sources = sources; }
  else {
    _sources = @[];
    rendered = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Extraction attempt needs work\n\n%@\n\nThe attempt and any submitted bytes are preserved. Describe a correction below.",entry[@"failure"] ?: @"No result"]
        attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:15]}];
  }
  [_text.textStorage setAttributedString:rendered];
  [_text.layoutManager ensureLayoutForTextContainer:_text.textContainer];
  CGFloat height = [_text.layoutManager usedRectForTextContainer:_text.textContainer].size.height + 2*_text.textContainerInset.height;
  [_text setFrameSize:NSMakeSize(_text.frame.size.width,MAX(height,_text.enclosingScrollView.contentSize.height))];
  [_text scrollRangeToVisible:NSMakeRange(0,0)];
  [self setWorking:_working message:document ? [NSString stringWithFormat:@"%@ · %@",entry[@"attempt"][@"phase"],document[@"assessment"]] : entry[@"failure"]];
}
- (NSDictionary<NSString*,NSData*>*)presentAttempt:(NSDictionary*)attempt document:(NSDictionary*)document failure:(NSString*)failure {
  NSMutableDictionary* entry = [@{@"attempt":attempt} mutableCopy];
  if (document) entry[@"document"] = document;
  if (failure) entry[@"failure"] = failure;
  [_attempts addObject:entry];
  [_history addItemWithTitle:[NSString stringWithFormat:@"%@ · %@ · %@",attempt[@"phase"],attempt[@"created_at"],document[@"title"] ?: @"Needs work"]];
  [_history selectItemAtIndex:_attempts.count-1]; [self display:entry]; [self show];
  NSMutableArray* links = [NSMutableArray array];
  [_text.textStorage enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0,_text.string.length) options:0
      usingBlock:^(id link, NSRange range, BOOL*) {
    if (link) [links addObject:@{@"character_offset":@(range.location),@"character_length":@(range.length),@"link":[link absoluteString]}];
  }];
  NSDictionary* layout = @{@"attempt_id":attempt[@"id"],@"sources":_sources ?: @[],@"links":links,
      @"view_width":@(_text.frame.size.width),@"view_height":@(_text.frame.size.height),@"character_count":@(_text.string.length),
      @"renderer":@"AppKit NSTextView; PDF/RTF/text share the displayed attributed document"};
  NSMutableDictionary* files = [NSMutableDictionary dictionary];
  files[@"preview.txt"] = [_text.string dataUsingEncoding:NSUTF8StringEncoding];
  files[@"preview.rtf"] = [_text.textStorage RTFFromRange:NSMakeRange(0,_text.string.length) documentAttributes:@{}];
  files[@"preview.pdf"] = [_text dataWithPDFInsideRect:_text.bounds];
  files[@"preview.bplist"] = [NSPropertyListSerialization dataWithPropertyList:layout format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
  return files;
}
- (void)historyChanged:(id)sender { (void)sender; if (_history.indexOfSelectedItem >= 0) [self display:_attempts[_history.indexOfSelectedItem]]; }
- (void)revise:(id)sender {
  (void)sender;
  NSString* correction = [_feedback.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (!correction.length || _working || !_displayed || !_actionHandler) return;
  NSString* selection = _text.selectedRange.length ? [_text.string substringWithRange:_text.selectedRange] : @"";
  _actionHandler(@"revise",@{@"attempt_id":_displayed[@"attempt"][@"id"],@"correction":correction,@"selection":selection});
  // Keep the operator's correction visible, including when a connection is busy.
}
- (void)openFiles:(id)sender { (void)sender; if (_displayed && _actionHandler) _actionHandler(@"files",@{@"attempt_id":_displayed[@"attempt"][@"id"]}); }
- (BOOL)textView:(NSTextView*)textView clickedOnLink:(id)link atIndex:(NSUInteger)characterIndex {
  (void)textView; (void)characterIndex;
  NSURL* url = [link isKindOfClass:NSURL.class] ? link : [NSURL URLWithString:link];
  if (![url.scheme isEqual:@"oxcart-source"]) return YES;
  NSInteger index = url.resourceSpecifier.integerValue;
  if (index >= 0 && static_cast<NSUInteger>(index) < _sources.count && _actionHandler)
    _actionHandler(@"source",@{@"attempt_id":_displayed[@"attempt"][@"id"],@"source":_sources[index]});
  return YES;
}
- (void)saveRecipe:(id)sender {
  (void)sender; NSDictionary* candidate = _displayed[@"document"][@"recipe"];
  if (!candidate || !_actionHandler || _working) return;
  NSString* attemptID = _displayed[@"attempt"][@"id"];
  NSAlert* alert = [[NSAlert alloc] init]; alert.messageText = @"Save a new recipe";
  alert.informativeText = @"A complete new recipe becomes active. Earlier recipes and attempts remain available.";
  [alert addButtonWithTitle:@"Save recipe"]; [alert addButtonWithTitle:@"Cancel"];
  NSView* form = [[NSView alloc] initWithFrame:NSMakeRect(0,0,570,350)];
  Label(form,@"Page type",NSMakeRect(0,323,570,20));
  NSTextField* type = [[NSTextField alloc] initWithFrame:NSMakeRect(0,296,570,26)]; type.stringValue = candidate[@"page_type"]; [form addSubview:type];
  Label(form,@"Applies to",NSMakeRect(0,268,570,20));
  NSTextField* applies = [[NSTextField alloc] initWithFrame:NSMakeRect(0,241,570,26)]; applies.stringValue = candidate[@"applicability"]; [form addSubview:applies];
  Label(form,@"Complete collection and extraction instructions",NSMakeRect(0,211,570,22));
  NSTextView* instructions = TextArea(form,NSMakeRect(0,0,570,205),YES); instructions.string = candidate[@"instructions"];
  alert.accessoryView = form;
  [alert beginSheetModalForWindow:_window completionHandler:^(NSModalResponse response) {
    if (response == NSAlertFirstButtonReturn && self->_actionHandler)
      self->_actionHandler(@"save_recipe",@{@"attempt_id":attemptID,@"candidate":@{
          @"page_type":type.stringValue,@"applicability":applies.stringValue,@"instructions":instructions.string}});
  }];
}
- (void)setRecipes:(NSArray<NSDictionary*>*)recipes selectedID:(NSString*)identity {
  _recipes = recipes;
  if (!_recipePanel) return;
  [_recipeMenu removeAllItems]; [_recipeMenu addItemWithTitle:@"Generic pass (no saved recipe)"];
  NSInteger selected = 0, index = 1;
  for (NSDictionary* recipe in recipes) {
    [_recipeMenu addItemWithTitle:[NSString stringWithFormat:@"%@ · %@%@ · %@",recipe[@"page_type"],recipe[@"created_at"],
        [recipe[@"active"] boolValue] ? @" · active" : @" · superseded/inactive",[recipe[@"id"] substringToIndex:8]]];
    if ([recipe[@"id"] isEqual:identity]) selected = index;
    ++index;
  }
  [_recipeMenu selectItemAtIndex:selected]; [self recipeChanged:nil];
}
- (void)recipeBox:(id)sender {
  (void)sender;
  if (!_recipePanel) {
    _recipePanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(80,100,760,570)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    _recipePanel.title = @"Oxcart · Recipe box"; _recipePanel.releasedWhenClosed = NO;
    _recipeMenu = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(16,521,728,32) pullsDown:NO];
    _recipeMenu.target = self; _recipeMenu.action = @selector(recipeChanged:); [_recipePanel.contentView addSubview:_recipeMenu];
    _recipeText = TextArea(_recipePanel.contentView,NSMakeRect(16,62,728,449),NO);
    Button(_recipePanel.contentView,@"Use for next extraction",self,@selector(useRecipe:),NSMakeRect(520,16,224,32));
    [self setRecipes:_recipes selectedID:nil];
  }
  if (_actionHandler) _actionHandler(@"recipes",@{});
  [_recipePanel makeKeyAndOrderFront:nil];
}
- (void)recipeChanged:(id)sender {
  (void)sender; NSInteger selected = _recipeMenu.indexOfSelectedItem;
  if (selected <= 0) { _recipeText.string = @"Start with the generic extraction pass.\n\nAll saved recipes and activation history remain available."; return; }
  NSDictionary* recipe = _recipes[selected-1];
  _recipeText.string = [NSString stringWithFormat:@"%@\n\nCreated: %@\nID: %@\nSupersedes: %@\n\nApplies to\n%@\n\nComplete instructions\n%@\n\nSource attempt: %@\n\n%@",
      recipe[@"page_type"],recipe[@"created_at"],recipe[@"id"],recipe[@"predecessor_id"] ?: @"none",
      recipe[@"applicability"],recipe[@"instructions"],recipe[@"source_attempt_id"],recipe[@"path"]];
}
- (void)useRecipe:(id)sender {
  (void)sender; NSInteger selected = _recipeMenu.indexOfSelectedItem;
  if (_actionHandler) _actionHandler(@"select_recipe",@{@"recipe_id":selected > 0 ? _recipes[selected-1][@"id"] : @""});
  [_recipePanel orderOut:nil];
}
- (void)showSource:(NSString*)text title:(NSString*)title selection:(NSRange)selection {
  if (!_sourcePanel) {
    _sourcePanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(100,100,820,660)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    _sourcePanel.releasedWhenClosed = NO; _sourceText = TextArea(_sourcePanel.contentView,NSMakeRect(12,12,796,636),NO);
  }
  _sourcePanel.title = title; _sourceText.string = text;
  if (selection.location != NSNotFound && NSMaxRange(selection) <= text.length) {
    _sourceText.selectedRange = selection; [_sourceText scrollRangeToVisible:selection];
  }
  [_sourcePanel makeKeyAndOrderFront:nil];
}
- (void)close { [_window orderOut:nil]; [_recipePanel orderOut:nil]; [_sourcePanel orderOut:nil]; _actionHandler = nil; }
@end
