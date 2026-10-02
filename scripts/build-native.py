#!/usr/bin/env python3
"""Build the owned native macOS shell against the acquired CEF tuple."""

import json
import hashlib
from pathlib import Path
import subprocess
import shutil
import tomllib

ROOT = Path(__file__).resolve().parent.parent
app = ROOT / "context/build/native/Bow Shock.app"
processes = subprocess.check_output(["/bin/ps", "-axww", "-o", "pid=,comm="], text=True)
for line in processes.splitlines():
    fields = line.strip().split(None, 1)
    if len(fields) == 2 and fields[1].startswith(str(app) + "/"):
        raise SystemExit(f"Close Bow Shock and its helpers before rebuilding the bundle (PID {fields[0]})")
manifest = json.loads((ROOT / "runtime/cef-macos-arm64.json").read_text())
if manifest["status"] != "acquired":
    raise SystemExit("acquire the pinned CEF runtime first: python3 scripts/cef-runtime.py acquire")
channel = tomllib.loads((ROOT / "rust-toolchain.toml").read_text())["toolchain"]["channel"]
commands = [
    ["cargo", f"+{channel}", "build", "--locked", "--release", "-p", "bow-shock-controller"],
    ["cmake", "-S", str(ROOT / "native/cef"), "-B", str(ROOT / "context/build/native"),
     "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release", f"-DCEF_ROOT={ROOT / manifest['distribution_dir']}"],
    ["cmake", "--build", str(ROOT / "context/build/native"), "--target", "bow_shock", "--parallel", "4"],
]
for command in commands:
    print("+ " + " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)

# Packaging runs on every invocation, including a controller/helper-only rebuild.
controller_source = ROOT / "target/release/bow-shock-controller"
controller_destination = app / "Contents/MacOS/bow-shock-controller"
shutil.copy2(controller_source, controller_destination)
components = [(controller_source, controller_destination)]
for name in ["bow-shock-native-control", "bow_shock_clock_probe"]:
    source = ROOT / "context/build/native" / name
    destination = app / "Contents/MacOS" / name
    shutil.copy2(source, destination)
    components.append((source, destination))
bundle_plists = [app / "Contents/Info.plist"]
for helper in (ROOT / "context/build/native/helpers").glob("*.app"):
    destination = app / "Contents/Frameworks" / helper.name
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(helper, destination, symlinks=True)
    components.append((helper / "Contents/MacOS" / helper.stem,
                       destination / "Contents/MacOS" / helper.stem))
    bundle_plists.append(destination / "Contents/Info.plist")
# Signing changes Mach-O bytes. Check the actual staged payload before signing.
for source, destination in components:
    with source.open("rb") as source_file, destination.open("rb") as destination_file:
        source_hash = hashlib.file_digest(source_file, "sha256").digest()
        destination_hash = hashlib.file_digest(destination_file, "sha256").digest()
    if source_hash != destination_hash:
        raise SystemExit(f"staged component differs from build: {destination.name}")
print(f"Staged {len(components)} matching controller/helper binaries", flush=True)
for plist in bundle_plists:
    subprocess.run(["/usr/bin/plutil", "-convert", "xml1", str(plist)], check=True)
# Sign the standalone owned executables explicitly; the outer resource seal
# and nested CEF bundles are verified afterward as one complete app.
for _, destination in components[:3]:
    subprocess.run(["codesign", "--force", "--sign", "-", str(destination)], check=True)
subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(app)], check=True)
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
for _, destination in components[:3]:
    subprocess.run(["codesign", "--verify", "--strict", str(destination)], check=True)
