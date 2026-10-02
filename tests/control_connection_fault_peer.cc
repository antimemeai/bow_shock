// Original test-only POSIX peer; independent fixed160-byte encoding, no codec.
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <poll.h>
#include <signal.h>
#include <string>
#include <unistd.h>

namespace {
bool Marker(const std::string& file, const std::string& value) {
  std::ofstream output(file); output << value; return static_cast<bool>(output);
}
bool Write(const uint8_t* bytes, std::size_t length) {
  std::size_t written = 0;
  while (written < length) {
    ssize_t count = write(1, bytes + written, length - written);
    if (count < 0 && errno == EINTR) continue;
    if (count <= 0) return false;
    written += count;
  }
  return true;
}
void Stall() { for (;;) pause(); }
}
int main(int argc, char** argv) {
  if (argc != 1) return 2;
  std::string base = argv[0], mode;
  std::ifstream configuration(base + ".mode"); configuration >> mode;
  if (!configuration) return 3;
  signal(SIGTERM, SIG_IGN);
  if (!Marker(base + ".pid", std::to_string(getpid())) ||
      !Marker(base + ".ready", "ready")) return 4;
  if (mode == "stall") Stall();
  bool fenced = false;
  for (;;) {
    // Idle peer exits only after the real positive main callback releases it.
    // Before release it services heartbeat, avoiding a presentation-time race.
    if (mode == "idle") {
      if (access((base + ".release").c_str(), F_OK) == 0) return 0;
      pollfd input{0, POLLIN, 0};
      int ready = poll(&input, 1, 10);
      if (ready < 0 && errno == EINTR) continue;
      if (ready < 0) return 5;
      if (!ready) continue;
    }
    uint8_t wire[160]; std::size_t received = 0;
    while (received < sizeof(wire)) {
      ssize_t count = read(0, wire + received, sizeof(wire) - received);
      if (count < 0 && errno == EINTR) continue;
      if (count <= 0) return 0;
      received += count;
    }
    if (!Marker(base + ".seen", "request")) return 6;
    if (wire[5] == 3) fenced = true;
    wire[5] |= 128; std::memset(wire + 24, 0, 4); wire[29] = fenced ? 2 : 1;
    if (mode == "capability") wire[31] = 1;
    if (mode == "fence") wire[23] ^= 1;
    if (mode == "eof") { close(1); Marker(base + ".sent", "eof"); Stall(); }
    if (mode == "flood") {
      uint8_t flood[32768]; std::memset(flood, 'x', sizeof(flood));
      Marker(base + ".sent", "flood"); Write(flood, sizeof(flood)); Stall();
    }
    const std::size_t bytes = mode == "partial" ? 159 : 160;
    if (!Write(wire, bytes) || !Marker(base + ".sent", std::to_string(bytes))) return 7;
    if (mode == "partial") Stall();
  }
}
