#import "table_projection.h"
#include <climits>

namespace {
NSDictionary* Map(id value) { return [value isKindOfClass:NSDictionary.class] ? value : nil; }
bool Text(id value, NSUInteger limit, bool empty = false) {
  return [value isKindOfClass:NSString.class] && (empty || [value length]) &&
      [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= limit;
}
bool Identity(id value, NSUInteger limit) {
  if (!Text(value, limit)) return false;
  for (NSUInteger i = 0; i < [value length]; ++i) {
    unichar c = [value characterAtIndex:i];
    if (c == 0 || c == '\r' || c == '\n') return false;
  }
  return true;
}
bool Flag(id value, bool wanted) {
  return value && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() &&
      [value boolValue] == wanted;
}
bool Positive(id value, uint64_t& out) {
  if (![value isKindOfClass:NSNumber.class] ||
      CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return false;
  const char* type = [value objCType];
  if (type[0] == 'd' || type[0] == 'f' || [value longLongValue] <= 0 ||
      [value compare:@(LLONG_MAX)] == NSOrderedDescending) return false;
  out = [value unsignedLongLongValue]; return true;
}
NSString* Trim(NSString* value) {
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
bool Digits(NSString* value) {
  if (!value.length) return false;
  for (NSUInteger i = 0; i < value.length; ++i) {
    unichar c = [value characterAtIndex:i];
    if (c < '0' || c > '9') return false;
  }
  return true;
}
NSString* StripZeros(NSString* value) {
  NSUInteger first = 0;
  while (first + 1 < value.length && [value characterAtIndex:first] == '0') ++first;
  return [value substringFromIndex:first];
}
NSString* Dollars(NSString* value) {
  if (![value hasPrefix:@"USD "]) return nil;
  NSString* digits = [value substringFromIndex:4];
  NSArray* parts = [digits componentsSeparatedByString:@"."];
  if (parts.count != 2 || !Digits(parts[0]) || [parts[1] length] != 2 || !Digits(parts[1])) return nil;
  return [NSString stringWithFormat:@"%@.%@", StripZeros(parts[0]), parts[1]];
}
NSDictionary* State(NSString* name, NSString* raw) {
  NSString* text = Trim(raw);
  if (!text.length) return @{@"kind": @"empty"};
  if ([name isEqual:@"price"]) {
    NSArray* parts = [text componentsSeparatedByString:@" / "];
    if (parts.count == 2 && Dollars(parts[0]) && Dollars(parts[1]))
      return @{@"kind": @"ambiguous", @"candidates": parts};
    NSString* amount = Dollars(text);
    return amount ? @{@"kind": @"value", @"source": raw, @"value": amount} :
        @{@"kind": @"invalid", @"source": raw, @"reason": @"Expected explicit USD amount with two decimal places"};
  }
  if ([name isEqual:@"quantity"]) {
    NSString* number = Digits(text) ? StripZeros(text) : nil;
    NSString* maximum = @"18446744073709551615";
    if (!number || number.length > maximum.length ||
        (number.length == maximum.length && [number compare:maximum options:NSLiteralSearch] == NSOrderedDescending))
      return @{@"kind": @"invalid", @"source": raw, @"reason": @"Expected nonnegative ASCII u64 integer"};
    return @{@"kind": @"value", @"source": raw, @"value": number};
  }
  return @{@"kind": @"value", @"source": raw, @"value": text};
}
}

NSDictionary* BSFixtureTableBatch(NSDictionary* record, NSString* run, NSString* origin) {
  if (!Map(record) || ![record[@"status"] isEqual:@"partial"] ||
      !Flag(record[@"fixture_only"], true) || !Flag(record[@"general_observation_enabled"], false) ||
      !Identity(run, 128) || !Identity(origin, 512)) return nil;
  NSDictionary* ref = Map(record[@"observation_ref"]), *coverage = Map(record[@"coverage"]);
  NSDictionary* provenance = Map(ref[@"origin"]);
  if (!ref || !coverage || ![coverage[@"scope"] isEqual:@"root-only"] ||
      ![coverage[@"child_frames"] isEqual:@"withheld"] ||
      !Flag(coverage[@"atomic"], false) || !Flag(coverage[@"actionable_geometry"], false) ||
      ![ref[@"run_id"] isEqual:run] || ![provenance[@"kind"] isEqual:@"tuple"] ||
      ![provenance[@"security_origin"] isEqual:origin] ||
      ![provenance[@"provenance"] isEqual:@"Runtime.executionContextCreated.defaultContext"]) return nil;
  NSMutableDictionary* observed = [NSMutableDictionary dictionary];
  for (NSString* key in @[@"run_id", @"surface_id", @"frame_id", @"document_id", @"capture_id"]) {
    if (!Identity(ref[key], 128)) return nil;
    observed[key] = ref[key];
  }
  for (NSString* key in @[@"attachment_generation", @"activation_generation", @"node_generation"]) {
    uint64_t value;
    if (!Positive(ref[key], value)) return nil;
    observed[key] = @(value);
  }
  uint64_t start, end;
  if (!Positive(ref[@"capture_start_continuous_ns"], start) ||
      !Positive(ref[@"capture_end_continuous_ns"], end) || end < start || end - start > 3000000000) return nil;
  observed[@"security_origin"] = origin;
  observed[@"capture_start_ns"] = @(start); observed[@"capture_end_ns"] = @(end);
  NSArray* names = @[@"name", @"price", @"note", @"sku", @"quantity", @"private"];
  NSArray* incoming = record[@"fields"];
  if (![incoming isKindOfClass:NSArray.class] || incoming.count != names.count) return nil;
  NSMutableDictionary* indexed = [NSMutableDictionary dictionary];
  for (id value in incoming) {
    NSDictionary* field = Map(value);
    NSString* name = field[@"field_id"];
    if (!Text(name, 64) || ![names containsObject:name] || indexed[name] ||
        ![@[@"observed", @"withheld"] containsObject:field[@"status"] ?: @""]) return nil;
    indexed[name] = field;
  }
  NSMutableArray* fields = [NSMutableArray arrayWithCapacity:names.count];
  for (NSString* name in names) {
    NSDictionary* field = indexed[name];
    NSMutableDictionary* source = [@{@"observation": observed, @"node_id": NSNull.null,
        @"visibility": @"unavailable", @"normalization": @"unavailable-v1"} mutableCopy];
    NSDictionary* state;
    if ([name isEqual:@"private"]) {
      state = @{@"kind": @"inaccessible"};
    } else if ([field[@"status"] isEqual:@"withheld"]) {
      state = @{@"kind": [field[@"reason"] isEqual:@"missing_field"] ? @"missing" : @"inaccessible"};
    } else {
      NSString* raw = field[@"text"];
      uint64_t node;
      if (!Text(raw, 2048) || !Positive(field[@"backend_node_id"], node) ||
          ![field[@"visibility"] isEqual:@"layout-present-occlusion-unknown"]) return nil;
      source[@"fragment"] = raw; source[@"node_id"] = @(node);
      source[@"visibility"] = field[@"visibility"];
      source[@"normalization"] = [name isEqual:@"price"] ? @"usd-decimal2-v1" :
          ([name isEqual:@"quantity"] ? @"ascii-u64-v1" : @"text-trim-v1");
      state = State(name, raw);
    }
    [fields addObject:@{@"name": name, @"state": state, @"source": source}];
  }
  NSDictionary* batch = @{@"schema_version": @"owned-product-v1", @"pattern_version": @"owned-field-ids-v1",
      @"partial": @YES, @"rows": @[@{@"fields": fields}]};
  NSData* bytes = [NSJSONSerialization dataWithJSONObject:batch options:0 error:nil];
  return bytes && bytes.length <= 16384 ? batch : nil;
}
