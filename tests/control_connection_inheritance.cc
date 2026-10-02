// Direct process-entry descriptor/environment oracle, before any interpreter.
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>
extern char** environ;
int main() {
  if (!environ[0] || std::strcmp(environ[0], "LANG=C") || environ[1]) return 2;
  for (int fd = 3; fd < 256; ++fd)
    if (fcntl(fd, F_GETFD) != -1 || errno != EBADF) return 3;
  bool fenced = false;
  for (;;) {
    uint8_t wire[160]; std::size_t received = 0;
    while (received < sizeof(wire)) {
      ssize_t count = read(0, wire + received, sizeof(wire) - received);
      if (count <= 0) return 0;
      received += count;
    }
    if (wire[5] == 3) fenced = true;
    wire[5] |= 128; std::memset(wire + 24, 0, 4); wire[29] = fenced ? 2 : 1;
    if (write(1, wire, sizeof(wire)) != static_cast<ssize_t>(sizeof(wire))) return 4;
  }
}
