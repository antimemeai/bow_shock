#!/usr/bin/env python3
"""Save a dated metrics snapshot from the native extraction workspace."""
import argparse
import collections
import datetime
import math
import os
from pathlib import Path
import plistlib
import uuid


def collect(workspace):
    errors = []

    def read(path):
        try:
            with path.open('rb') as stream:
                value = plistlib.load(stream)
            if not isinstance(value, dict):
                raise ValueError('Expected a native dictionary')
            return value
        except (OSError, ValueError, plistlib.InvalidFileException, OverflowError) as error:
            errors.append({'path': str(path), 'error': str(error)})
            return {}

    events = []
    files = sorted((workspace / 'events').glob('*.bplist'))
    for path in files:
        event = read(path)
        if event:
            events.append(event)
    kinds = collections.Counter(event.get('kind', 'unknown') for event in events)
    by_attempt = collections.defaultdict(list)
    readings = {}
    for event in events:
        if event.get('attempt_id'):
            by_attempt[event['attempt_id']].append(event)
        reference = event.get('reading')
        if isinstance(reference, dict) and reference.get('capture_id'):
            readings[reference['capture_id']] = reference

    def interval(start, end):
        if not start or not end:
            return {'available': False, 'reason': 'stage event absent'}
        if start.get('run_id') != end.get('run_id'):
            return {'available': False, 'reason': 'different host runs'}
        first, last = start.get('uptime_seconds'), end.get('uptime_seconds')
        if not all(isinstance(t, (float, int)) and not isinstance(t, bool) and math.isfinite(t) for t in (first, last)):
            return {'available': False, 'reason': 'invalid uptime'}
        if last < first:
            return {'available': False, 'reason': 'uptime decreased'}
        return {'available': True, 'seconds': last - first}

    attempts = []
    root = workspace / 'attempts'
    for directory in sorted(root.iterdir()) if root.exists() else []:
        if not directory.is_dir():
            continue
        manifest = read(directory / 'attempt.bplist')
        if not manifest:
            continue
        identity = manifest.get('id', directory.name)
        own = sorted(by_attempt[identity], key=lambda event: event.get('sequence', 0))

        def first(kind):
            return next((event for event in own if event.get('kind') == kind), {})

        start, model, rendered = first('attempt_started'), first('model_finished'), first('preview_rendered')
        item = {'id': identity, 'directory': str(directory), 'phase': manifest.get('phase', 'unknown'),
                'visit_id': manifest.get('visit_id', 'unknown'), 'recipe_id': manifest.get('recipe_id', 'generic'),
                'model_outcome': model.get('outcome', 'no completion recorded'),
                'cancel_requested': bool(first('cancel_requested')),
                'connection_failed': bool(first('connection_failed')),
                'model_failed': bool(first('model_failed')),
                'submission_present': (directory / 'received.bplist').is_file(),
                'error_note_present': (directory / 'validation-error.txt').is_file() or (directory / 'outcome-note.txt').is_file(),
                'validation_error_present': model.get('outcome') == 'completed' and (directory / 'validation-error.txt').is_file(),
                'preview_present': (directory / 'preview.txt').is_file(),
                'attempt_to_model_finish': interval(start, model),
                'model_finish_to_preview_save': interval(model, rendered),
                'recipe_activations_from_attempt': sum(event.get('source_attempt_id') == identity
                                                     and event.get('kind') == 'recipe_activated' for event in events)}
        if item['submission_present']:
            document = read(directory / 'received.bplist')
            if document.get('format') == 'oxcart.extraction':
                assessment = document.get('assessment')
                item['bot_assessment'] = assessment if isinstance(assessment, str) else 'invalid/not recorded'
                issues = document.get('issues')
                item['reported_issues_available'] = isinstance(issues, list)
                if isinstance(issues, list):
                    item['reported_issues'] = len(issues)
                blocks = document.get('blocks', [])
                if isinstance(blocks, list):
                    item['block_counts'] = dict(collections.Counter(
                        block['kind'] if isinstance(block.get('kind'), str) else 'invalid'
                        for block in blocks if isinstance(block, dict)))
        preview = directory / 'preview.txt'
        if preview.is_file():
            item['preview_text_bytes'] = preview.stat().st_size
        attempts.append(item)

    sources = []
    for identity, reference in sorted(readings.items()):
        locator = reference.get('reading', {})
        path = locator.get('manifest_path')
        if not path:
            errors.append({'path': str(workspace), 'error': f'Reading {identity} has no manifest locator'})
            continue
        manifest = read(Path(path))
        if not manifest:
            continue
        if manifest.get('capture_id') != identity:
            errors.append({'path': path, 'error': 'Reading identity differs from the visit reference'})
            continue
        sources.append({'capture_id': identity, 'manifest_path': path,
                        'documents': len(manifest.get('documents', [])),
                        'rendered_text_bytes': sum(doc.get('text_bytes', 0) for doc in manifest.get('documents', [])),
                        'coverage': manifest.get('coverage', [])})

    counts = {'visits_opened': kinds['visit_opened'], 'reading_events': kinds['reading_added'],
              'unique_readings': len(sources), 'reading_failures': kinds['reading_failed'],
              'readable_attempts': len(attempts),
              'attempt_phases': dict(collections.Counter(item['phase'] for item in attempts)),
              'model_outcomes': dict(collections.Counter(item['model_outcome'] for item in attempts)),
              'command_rejections': kinds['command_rejected'],
              'validation_errors': sum(item['validation_error_present'] for item in attempts),
              'attempts_with_previews': sum(item['preview_present'] for item in attempts),
              'cancel_requests': kinds['cancel_requested'], 'recipe_activations': kinds['recipe_activated'],
              'source_rendered_text_bytes': sum(item['rendered_text_bytes'] for item in sources)}
    return {'format': 'oxcart.metrics', 'version': 1, 'workspace': str(workspace),
            'generated_at': datetime.datetime.now(datetime.UTC).replace(tzinfo=None), 'time_zone': 'UTC',
            'source_event_files': [str(path) for path in files], 'event_counts': dict(kinds),
            'counts': counts, 'attempts': attempts, 'readings': sources, 'read_errors': errors,
            'definitions': {
                'durations': 'Native host uptime differences within the same recorded run; missing/incomparable intervals stay unavailable.',
                'source_rendered_text_bytes': 'Bytes in saved document text views, not full DOM/blob size or network bytes.',
                'model_outcome': 'Engine turn outcome, or rejected for a command that received no admitted final; separate from extraction validity and bot assessment.',
                'recipe_activations': 'Recorded recipe activation operations, not a semantic completeness score.',
                'counts': 'Observed events/artifacts; no extraction precision, recall or coverage percentage is inferred.'}}


