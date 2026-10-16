#!/usr/bin/env python3
"""Compile/run the native CDP projection oracle; no browser fixtures or server."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "context/build/native"
cache = (BUILD / "CMakeCache.txt").read_text()
cef = next(line.split("=", 1)[1] for line in cache.splitlines() if line.startswith("CEF_ROOT:"))
output = ROOT / "context/build/live-observation-probe"
subprocess.run([
    "/usr/bin/clang++", "-std=c++20", "-fobjc-arc", "-fobjc-exceptions",
    "-DCEF_API_VERSION=15400", "-DCEF_USE_SANDBOX", "-isystem", cef,
    "-Wall", "-Wextra", "-Werror", "-Wno-unused-function",
    str(ROOT / "tests/live_observation_probe.mm"),
    str(ROOT / "native/cef/reading_archive.mm"),
    str(BUILD / "cef_wrapper/libcef_dll_wrapper.a"),
    "-framework", "Foundation", "-framework", "Cocoa", "-o", str(output),
], check=True, cwd=ROOT)
subprocess.run([str(output)], check=True, cwd=ROOT)
