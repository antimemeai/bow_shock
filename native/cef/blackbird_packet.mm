#import "blackbird_packet.h"
#include <cmath>
#include <cstring>
#include <limits>
#include <iterator>
#include <stdexcept>

const NSUInteger BSBlackbirdMaximumPacketBytes = 4 * 1024 * 1024;
namespace {
constexpr NSUInteger MaxNodes = 200000, MaxDepth = 64;
const char* const Words[] = {
  "label", "metadata", "time", "clock_id", "utc_ns", "monotonic_ns",
  "sampling_span_ns", "synchronization", "variable", "value", "source", "sample_id",
  "observation_status", "kind", "attempt", "invocation", "operation", "revision",
  "generation", "duration_ns", "input_binding", "retry_group", "ordinal", "field",
  "identity_scope", "content_observation", "repository", "requested_path", "path",
  "exit_code", "commit", "parents", "author_unix_seconds", "committer_unix_seconds",
  "host", "pid", "scope", "diagnostic_file", "expires_at", "bytes", "available",
  "storage_error", "complaint", "activation", "unknown", "observed", "unavailable",
  "variable.sample", "clock.domain", "doctrine.effective", "git.head", "git.commit",
  "native_request_field", "instructions", "git_cli", "operation.result",
  "provider.request", "provider.stream", "process.output", "invocation-v1",
  "attempt-invocation-v1", "turn-boundary", "result_id", "result_record"
};
[[noreturn]] void Bad(const char* message) { throw std::runtime_error(message); }
void SetError(NSError** error, const char* message) {
  if (error) *error = [NSError errorWithDomain:@"dev.oxcart.blackbird.packet" code:1
    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:message]}];
}
class Encoder {
  NSMutableData* data_ = [NSMutableData data];
  NSUInteger nodes_ = 0;
public:
  void raw(const void* bytes, NSUInteger count) {
    if (count > BSBlackbirdMaximumPacketBytes - data_.length) Bad("Packet exceeds 4 MiB");
    [data_ appendBytes:bytes length:count];
  }
  void byte(uint8_t value) { raw(&value, 1); }
  void varint(uint64_t value) {
    do { uint8_t b = value & 127; value >>= 7; byte(b | (value ? 128 : 0)); } while (value);
  }
  void string(NSString* value) {
    NSData* bytes = [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!bytes) Bad("String is not valid UTF-8");
    byte(6); varint(bytes.length); raw(bytes.bytes, bytes.length);
  }
  void value(id object, NSUInteger depth = 0) {
    if (depth > MaxDepth || ++nodes_ > MaxNodes) Bad("Packet structure exceeds limits");
    if (object == NSNull.null) { byte(0); return; }
    if ([object isKindOfClass:NSString.class]) { string(object); return; }
    if ([object isKindOfClass:NSNumber.class]) {
      if (CFGetTypeID((__bridge CFTypeRef)object) == CFBooleanGetTypeID()) {
        byte([object boolValue] ? 2 : 1); return;
      }
      if ([object isKindOfClass:NSDecimalNumber.class]) Bad("Decimal is outside the application schema");
      const char type = [object objCType][0];
      if (type == 'd' || type == 'f') {
        double value = [object doubleValue];
        if (!std::isfinite(value)) Bad("Non-finite number");
        uint64_t bits; std::memcpy(&bits, &value, 8); byte(11);
        for (unsigned i = 0; i < 8; ++i) byte(bits >> (i * 8));
      } else if (std::strchr("CSILQ", type)) {
        byte(3); varint([object unsignedLongLongValue]);
      } else if (std::strchr("csilqB", type)) {
        int64_t value = [object longLongValue]; byte(value < 0 ? 4 : 3);
        varint(value < 0 ? static_cast<uint64_t>(-(value + 1)) + 1 : static_cast<uint64_t>(value));
      } else Bad("Unsupported native number");
      return;
    }
    if ([object isKindOfClass:NSArray.class]) {
      byte(9); varint([object count]);
      for (id child in object) value(child, depth + 1);
      return;
    }
    if ([object isKindOfClass:NSDictionary.class]) {
      for (id key in object) if (![key isKindOfClass:NSString.class]) Bad("Map key is not text");
      byte(10); varint([object count]);
      for (NSString* key in [[object allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        string(key); value(object[key], depth + 1);
      }
      return;
    }
    Bad("Unsupported native value");
  }
  NSData* finish() { return [data_ copy]; }
};
class Decoder {
  const uint8_t* bytes_;
  NSUInteger size_, at_ = 0, nodes_ = 0;
public:
  explicit Decoder(NSData* data) : bytes_(static_cast<const uint8_t*>(data.bytes)), size_(data.length) {}
  uint8_t byte() { if (at_ == size_) Bad("Truncated packet"); return bytes_[at_++]; }
  uint64_t varint() {
    uint64_t value = 0;
    for (unsigned i = 0; i < 10; ++i) {
      uint8_t b = byte();
      if (i == 9 && b > 1) Bad("Overflowing integer");
      value |= static_cast<uint64_t>(b & 127) << (i * 7);
      if (!(b & 128)) { if (i && b == 0) Bad("Noncanonical integer"); return value; }
    }
    Bad("Overflowing integer");
  }
  NSString* string(uint8_t tag) {
    if (tag == 6) {
      uint64_t count = varint(); if (count > size_ - at_) Bad("Truncated text");
      NSString* value = [[NSString alloc] initWithBytes:bytes_ + at_ length:count encoding:NSUTF8StringEncoding];
      if (!value) Bad("Invalid UTF-8 text"); at_ += count; return value;
    }
    if (tag == 8) {
      uint64_t id = varint(); if (!id || id > std::size(Words)) Bad("Unknown word ID");
      return [NSString stringWithUTF8String:Words[id - 1]];
    }
    if (tag == 7) {
      static const char hex[] = "0123456789abcdef";
      char text[33];
      for (NSUInteger i = 0; i < 16; ++i) { uint8_t b = byte(); text[i * 2] = hex[b >> 4]; text[i * 2 + 1] = hex[b & 15]; }
      text[32] = 0; return [NSString stringWithUTF8String:text];
    }
    Bad("Map key is not text");
  }
  id value(NSUInteger depth = 0) {
    if (depth > MaxDepth || ++nodes_ > MaxNodes) Bad("Packet structure exceeds limits");
    uint8_t tag = byte();
    switch (tag) {
      case 0: return NSNull.null;
      case 1: return @NO;
      case 2: return @YES;
      case 3: return @(varint());
      case 4: {
        uint64_t n = varint(); if (!n || n > (uint64_t{1} << 63)) Bad("Invalid negative integer");
        return @(n == (uint64_t{1} << 63) ? INT64_MIN : -static_cast<int64_t>(n));
      }
      case 11: {
        uint64_t bits = 0; for (unsigned i = 0; i < 8; ++i) bits |= static_cast<uint64_t>(byte()) << (i * 8);
        double number; std::memcpy(&number, &bits, 8); if (!std::isfinite(number)) Bad("Non-finite number"); return @(number);
      }
      case 6: case 7: case 8: return string(tag);
      case 9: case 10: {
        uint64_t count = varint();
        if (count > MaxNodes - nodes_ || count > (size_ - at_) / (tag == 10 ? 2 : 1)) Bad("Container exceeds limits");
        if (tag == 9) {
          NSMutableArray* items = [NSMutableArray arrayWithCapacity:count];
          for (uint64_t i = 0; i < count; ++i) [items addObject:value(depth + 1)];
          return [items copy];
        }
        NSMutableDictionary* items = [NSMutableDictionary dictionaryWithCapacity:count];
        for (uint64_t i = 0; i < count; ++i) {
          NSString* key = string(byte()); if (items[key]) Bad("Duplicate map key"); items[key] = value(depth + 1);
        }
        return [items copy];
      }
      case 5: Bad("Decimal is outside the application schema");
      default: Bad("Unknown packet tag");
    }
  }
  bool complete() const { return at_ == size_; }
};
}
NSData* BSBlackbirdEncodePacket(id value, NSError** error) {
  try {
    Encoder encoder; const uint8_t magic[] = {'B', 'B', 'M', 2}; encoder.raw(magic, 4); encoder.value(value); return encoder.finish();
  } catch (const std::exception& problem) { SetError(error, problem.what()); return nil; }
}
id BSBlackbirdDecodePacket(NSData* packet, NSError** error) {
  try {
    if (packet.length > BSBlackbirdMaximumPacketBytes) Bad("Packet exceeds 4 MiB");
    Decoder decoder(packet);
    if (decoder.byte() != 'B' || decoder.byte() != 'B' || decoder.byte() != 'M' || decoder.byte() != 2) Bad("Unsupported packet header");
    id value = decoder.value(); if (!decoder.complete()) Bad("Trailing packet bytes"); return value;
  } catch (const std::exception& problem) { SetError(error, problem.what()); return nil; }
}