def summary(report):
    counts = report['counts']
    lines = ['Oxcart extraction metrics', str(report['generated_at']) + ' UTC', report['workspace'], '',
             f"Visits: {counts['visits_opened']}; saved readings: {counts['unique_readings']}; reading failures: {counts['reading_failures']}",
             f"Source text bytes: {counts['source_rendered_text_bytes']}",
             f"Attempts: {counts['readable_attempts']}; phases: {counts['attempt_phases']}",
             f"Model outcomes: {counts['model_outcomes']}",
             f"Validation errors: {counts['validation_errors']}; previews: {counts['attempts_with_previews']}; cancel requests: {counts['cancel_requests']}",
             f"Recipe activations: {counts['recipe_activations']}", '', 'Attempts']
    for item in report['attempts']:
        model = item['attempt_to_model_finish']
        elapsed = f"{model['seconds']:.3f}s" if model['available'] else model['reason']
        lines.append(f"{item['id']} | {item['phase']} | {item['model_outcome']} | bot={item.get('bot_assessment', 'not recorded')} | {elapsed}")
    lines.extend(['', f"Read errors: {len(report['read_errors'])}"])
    for error in report['read_errors']:
        lines.append(f"{error['path']}: {error['error']}")
    lines.extend(['', 'Counts and bot assessments do not establish collection completeness.'])
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('workspace', type=Path, help='The data directory’s extraction/ folder')
    args = parser.parse_args()
    workspace = args.workspace.expanduser().resolve()
    if not workspace.is_dir():
        parser.error('Choose an existing extraction workspace.')
    report = collect(workspace)
    directory = workspace / 'reports' / str(uuid.uuid4())
    directory.mkdir(parents=True, exist_ok=False, mode=0o700)
    rendered = summary(report)
    for name, content in [('metrics.bplist', plistlib.dumps(report, fmt=plistlib.FMT_BINARY)),
                          ('metrics.txt', rendered.encode('utf8'))]:
        descriptor = os.open(directory / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
    print(rendered, end='')
    print('Saved metrics: ' + str(directory))


if __name__ == '__main__':
    main()
