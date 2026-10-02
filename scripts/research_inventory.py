#!/usr/bin/env python3
"""Render reference inventory and retrieval gaps from the acquisition ledger."""
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def cell(value):
    return str(value).replace('|', '\\|').replace('\n', ' ')


def section(path, marker, body):
    text = path.read_text()
    start = f'<!-- BEGIN {marker} -->'
    end = f'<!-- END {marker} -->'
    if text.count(start) != 1 or text.count(end) != 1:
        raise ValueError(f'{path.name}: expected one marker pair')
    before, remainder = text.split(start)
    _, after = remainder.split(end)
    path.write_text(before + start + '\n' + body + end + after)


def main():
    records = json.loads((ROOT / 'papers/acquisition.json').read_text())
    counts = Counter((r['kind'], r['status']) for r in records)
    inventory = (
        f"Current local inventory: **{counts['repository', 'acquired']} acquired "
        f"source collections, {counts['paper', 'acquired']} PDFs, and "
        f"{counts['documentation', 'acquired']} documentation/source snapshots**, "
        f"from {len(records)} recorded catalog entries. Some collections share an "
        "upstream repository. Unresolved entries are in "
        "[the shopping list](SHOPPING_LIST.md).\n\n"
        '| Source | Revision | Scope | Status | Local tree |\n'
        '| --- | --- | --- | --- | --- |\n'
    )
    gaps = '| Source | Status / retrieval limit |\n| --- | --- |\n'
    by_id = {r['id']: r for r in records}
    for record in sorted(records, key=lambda r: r['id']):
        key = record['id']
        url = record['source_url']
        if record['kind'] == 'repository':
            revision = record.get('revision', 'unresolved')[:12]
            scope = record.get('scope', 'not acquired')
            paths = record.get('selected_paths', [])
            if paths:
                scope += f' ({len(paths)} selected paths)'
            inventory += (
                f'| [{cell(key)}]({url}) | `{revision}` | {cell(scope)} | '
                f"{record['status']} | `{record.get('tree', 'not acquired')}` |\n"
            )
        if record['status'] != 'acquired':
            detail = record.get('error', record['status'])
            counterpart = by_id.get(key + '-reviewed')
            if counterpart and counterpart['status'] == 'acquired':
                detail += '; pinned reviewed counterpart acquired as ' + counterpart['id']
            gaps += f"| [{cell(record['title'])}]({url}) (`{key}`) | {cell(detail)} |\n"
    if all(r['status'] == 'acquired' for r in records):
        gaps += '| None | All recorded entries acquired |\n'
    section(ROOT / 'QUARANTINE.md', 'ACQUISITION INVENTORY', inventory)
    section(ROOT / 'SHOPPING_LIST.md', 'ACQUISITION GAPS', gaps)
    print(f'Rendered inventory/gaps for {len(records)} acquisition records.')


if __name__ == '__main__':
    main()
