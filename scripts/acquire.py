#!/usr/bin/env python3
"""Acquire the research catalogs without installing or executing upstream code."""
import argparse
import concurrent.futures
import configparser
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import urllib.parse
import zipfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / 'papers/acquisition.json'
USER_AGENT = 'bow-shock-research/1.0'


def fetch(url, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    temporary = destination.with_suffix(destination.suffix + '.part')
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            with temporary.open('wb') as output:
                shutil.copyfileobj(response, output)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def identity(path, expected=None):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    result = {'path': str(path.relative_to(ROOT)), 'bytes': path.stat().st_size,
              'sha256': digest.hexdigest()}
    if expected and expected['path'] == result['path'] and expected['sha256'] != result['sha256']:
        raise ValueError(f'cached artifact changed: {result["path"]}')
    return result


def clean_path(name):
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts:
        raise ValueError(f'unsafe archive path: {name}')
    if any(part in {'.git', '.DS_Store', '__MACOSX', '__pycache__', '.entire', 'node_modules', '.venv'}
           or part.startswith('._') for part in path.parts):
        return None
    return path


def extract(archive, target, selected, rebuild=False):
    """Install a fresh tree atomically; preserve files/modes and confined links."""
    if target.exists() and not rebuild:
        missing = [p for p in selected if not (target / p).exists()]
        if missing:
            raise ValueError(f'existing tree is missing selected paths: {missing}')
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='ingest-', dir=target.parent))
    try:
        if archive.suffix == '.zip':
            with zipfile.ZipFile(archive) as source:
                for member in source.infolist():
                    relative = clean_path(member.filename)
                    if relative is None or member.is_dir():
                        continue
                    output = temporary / relative
                    output.parent.mkdir(parents=True, exist_ok=True)
                    output.write_bytes(source.read(member))
        else:
            with tarfile.open(archive, 'r:gz') as source:
                for member in source:
                    parts = PurePosixPath(member.name).parts[1:]
                    if not parts:
                        continue
                    relative = clean_path(str(PurePosixPath(*parts)))
                    if relative is None:
                        continue
                    if selected and not any(str(relative) == p or
                            str(relative).startswith(p.rstrip('/') + '/')
                            for p in selected):
                        continue
                    member.name = str(relative)
                    # Python's data filter rejects outside links and special files.
                    source.extract(member, temporary, filter='data')
        missing = [p for p in selected if not (temporary / p).exists()]
        if missing:
            raise ValueError(f'archive is missing selected paths: {missing}')
        if not any(temporary.iterdir()):
            raise ValueError('extraction produced an empty tree')
        if target.exists():
            retired = ROOT / 'context/retired-references'
            retired.mkdir(parents=True, exist_ok=True)
            target.rename(retired / (target.name + '-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%f')))
        temporary.rename(target)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)


def submodule_gaps(archive):
    if archive.suffix == '.zip':
        return []
    with tarfile.open(archive, 'r:gz') as source:
        member = next((m for m in source if len(PurePosixPath(m.name).parts) == 2
                       and m.name.endswith('/.gitmodules') and m.isfile()), None)
        if member is None:
            return []
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.read_string(source.extractfile(member).read().decode())
        return [{'path': parser.get(section, 'path', fallback=''),
                 'url': parser.get(section, 'url', fallback=''),
                 'status': 'not included in source archive'} for section in parser.sections()]


