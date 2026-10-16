#!/usr/bin/env python3
"""Inspect archived human traces; this is corpus inspection, not model fitting."""
import collections
import csv
import io
from pathlib import Path
import plistlib
import re
import statistics
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "quarantine/human-input"


def distribution(values):
    if not values:
        return {"count": 0}
    quantiles = statistics.quantiles(values, n=100, method="inclusive") if len(values) > 1 else values * 99
    return {"count": len(values), "min": min(values), "p10": quantiles[9],
            "median": statistics.median(values), "p90": quantiles[89], "max": max(values)}


def inspect_mouse():
    users = set()
    states, buttons = collections.Counter(), collections.Counter()
    rows = sessions = equal = decreasing = 0
    with tarfile.open(STORE / "balabit-d00d6f77.tar.gz") as archive:
        for member in archive:
            if not member.isfile() or "/training_files/" not in member.name:
                continue
            sessions += 1
            users.add(member.name.split("/training_files/")[1].split("/")[0])
            prior = None
            for row in csv.DictReader(io.TextIOWrapper(archive.extractfile(member), encoding="utf8")):
                rows += 1
                states[row["state"]] += 1
                buttons[row["button"]] += 1
                timestamp = float(row["client timestamp"])
                if prior is not None:
                    equal += timestamp == prior
                    decreasing += timestamp < prior
                prior = timestamp
    return {"scope": "all training files, no test files", "users": len(users), "sessions": sessions,
            "rows": rows, "states": dict(states), "buttons": dict(buttons),
            "equal_adjacent_client_timestamps": equal, "decreasing_client_timestamps": decreasing}


def inspect_typing():
    duration, intervals = [], []
    rows = invalid = rollover = pairs = backspace = differing = sentences = 0
    with zipfile.ZipFile(STORE / "Keystrokes.zip") as archive:
        members = sorted((name for name in archive.namelist() if re.search(r"/\d+_keystrokes\.txt$", name)),
                         key=lambda name: int(name.rsplit("/", 1)[1].split("_", 1)[0]))
        # A deterministic inspection sample. The whole original archive is retained.
        sample = members[:100]
        for name in sample:
            sections = collections.defaultdict(list)
            with archive.open(name) as raw:
                for row in csv.DictReader(io.TextIOWrapper(raw, encoding="utf8"), delimiter="\t"):
                    rows += 1
                    if None in row or any(value is None for value in row.values()):
                        invalid += 1
                        continue
                    try:
                        press, release = int(row["PRESS_TIME"]), int(row["RELEASE_TIME"])
                        keycode = int(row["KEYCODE"])
                    except ValueError:
                        invalid += 1
                        continue
                    if release < press:
                        invalid += 1
                        continue
                    duration.append(release - press)
                    backspace += keycode == 8
                    sections[row["TEST_SECTION_ID"]].append((press, release, row))
            for section in sections.values():
                sentences += 1
                differing += section[0][2]["SENTENCE"] != section[0][2]["USER_INPUT"]
                # Derived press-order view; raw export order remains untouched.
                printable = sorted((event for event in section if len(event[2]["LETTER"]) == 1), key=lambda e: e[0])
                for first, second in zip(printable, printable[1:]):
                    pairs += 1
                    intervals.append(second[0] - first[0])
                    rollover += second[0] < first[1]
    return {"scope": "first 100 numerically ordered participant files; not a calibration sample",
            "archive_participant_files": len(members), "sample_members": sample,
            "rows": rows, "invalid_rows": invalid, "sentence_sections": sentences,
            "final_text_differs_from_prompt_sections": differing, "backspace_rows": backspace,
            "all_valid_key_hold_ms": distribution(duration),
            "consecutive_printable_down_to_down_ms": distribution(intervals),
            "printable_pairs": pairs, "printable_rollover_pairs": rollover,
            "error_confusion_matrix": "not fitted; requires correction/selection-aware alignment and uncertainty"}


def main():
    ledger = plistlib.loads((STORE / "acquisition.bplist").read_bytes())
    result = {"format": "oxcart.human-input-inspection", "version": 1,
              "archive_sha256": {key: ledger[key]["sha256"] for key in ["aalto-keystrokes", "balabit-mouse"]},
              "typing": inspect_typing(), "mouse": inspect_mouse()}
    path = ROOT / "context/human-input-study/inspection.bplist"
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        # Keep each inspection; the short locator is only a derived convenience.
        import uuid
        path = path.with_name(f"inspection-{uuid.uuid4()}.bplist")
    with path.open("xb") as output:
        plistlib.dump(result, output, fmt=plistlib.FMT_BINARY)
    print(path)
    for key in ["typing", "mouse"]:
        print(key, {k: v for k, v in result[key].items() if k != "sample_members"})


if __name__ == "__main__":
    main()
