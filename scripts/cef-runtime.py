#!/usr/bin/env python3
"""Acquire/restore the pinned adopted CEF distribution; never run its examples."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "runtime/cef-macos-arm64.json"
STORE = ROOT / "context/runtime"


def digest(path, algorithm):
    value = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def acquire():
    manifest = json.loads(MANIFEST.read_text())
    archive = STORE / "archives" / manifest["archive"]["name"]
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        partial = archive.with_name(archive.name + ".part")
        subprocess.run([
            "curl", "--fail", "--location", "--retry", "3", "--connect-timeout", "30",
            "--max-time", "600", "--continue-at", "-", "--output", str(partial),
            manifest["download_url"],
        ], check=True)
        if partial.stat().st_size != manifest["archive"]["size"]:
            raise SystemExit("CEF archive size differs from pinned publisher metadata")
        if digest(partial, "sha1") != manifest["archive"]["sha1"]:
            raise SystemExit("CEF archive SHA-1 differs from pinned publisher metadata")
        partial.rename(archive)
    if archive.stat().st_size != manifest["archive"]["size"] or digest(archive, "sha1") != manifest["archive"]["sha1"]:
        raise SystemExit("preserved CEF archive fails publisher integrity comparison")
    sha256 = digest(archive, "sha256")
    if manifest["local_sha256"] is not None and manifest["local_sha256"] != sha256:
        raise SystemExit("preserved CEF archive differs from recorded local SHA-256")
    destination = STORE / "distributions"
    folder_name = archive.name.removesuffix(".tar.bz2")
    tree = destination / folder_name
    if not tree.exists():
        destination.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive, "r:bz2") as source:
            members = source.getmembers()
            for member in members:
                parts = Path(member.name).parts
                if not parts or parts[0] != folder_name or ".." in parts or member.name.startswith("/"):
                    raise SystemExit("archive member escapes the expected distribution root")
                if member.isdev() or member.isfifo() or ".git" in parts:
                    raise SystemExit("unexpected archive member type or nested Git metadata")
            source.extractall(destination, members=[m for m in members if Path(m.name).name != ".DS_Store"], filter="data")
    if not (tree / "include/cef_version.h").is_file():
        raise SystemExit("CEF extraction is incomplete; move it aside and restore from the preserved archive")
    manifest["local_sha256"] = sha256
    manifest["distribution_dir"] = str(tree.relative_to(ROOT))
    manifest["status"] = "acquired"
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print(tree)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["acquire"])
    parser.parse_args()
    acquire()
