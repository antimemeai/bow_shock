#include "include/cef_app.h"
#include "include/cef_sandbox_mac.h"
#include "include/wrapper/cef_library_loader.h"
#include "input_renderer.h"

#include <cerrno>
#include <cstdio>
#include <fcntl.h>
#include <string>
#include <unistd.h>

static std::string ProbeToken(const std::string& value) {
  if (value.size() > 128) return "unknown";
  for (unsigned char c : value) {
    if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') || c == '.' || c == '_' || c == '-'))
      return "unknown";
  }
  return value;
}

int main(int argc, char** argv) {
  CefScopedSandboxContext sandbox;
  if (!sandbox.Initialize(argc, argv)) return 1;

  // Test-only direct file-access oracle, after seatbelt setup and before CEF.
  std::string probe;
  std::string outsideProbe;
  std::string role = "utility";
  std::string utilitySubtype;
  std::string serviceSandbox;
  bool seatbeltClient = false;
  for (int i = 1; i < argc; ++i) {
    std::string argument(argv[i]);
    const std::string prefix = "--bs-sandbox-probe=";
    if (argument.rfind(prefix, 0) == 0) probe = argument.substr(prefix.size());
    const std::string outsidePrefix = "--bs-sandbox-probe-outside=";
    if (argument.rfind(outsidePrefix, 0) == 0) outsideProbe = argument.substr(outsidePrefix.size());
    if (argument == "--seatbelt-client" || argument.rfind("--seatbelt-client=", 0) == 0)
      seatbeltClient = true;
    if (argument.rfind("--type=", 0) == 0) role = ProbeToken(argument.substr(7));
    const std::string subtypePrefix = "--utility-sub-type=";
    const std::string sandboxPrefix = "--service-sandbox-type=";
    if (argument.rfind(subtypePrefix, 0) == 0)
      utilitySubtype = ProbeToken(argument.substr(subtypePrefix.size()));
    if (argument.rfind(sandboxPrefix, 0) == 0)
      serviceSandbox = ProbeToken(argument.substr(sandboxPrefix.size()));
  }
  if (!probe.empty()) {
    int fd = open(probe.c_str(), O_RDONLY | O_CLOEXEC);
    int error = fd == -1 ? errno : 0;
    if (fd != -1) close(fd);
    bool denied = error == EPERM || error == EACCES;
    int outsideError = 0;
    if (!outsideProbe.empty()) {
      int outsideFd = open(outsideProbe.c_str(), O_RDONLY | O_CLOEXEC);
      outsideError = outsideFd == -1 ? errno : 0;
      if (outsideFd != -1) close(outsideFd);
    }
    bool outsideDenied = outsideError == EPERM || outsideError == EACCES;
    // Never read or disclose marker content/path.
    fprintf(stderr, "BS_SANDBOX {\"role\":\"%s\",\"utility_subtype\":\"%s\","
            "\"service_sandbox\":\"%s\",\"seatbelt_client\":%s,\"uid\":%u,\"euid\":%u,"
            "\"pid\":%d,\"sentinel_denied\":%s,\"errno\":%d,"
            "\"outside_probe_present\":%s,\"outside_sentinel_denied\":%s,\"outside_errno\":%d}\n",
            role.c_str(), utilitySubtype.c_str(), serviceSandbox.c_str(),
            seatbeltClient ? "true" : "false", getuid(), geteuid(), getpid(),
            denied ? "true" : "false", error, outsideProbe.empty() ? "false" : "true",
            outsideDenied ? "true" : "false", outsideError);
  }

  CefScopedLibraryLoader loader;
  if (!loader.LoadInHelper()) return 1;
  return CefExecuteProcess(CefMainArgs(argc, argv), OXInputRendererApp(), nullptr);
}