def acquire(source, previous, restore):
    entry = dict(previous or {})
    entry.update({'id': source['id'], 'title': source['title'],
                  'source_url': source['url'], 'kind': source['kind'],
                  'checked_at': datetime.now(timezone.utc).isoformat()})
    try:
        key = source['id']
        if not key or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-_' for c in key):
            raise ValueError('id must contain lowercase letters, numbers, - or _')
        if previous and previous.get('artifact') and (previous['source_url'] != source['url'] or previous['kind'] != source['kind']):
            entry['source_url'] = previous['source_url']
            entry['kind'] = previous['kind']
            entry['requested_source_url'] = source['url']
            raise ValueError('source identity changed; use a new source ID')
        if source['kind'] == 'repository':
            repo = source['repo']
            if previous and previous.get('repo', repo) != repo:
                raise ValueError('repository identity changed; use a new source ID')
            entry['repo'] = repo
            revision = entry.get('revision') or source.get('revision')
            if not revision:
                remote = subprocess.run(['git', 'ls-remote', f'https://github.com/{repo}.git',
                                         source.get('ref', 'HEAD')], capture_output=True,
                                        text=True, check=True, timeout=90)
                revision = remote.stdout.split()[0]
            entry['revision'] = revision
            selected = source.get('selected_paths', [])
            entry['selected_paths'] = selected
            files_only = source.get('mode') == 'files'
            entry['mode'] = 'files' if files_only else 'archive'
            scope_changed = bool(previous and (previous.get('selected_paths', []) != selected
                                 or previous.get('mode', 'files' if previous.get('artifact', {}).get('path', '').endswith('.zip') else 'archive') != entry['mode']))
            extension = '.zip' if files_only else '.tar.gz'
            scope = '-' + hashlib.sha256(json.dumps(sorted(selected)).encode()).hexdigest()[:12] if files_only else ''
            archive = ROOT / 'quarantine/archives' / f'{key}-{revision}{scope}{extension}'
            # Reuse an original files ZIP only when its catalog scope is identical.
            if files_only and previous and not scope_changed and previous.get('artifact'):
                archive = ROOT / previous['artifact']['path']
            target = ROOT / 'quarantine' / key
            entry['archive_url'] = (f'https://raw.githubusercontent.com/{repo}/{revision}/'
                                    if files_only else f'https://codeload.github.com/{repo}/tar.gz/{revision}')
            entry['scope'] = 'listed individual files' if files_only else (
                'full archive; selected extracted paths' if selected else 'full source archive')
            if not archive.exists():
                if files_only:
                    if not selected:
                        raise ValueError('files mode requires exact selected_paths')
                    archive.parent.mkdir(parents=True, exist_ok=True)
                    staged = archive.with_suffix('.part')
                    try:
                        with zipfile.ZipFile(staged, 'w', zipfile.ZIP_DEFLATED) as output:
                            for path in selected:
                                if clean_path(path) is None:
                                    raise ValueError(f'excluded selected path: {path}')
                                with tempfile.TemporaryDirectory() as directory:
                                    downloaded = Path(directory) / 'file'
                                    try:
                                        fetch(entry['archive_url'] + urllib.parse.quote(path, safe='/'), downloaded)
                                    except Exception as error:
                                        raise RuntimeError(f'{path}: {error}') from error
                                    member = zipfile.ZipInfo(path, date_time=(1980, 1, 1, 0, 0, 0))
                                    member.compress_type = zipfile.ZIP_DEFLATED
                                    member.external_attr = 0o100644 << 16
                                    output.writestr(member, downloaded.read_bytes())
                        staged.replace(archive)
                    finally:
                        staged.unlink(missing_ok=True)
                else:
                    fetch(entry['archive_url'], archive)
            entry['artifact'] = identity(archive, (previous or {}).get('artifact'))
            entry['submodules_not_acquired'] = submodule_gaps(archive)
            extract(archive, target, selected, rebuild=restore or scope_changed)
            entry['tree'] = str(target.relative_to(ROOT))
        else:
            pdf = source['kind'] == 'paper'
            url = source.get('pdf_url') if pdf else source['url']
            if not url:
                entry['status'] = 'lead-only'
                entry['error'] = 'No downloadable PDF URL in catalog'
                return entry
            destination = ROOT / (f'papers/pdfs/{key}.pdf' if pdf else f'context/docs/{key}.html')
            if previous and previous.get('download_url', url) != url:
                raise ValueError('download URL changed; use a new source ID')
            if not destination.exists():
                fetch(url, destination)
            if pdf and not destination.read_bytes()[:1024].lstrip().startswith(b'%PDF-'):
                destination.unlink()
                raise ValueError('download is not a PDF')
            entry['download_url'] = url
            entry['artifact'] = identity(destination, (previous or {}).get('artifact'))
        entry['status'] = 'acquired'
        entry.pop('error', None)
        entry.pop('requested_scope', None)
    except Exception as error:
        if previous and previous.get('artifact'):
            entry['requested_scope'] = {field: entry.get(field) for field in
                                        ('mode', 'selected_paths', 'revision', 'download_url')}
            for field in ('mode', 'selected_paths', 'artifact', 'tree', 'archive_url',
                          'scope', 'revision', 'repo', 'submodules_not_acquired', 'download_url'):
                if field in previous:
                    entry[field] = previous[field]
                else:
                    entry.pop(field, None)
        entry['status'] = 'failed'
        entry['error'] = f'{type(error).__name__}: {error}'
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kind', choices=['all', 'refs', 'papers', 'docs'], default='all')
    parser.add_argument('--id', action='append', help='Select source ID; repeatable')
    parser.add_argument('--restore', action='store_true', help='Rebuild trees; retain previous trees under context/retired-references')
    args = parser.parse_args()
    sources = {}
    for catalog in sorted((ROOT / 'papers').glob('*-sources.json')):
        for source in json.loads(catalog.read_text()):
            if source['id'] in sources and sources[source['id']] != source:
                raise ValueError(f'duplicate source ID: {source["id"]}')
            sources[source['id']] = source
    existing = json.loads(LEDGER.read_text()) if LEDGER.exists() else []
    records = {entry['id']: entry for entry in existing}
    kind = {'refs': 'repository', 'papers': 'paper', 'docs': 'documentation'}.get(args.kind)
    selected = [s for s in sources.values() if (kind is None or s['kind'] == kind)
                and (args.id is None or s['id'] in args.id)]
    if args.id and set(args.id) - sources.keys():
        parser.error('unknown source ID')
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = {pool.submit(acquire, s, records.get(s['id']), args.restore): s for s in selected}
        for future in concurrent.futures.as_completed(jobs):
            record = future.result()
            records[record['id']] = record
            temporary = LEDGER.with_suffix('.part')
            temporary.write_text(json.dumps(sorted(records.values(), key=lambda r: r['id']), indent=2) + '\n')
            temporary.replace(LEDGER)
            print(f'{record["status"]}: {record["id"]}' +
                  (f' — {record["error"]}' if record.get('error') else ''), flush=True)
    return int(any(records[s['id']]['status'] == 'failed' for s in selected))


if __name__ == '__main__':
    raise SystemExit(main())
