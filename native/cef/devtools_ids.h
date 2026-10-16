#pragma once
#include <atomic>
#include <climits>
#include <cstdint>

// All native observers share a browser protocol command namespace. Never reuse
// an ID, including after an observer is closed or a browser window is replaced.
inline int OXNextDevToolsID() {
  static std::atomic<int64_t> next{2000000};
  int64_t value = next.fetch_add(1);
  return value > 0 && value <= INT_MAX ? static_cast<int>(value) : 0;
}
