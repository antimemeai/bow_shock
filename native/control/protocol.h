#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
#include <string>

// Closed control-only wire v1; see docs/plan/native-control-helper.md.
// Serialization is explicit big-endian bytes, never sizeof a C++ structure.
namespace bs_control {
constexpr std::size_t kRecordBytes = 160;
constexpr uint32_t kMaxLeaseMs = 5000;
constexpr uint64_t kInitTimeoutNs = 1000000000;
constexpr uint64_t kWriteTimeoutNs = 500000000;
using Wire = std::array<uint8_t, kRecordBytes>;
enum class Op : uint8_t { Initialize = 1, Heartbeat = 2, Stop = 3, Cancel = 4, Shutdown = 5 };
enum class Status : uint8_t { Live = 1, Fenced = 2, Closed = 3 };
enum class Fault : uint8_t {
  None = 0, Syntax = 1, UnsupportedOp = 2, State = 3, Sequence = 4,
  Fence = 5, Lease = 6, Truncated = 7, InitializationExpired = 8,
  LeaseExpired = 9, WriteStall = 10, IO = 11, Clock = 12,
  Overflow = 13, Queue = 14,
};
constexpr int ExitCode(Fault fault) { return 16 + static_cast<int>(fault); }
struct Record {
  uint8_t op = 0;
  uint64_t sequence = 0;
  uint64_t stop_generation = 0;
  uint32_t lease_ms = 0;
  std::string run;
  Status status = Status::Live;
  Fault error = Fault::None;
};
inline uint64_t ReadNumber(const Wire& wire, std::size_t offset, std::size_t width) {
  uint64_t value = 0;
  for (std::size_t i = 0; i < width; ++i) value = (value << 8) | wire[offset + i];
  return value;
}
inline void WriteNumber(Wire& wire, std::size_t offset, std::size_t width, uint64_t value) {
  for (std::size_t i = 0; i < width; ++i) {
    wire[offset + width - 1 - i] = static_cast<uint8_t>(value);
    value >>= 8;
  }
}
inline Fault DecodeRequest(const Wire& wire, Record& record) {
  if (wire[0] != 'B' || wire[1] != 'S' || wire[2] != 'C' || wire[3] != 'H' ||
      wire[4] != 1 || wire[6] || wire[7] || wire[29] || wire[30] || wire[31] ||
      wire[28] == 0 || wire[28] > 128) return Fault::Syntax;
  if (wire[5] < 1 || wire[5] > 5) return Fault::UnsupportedOp;
  for (std::size_t i = 0; i < 128; ++i) {
    uint8_t byte = wire[32 + i];
    if (i >= wire[28]) { if (byte) return Fault::Syntax; }
    else if (!((byte >= 'a' && byte <= 'z') || (byte >= 'A' && byte <= 'Z') ||
        (byte >= '0' && byte <= '9') || byte == '-' || byte == '_' || byte == '.')) return Fault::Syntax;
  }
  record.op = wire[5];
  record.sequence = ReadNumber(wire, 8, 8);
  record.stop_generation = ReadNumber(wire, 16, 8);
  record.lease_ms = static_cast<uint32_t>(ReadNumber(wire, 24, 4));
  record.run.assign(reinterpret_cast<const char*>(wire.data() + 32), wire[28]);
  return Fault::None;
}
inline Wire EncodeReply(const Record& record) {
  Wire wire{};
  wire[0] = 'B'; wire[1] = 'S'; wire[2] = 'C'; wire[3] = 'H'; wire[4] = 1;
  wire[5] = record.op;
  WriteNumber(wire, 8, 8, record.sequence);
  WriteNumber(wire, 16, 8, record.stop_generation);
  wire[28] = static_cast<uint8_t>(record.run.size());
  wire[29] = static_cast<uint8_t>(record.status);
  wire[30] = static_cast<uint8_t>(record.error);
  // Lease/reserved/padding/input-capability bytes stay zero. No powers exist.
  for (std::size_t i = 0; i < record.run.size(); ++i) wire[32 + i] = record.run[i];
  return wire;
}
}  // namespace bs_control
