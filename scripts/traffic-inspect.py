#!/usr/bin/env python3
"""Inspect Oxcart's native traffic archive or reconstruct an exact retained body."""
import argparse
import collections
import os
from pathlib import Path
import plistlib
import pprint
import shutil


def read(path):
    with path.open('rb') as source:
        return plistlib.load(source)


def reconstruct(session, manifest, output, allow_partial=False):
    value = read(manifest)
    outcome = value.get('outcome', 'unknown')
    if outcome != 'completed' and not allow_partial:
        raise ValueError(f'Body outcome is {outcome}; use --allow-partial to export retained partial bytes')
    if value.get('fallback_body', {}).get('available'):
        chunks = [value['fallback_body']]
    elif value.get('stream_available', True) or (allow_partial and value.get('chunks')):
        chunks = value['chunks']
    else:
        raise ValueError(f"Body unavailable: {value.get('fallback_error') or value.get('error')}")
    sources = []
    total = 0
    for chunk in chunks:
        if not chunk.get('available'):
            raise ValueError(f'Unavailable chunk: {chunk}')
        path = (session / chunk['path']).resolve()
        if not path.is_relative_to(session.resolve()):
            raise ValueError('Body blob path leaves this traffic session')
        if not path.is_file() or path.stat().st_size != chunk['bytes']:
            raise ValueError(f'Missing or changed body chunk: {path}')
        sources.append(path)
        total += chunk['bytes']
    # No silent overwrite. A failed export keeps its partial bytes for inspection.
    with os.fdopen(os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC, 0o600), 'wb') as destination:
        for path in sources:
            with path.open('rb') as source:
                shutil.copyfileobj(source, destination, length=1024 * 1024)
        destination.flush()
        os.fsync(destination.fileno())
    return {'output': str(output), 'bytes': total, 'outcome': outcome,
            'representation': value.get('representation', 'see source chunks')}


def inspect(session):
    kinds = collections.Counter()
    commands = collections.Counter()
    accepted = collections.Counter()
    rejected = collections.Counter()
    errors = []
    for path in sorted((session / 'events').glob('*.bplist')):
        try:
            event = read(path)
            kind = event['kind']
            kinds[kind] += 1
            if kind == 'command':
                commands[event['fields']['method']] += 1
            if kind == 'decision_result':
                target = accepted if event['fields']['success'] else rejected
                target[event['fields']['method']] += 1
        except (OSError, ValueError, KeyError, TypeError) as error:
            errors.append({'path': str(path), 'error': str(error)})
    return {'directory': str(session), 'session': read(session / 'session.bplist'),
            'events': dict(kinds), 'commands': dict(commands),
            'accepted_decisions': dict(accepted), 'rejected_decisions': dict(rejected),
            'body_manifests': len(list((session / 'bodies').glob('*.bplist'))),
            'blob_bytes': sum(path.stat().st_size for path in (session / 'blobs').glob('*.bin')),
            'read_errors': errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('session', type=Path, help='one traffic/<UUID> directory')
    parser.add_argument('--event', type=Path, help='inspect one native event/manifest (relative to session)')
    parser.add_argument('--body', type=Path, help='reconstruct a body manifest (relative to session)')
    parser.add_argument('--output', type=Path, help='new file for reconstructed bytes')
    parser.add_argument('--allow-partial', action='store_true')
    args = parser.parse_args()
    try:
        session = args.session.expanduser().resolve()
        if args.body:
            if not args.output:
                parser.error('--body requires --output')
            value = reconstruct(session, session / args.body, args.output.expanduser(), args.allow_partial)
        elif args.event:
            value = read(session / args.event)
        else:
            value = inspect(session)
        pprint.pp(value, sort_dicts=False)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'traffic-inspect: {error}\n')


if __name__ == '__main__':
    main()
