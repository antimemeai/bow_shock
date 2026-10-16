#import "input_events.h"

NSDictionary* OXNativeInputFields(NSEvent* event) {
  NSString* kind;
  BOOL key = NO, mouse = NO, button = NO, motion = NO, pressure = NO, scroll = NO;
  switch (event.type) {
    case NSEventTypeKeyDown: kind = @"key_down"; key = YES; break;
    case NSEventTypeKeyUp: kind = @"key_up"; key = YES; break;
    case NSEventTypeFlagsChanged: kind = @"flags_changed"; break;
    case NSEventTypeLeftMouseDown: kind = @"left_down"; mouse = button = pressure = YES; break;
    case NSEventTypeLeftMouseUp: kind = @"left_up"; mouse = button = pressure = YES; break;
    case NSEventTypeRightMouseDown: kind = @"right_down"; mouse = button = pressure = YES; break;
    case NSEventTypeRightMouseUp: kind = @"right_up"; mouse = button = pressure = YES; break;
    case NSEventTypeOtherMouseDown: kind = @"other_down"; mouse = button = pressure = YES; break;
    case NSEventTypeOtherMouseUp: kind = @"other_up"; mouse = button = pressure = YES; break;
    case NSEventTypeMouseMoved: kind = @"mouse_move"; mouse = motion = YES; break;
    case NSEventTypeLeftMouseDragged: kind = @"left_drag"; mouse = button = motion = pressure = YES; break;
    case NSEventTypeRightMouseDragged: kind = @"right_drag"; mouse = button = motion = pressure = YES; break;
    case NSEventTypeOtherMouseDragged: kind = @"other_drag"; mouse = button = motion = pressure = YES; break;
    case NSEventTypeMouseEntered: kind = @"mouse_enter"; mouse = YES; break;
    case NSEventTypeMouseExited: kind = @"mouse_exit"; mouse = YES; break;
    case NSEventTypeScrollWheel: kind = @"scroll_wheel"; mouse = scroll = YES; break;
    case NSEventTypePressure: kind = @"pressure"; mouse = pressure = YES; break;
    default: return nil;
  }
  NSMutableDictionary* fields = [@{@"type":kind,@"appkit_type":@(event.type),
      @"native_timestamp_seconds":@(event.timestamp),@"modifier_flags":@(event.modifierFlags),
      @"window_number":@(event.windowNumber),@"stage":@"before_application_dispatch"} mutableCopy];
  if (key || event.type == NSEventTypeFlagsChanged) fields[@"key_code"] = @(event.keyCode);
  if (key) {
    fields[@"characters"] = event.characters ?: @"";
    fields[@"characters_ignoring_modifiers"] = event.charactersIgnoringModifiers ?: @"";
    fields[@"repeat"] = @(event.isARepeat);
    fields[@"appkit_input_source"] = NSTextInputContext.currentInputContext.selectedKeyboardInputSource ?: @"unknown";
  }
  if (mouse) {
    NSPoint p = event.locationInWindow;
    fields[@"window_x"] = @(p.x); fields[@"window_y"] = @(p.y);
  }
  if (button) {
    fields[@"button_number"] = @(event.buttonNumber);
    fields[@"click_count"] = @(event.clickCount);
  }
  if (motion || scroll) {
    fields[@"delta_x"] = @(event.deltaX); fields[@"delta_y"] = @(event.deltaY);
  }
  if (pressure) fields[@"pressure"] = @(event.pressure);
  if (scroll) {
    fields[@"delta_z"] = @(event.deltaZ);
    fields[@"scrolling_delta_x"] = @(event.scrollingDeltaX);
    fields[@"scrolling_delta_y"] = @(event.scrollingDeltaY);
    fields[@"precise_scrolling_deltas"] = @(event.hasPreciseScrollingDeltas);
    fields[@"phase"] = @(event.phase); fields[@"momentum_phase"] = @(event.momentumPhase);
    fields[@"direction_inverted_from_device"] = @(event.directionInvertedFromDevice);
  }
  return fields;
}
