#include <fstream>
#include <iostream>
#include <string>
extern char** environ;

int main(int argc, const char* argv[]) {
  std::string database;
  for (int i = 1; i + 1 < argc; ++i)
    if (std::string(argv[i]) == "--table-db") database = argv[i + 1];
  if (database.empty()) return 2;
  std::ofstream launch(database + ".launch");
  for (int i = 1; i < argc; ++i) launch << "arg:" << argv[i] << '\n';
  for (char** entry = environ; *entry; ++entry) launch << "env:" << *entry << '\n';
  launch.close();
  std::string line, run;
  while (std::getline(std::cin, line)) {
    if (line.size() > 65536) return 3;
    const bool initialize = line.find("\"op\":\"initialize\"") != std::string::npos;
    const bool shutdown = line.find("\"op\":\"shutdown\"") != std::string::npos;
    if (initialize) {
      const auto start = line.find("\"run_id\":\"");
      if (start == std::string::npos) return 4;
      const auto first = start + 10;
      run = line.substr(first, line.find('"', first) - first);
    }
    std::cout << "{\"version\":1,\"op\":\""
              << (initialize ? "initialized" : shutdown ? "shutdown" : "pong")
              << "\",\"run_id\":\"" << run << '"';
    if (!initialize) {
      const auto start = line.find("\"id\":");
      if (start == std::string::npos) return 5;
      std::cout << ",\"id\":" << std::stoull(line.substr(start + 5));
    }
    std::cout << ",\"stop_generation\":0,\"active_powers\":[]}\n" << std::flush;
    if (shutdown) break;
  }
}
