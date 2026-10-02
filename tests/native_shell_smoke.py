#!/usr/bin/env python3
"""Direct owned-page and native lifecycle oracle for the first macOS shell."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "context/build/native/Bow Shock.app/Contents/MacOS/Bow Shock"
MARKER = "Bow Shock native fixture alpha"


class Page(BaseHTTPRequestHandler):
    def do_GET(self):
        body = f"<!doctype html><title>{MARKER}</title><h1>{MARKER}</h1><p>Owned local page.</p>".encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


def main():
    if not APP.is_file():
        raise SystemExit("native smoke FAIL: owned Bow Shock application has not been built")
    server = ThreadingHTTPServer(("127.0.0.1", 0), Page)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix="bow-shock-native-") as temporary, \
                tempfile.TemporaryDirectory(prefix="sandbox-outside-", dir=ROOT / "context/runtime") as outside:
            folder = Path(temporary)
            result_path = folder / "result.json"
            marker_path = folder / "sandbox-sentinel"
            marker_path.write_text("owned nonsecret sandbox probe\n")
            outside_path = Path(outside) / "sandbox-sentinel"
            outside_path.write_text("owned nonsecret outside-temp sandbox probe\n")
            command = [str(APP), f"--bs-profile={folder / 'profile'}",
                       f"--bs-smoke-output={result_path}",
                       f"--bs-sandbox-probe={marker_path}",
                       f"--bs-sandbox-probe-outside={outside_path}",
                       f"--bs-url=http://127.0.0.1:{server.server_port}/alpha"]
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                stdout, stderr = process.communicate(timeout=8)
            except subprocess.TimeoutExpired:
                # Diagnose this exact owned-fixture process while it is alive.
                try:
                    subprocess.run(["/usr/bin/sample", str(process.pid), "1", "1", "-file",
                                    str(ROOT / "context/runtime/native-smoke-hang.sample")],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
                except (subprocess.TimeoutExpired, OSError):
                    pass
                try:
                    stdout, stderr = process.communicate(timeout=32)
                except subprocess.TimeoutExpired:
                    process.kill()
                    stdout, stderr = process.communicate()
            result = subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
            (ROOT / "context/runtime/native-smoke-app.stderr").write_bytes(result.stderr)
            if result.returncode != 0:
                failure_profile = ROOT / "context/runtime/native-failure-profile"
                if failure_profile.exists():
                    shutil.rmtree(failure_profile)
                if (folder / "profile").exists():
                    shutil.copytree(folder / "profile", failure_profile, symlinks=True)
                raise AssertionError(f"native app exited {result.returncode}: {result.stderr.decode(errors='replace')[-6000:]}")
            assert b"cache_path is invalid" not in result.stderr, result.stderr.decode(errors="replace")
            assert b"Unable to derive validation category for current process" not in result.stderr, result.stderr.decode(errors="replace")
            assert (folder / "profile/Default/Preferences").is_file(), "dedicated persistent profile missing"
            actual = json.loads(result_path.read_text())
            boot_id = str(uuid.UUID(subprocess.check_output(
                ["/usr/sbin/sysctl", "-n", "kern.bootsessionuuid"], text=True).strip())).upper()
            assert actual["clock_start"]["boot_id"] == boot_id, actual
            assert actual["clock_end"]["boot_id"] == boot_id, actual
            assert actual["clock_end"]["continuous_ns"] > actual["clock_start"]["continuous_ns"], actual
            assert actual["loaded_title"] == MARKER, actual
            assert actual["load_status"] == 200, actual
            assert actual["browser_created"] and actual["browser_closed"] and actual["cef_shutdown"], actual
            assert actual["native_window_visible"], actual
            assert actual["controller_initialized"] and actual["controller_stop_generation"] == 1, actual
            child_pid = actual["controller_pid"]
            assert child_pid > 0, actual
            try:
                os.kill(child_pid, 0)
            except ProcessLookupError:
                pass
            else:
                raise AssertionError(f"owned controller {child_pid} remains after native shutdown")
            probes = [json.loads(line[len("BS_SANDBOX "):]) for line in result.stderr.decode(errors="replace").splitlines() if line.startswith("BS_SANDBOX ")]
            assert any(p["role"] == "renderer" and p["sentinel_denied"] for p in probes), probes
            assert all(p["sentinel_denied"] for p in probes if p["role"] == "renderer"), probes
            assert all(p["outside_probe_present"] and p["outside_sentinel_denied"]
                       for p in probes if p["role"] == "renderer"), probes
            gpus = [p for p in probes if p["role"] == "gpu-process"]
            assert gpus and all(p["seatbelt_client"] and p["errno"] == 0
                                and p["outside_sentinel_denied"] for p in gpus), probes
            for subtype, policy in [("network.mojom.NetworkService", "network"),
                                    ("storage.mojom.StorageService", "service")]:
                services = [p for p in probes if p["utility_subtype"] == subtype]
                assert services and all(p["service_sandbox"] == policy and p["seatbelt_client"]
                                        and p["outside_sentinel_denied"] for p in services), probes
            notifications = [p for p in probes
                             if p["utility_subtype"] == "mac_notifications.mojom.MacNotificationProvider"]
            assert notifications and all(p["service_sandbox"] == "none" and not p["seatbelt_client"]
                                         and p["outside_errno"] == 0 for p in notifications), probes
            helper_pids = {p["pid"] for p in probes}
            deadline = time.monotonic() + 5
            while helper_pids:
                for pid in tuple(helper_pids):
                    try:
                        os.kill(pid, 0)
                    except ProcessLookupError:
                        helper_pids.remove(pid)
                if not helper_pids:
                    break
                assert time.monotonic() < deadline, f"owned CEF helpers remain: {helper_pids}"
                time.sleep(.05)
            print(json.dumps({"native_smoke": "pass", "result": actual, "sandbox_probes": probes}, indent=2))
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
