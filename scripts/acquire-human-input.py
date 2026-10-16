#!/usr/bin/env python3
"""Retain original human-input research artifacts; never execute reference code."""
import argparse
import concurrent.futures
import datetime
import hashlib
from pathlib import Path
import plistlib
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "quarantine/human-input"
LEDGER = STORE / "acquisition.bplist"
SOURCES = {
    "aalto-keystrokes": (
        "https://userinterfaces.aalto.fi/136Mkeystrokes/data/Keystrokes.zip", "Keystrokes.zip"),
    "aalto-paper": (
        "https://userinterfaces.aalto.fi/136Mkeystrokes/resources/chi-18-analysis.pdf", "dhakal-2018.pdf"),
    "aalto-capture": (
        "https://codeload.github.com/aalto-ui/136m-keystrokes/tar.gz/98dcee94dc6c0464b35e8ca43d60e1b225cc621f",
        "aalto-capture-98dcee94.tar.gz"),
    "balabit-mouse": (
        "https://codeload.github.com/balabit/Mouse-Dynamics-Challenge/tar.gz/d00d6f779254a2a917deeab4a5b7a9e8643bd91e",
        "balabit-d00d6f77.tar.gz"),
    "error-metrics": ("https://www.yorku.ca/mack/chi03.pdf", "soukoreff-mackenzie-2003.pdf"),
    "character-errors": (
        "https://www.yorku.ca/mack/nordichi2002-shortpaper.pdf", "mackenzie-soukoreff-2002.pdf"),
    "ui-events": ("https://www.w3.org/TR/2026/WD-uievents-20260221/", "ui-events-20260221.html"),
    "pointer-events": ("https://www.w3.org/TR/pointerevents3/", "pointer-events.html"),
    "input-events": (
        "https://www.w3.org/TR/2026/WD-input-events-2-20261015/", "input-events-2-20261015.html"),
}


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def acquire(identity, source, prior):
    url, filename = source
    destination = STORE / filename
    expected = (prior.get("sha256") or prior.get("expected_sha256")) if prior else None
    if destination.exists():
        sha = digest(destination)
        if not expected or sha != expected:
            raise ValueError(f"Existing artifact has no matching ledger entry: {destination}")
        print(f"Retained {identity}: {destination.stat().st_size} bytes", flush=True)
        return prior
    partial = STORE / f"{filename}.{uuid.uuid4()}.partial"
    record = {"id": identity, "source_url": url, "path": str(destination.relative_to(ROOT)),
              "acquired_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    if expected:
        record["expected_sha256"] = expected
    sha = hashlib.sha256()
    count = 0
    request = urllib.request.Request(url, headers={"User-Agent": "Oxcart-human-input-source-study/1"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response, partial.open("xb") as output:
            record["resolved_url"] = response.url
            length = response.headers.get("Content-Length")
            for chunk in iter(lambda: response.read(1024 * 1024), b""):
                output.write(chunk)
                sha.update(chunk)
                count += len(chunk)
            if length is not None and count != int(length):
                raise ValueError(f"Incomplete transfer: {count} of {length} bytes")
        if expected and sha.hexdigest() != expected:
            raise ValueError("Source changed; original bytes retained in .partial, not substituted")
        # This utility has one owner. Never replace an existing retained artifact.
        destination.hardlink_to(partial)
        partial.unlink()
        record.update(status="acquired", bytes=count, sha256=sha.hexdigest())
        print(f"Acquired {identity}: {count} bytes {record['sha256']}", flush=True)
    except Exception as error:
        record.update(status="failed", error=f"{type(error).__name__}: {error}",
                      partial_path=str(partial.relative_to(ROOT)), bytes=count)
        print(f"Failed {identity}: {record['error']}", flush=True)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", nargs="*", help="Source IDs; omit for all artifacts")
    arguments = parser.parse_args()
    chosen = arguments.sources or list(SOURCES)
    unknown = set(chosen) - SOURCES.keys()
    if unknown:
        parser.error(f"Unknown source IDs: {', '.join(sorted(unknown))}")
    STORE.mkdir(parents=True, exist_ok=True)
    history = STORE / "acquisitions"
    history.mkdir(exist_ok=True)
    prior = plistlib.loads(LEDGER.read_bytes()) if LEDGER.exists() else {}
    records = dict(prior)
    failed = False
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        pending = {pool.submit(acquire, key, SOURCES[key], prior.get(key)): key for key in chosen}
        for future in concurrent.futures.as_completed(pending):
            key = pending[future]
            try:
                records[key] = future.result()
                failed |= records[key]["status"] != "acquired"
                event = history / f"{uuid.uuid4()}.bplist"
                with event.open("xb") as output:
                    plistlib.dump(records[key], output, fmt=plistlib.FMT_BINARY)
            except Exception as error:
                failed = True
                print(f"Failed {key}: {error}", flush=True)
            # Keep completed entries even if another large transfer fails later.
            temporary = STORE / f"ledger-{uuid.uuid4()}.partial"
            temporary.write_bytes(plistlib.dumps(records, fmt=plistlib.FMT_BINARY))
            temporary.replace(LEDGER)
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
