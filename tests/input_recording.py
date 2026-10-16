#!/usr/bin/env python3
"""Direct native event/archive checks; never posts OS input or hosts a website."""
from pathlib import Path
import subprocess
import uuid
import runpy

ROOT = Path(__file__).resolve().parents[1]
executable = ROOT / "context/build/input-recording-test"
executable.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([
    "/usr/bin/clang++", "-std=c++20", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra", "-Werror",
    "-framework", "Cocoa", "-framework", "ApplicationServices",
    str(ROOT / "native/cef/extraction_workspace.mm"),
    str(ROOT / "native/cef/input_archive.mm"), str(ROOT / "native/cef/input_events.mm"),
    str(ROOT / "native/tests/input_archive_test.mm"), "-o", str(executable),
], check=True)
artifacts = ROOT / "context/build/input-checks" / str(uuid.uuid4())
artifacts.mkdir(parents=True)
subprocess.run([str(executable), str(artifacts)], check=True, timeout=30)
subprocess.run(["node", str(ROOT / "tests/input_observer.cjs")], check=True, timeout=30)
inspector = runpy.run_path(str(ROOT / "scripts/input-inspect.py"))
reports = [inspector["inspect"](path) for path in artifacts.iterdir() if (path / "session.bplist").is_file()]
assert sorted(report["events"] for report in reports) == [1, 5, 515]
episode = next(report for report in reports if report["events"] == 5)
assert abs(episode["observed_key_holds_ms"]["median"] - 70) < 0.001
assert episode["later_cancellation_observed"] == 1
assert episode["capture_without_settled_sample"] == 0
assert episode["native_types"]["scroll_wheel"] == 1
print(artifacts)
