#!/usr/bin/env python3
"""Inspect complete native/browser input archives; never infer intended-key errors."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import os
from pathlib import Path
import plistlib
import statistics


def read(path):
    with path.open("rb") as source:
        return plistlib.load(source)


def events(directory):
    session = read(directory / "session.bplist")
    if session.get("format") != "oxcart.input-recording" or session.get("version") != 1:
        raise ValueError("Unsupported input recording")
    expected = 1
    for path in sorted((directory / "events").glob("*.bplist")):
        chunk = read(path)
        rows = chunk.get("events", [])
        if (chunk.get("format") != "oxcart.input-events" or chunk.get("version") != 1
                or chunk.get("recording_id") != session["id"] or not rows
                or chunk.get("first_sequence") != expected
                or chunk.get("last_sequence") != rows[-1].get("sequence")):
            raise ValueError(f"Missing, reordered or foreign chunk: {path}")
        for row in rows:
            if row["sequence"] != expected:
                raise ValueError(f"Event sequence gap in {path}: expected {expected}")
            expected += 1
            yield row


def distribution(values):
    if not values:
        return {"count": 0}
    return {"count": len(values), "minimum": min(values), "median": statistics.median(values), "maximum": max(values)}


def inspect(directory):
    session = read(directory / "session.bplist")
    kinds, native, browser, scroll_targets = Counter(), Counter(), Counter(), Counter()
    held, holds, pending, errors = {}, [], {}, []
    contexts, disabled, released = set(), set(), set()
    repeats = unmatched_up = interrupted_down = clock_errors = overlaps = late_cancel = 0
    for row in events(directory):
        kind, fields = row["kind"], row["fields"]
        kinds[kind] += 1
        if kind == "native_focus" and not (fields.get("app_active") and fields.get("browser_window_key")):
            interrupted_down += len(held)
            held.clear()
        if kind == "native_input":
            event_type, timestamp = fields["type"], fields["native_timestamp_seconds"]
            native[event_type] += 1
            code = fields.get("key_code")
            if event_type == "key_down":
                if fields["repeat"]:
                    repeats += 1
                else:
                    interrupted_down += code in held
                    overlaps += bool(held)
                    held[code] = timestamp
            elif event_type == "key_up":
                press = held.pop(code, None)
                if press is None:
                    unmatched_up += 1
                elif timestamp < press:
                    clock_errors += 1
                else:
                    holds.append((timestamp - press) * 1000)
        if kind == "context_disabled":
            disabled.add(fields["context_id"])
        if kind == "context_released":
            released.add(fields["context_id"])
        if kind in ("observer_install_failed", "observer_conversion_failed", "context_unavailable", "renderer_terminated"):
            errors.append({"sequence": row["sequence"], "kind": kind, "fields": fields})
        if kind != "observer":
            continue
        observation = fields["observation"]
        context = fields["context_id"]
        observed_kind = observation["kind"]
        if observed_kind == "observer_started":
            contexts.add(context)
        elif observed_kind == "capture":
            browser[observation["type"]] += 1
            pending[(context, observation["event_id"])] = observation["default_prevented"]
            if observation["type"] == "scroll":
                scroll_targets[f'{context}:{observation["state"]["target"]["id"]}'] += 1
        elif observed_kind == "settled":
            identity = (context, observation["event_id"])
            # Each context/event has a single capture record; preserve missing cases.
            initial = pending.pop(identity, None)
            if initial is not None:
                late_cancel += observation["default_prevented"] and not initial
        elif observed_kind == "observer_error":
            errors.append({"sequence": row["sequence"], "kind": observed_kind, "fields": fields})
    return {
        "format": "oxcart.input-inspection", "version": 1,
        "created_at": datetime.now(timezone.utc), "recording_id": session["id"],
        "directory": str(directory.resolve()), "events": sum(kinds.values()), "kinds": dict(kinds),
        "native_types": dict(native), "browser_types": dict(browser),
        "observed_key_holds_ms": distribution(holds), "repeat_down_events": repeats,
        "key_down_while_another_held": overlaps, "unmatched_key_up": unmatched_up,
        "interrupted_key_down": interrupted_down, "unreleased_at_end": len(held),
        "negative_hold_timestamps": clock_errors, "later_cancellation_observed": late_cancel,
        "capture_without_settled_sample": len(pending), "instrumented_contexts": len(contexts),
        "contexts_without_disabled_or_released": sorted(contexts - disabled - released),
        "scroll_event_recipients": dict(scroll_targets), "observation_errors": errors,
        "limits": ["Receipt sequence is not causal order; native and browser clocks remain separate.",
                   "Paired holds exclude focus interruptions; they are observations, not a fitted profile.",
                   "No intended-key labels or conditional mistake probabilities are inferred.",
                   "No completeness claim for unsent renderer events or an unflushed crash tail."],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--report", type=Path, help="Save a new native binary-plist report; refuses overwrite.")
    options = parser.parse_args()
    report = inspect(options.directory.expanduser().resolve())
    if options.report:
        path = options.report.expanduser().resolve()
        with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as output:
            plistlib.dump(report, output, fmt=plistlib.FMT_BINARY, aware_datetime=True)
            output.flush()
            os.fsync(output.fileno())
    for key in ("recording_id", "events", "native_types", "browser_types", "observed_key_holds_ms",
                "instrumented_contexts", "capture_without_settled_sample", "observation_errors"):
        print(f"{key}: {report[key]}")


if __name__ == "__main__":
    main()
