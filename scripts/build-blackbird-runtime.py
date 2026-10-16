#!/usr/bin/env python3
"""Build an exported Blackbird revision without changing its active checkout."""
import argparse
import datetime
import hashlib
from pathlib import Path
import plistlib
import shutil
import subprocess
import tarfile
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--repo', type=Path, default=Path.home() / 'projects/blackbird')
parser.add_argument('--revision', default='master', help='commit, branch or owned Git tree')
parser.add_argument('--runtime', type=Path)
args = parser.parse_args()
repo = args.repo.expanduser().resolve()
runtime = args.runtime.expanduser().resolve() if args.runtime else repo / 'context/mainline-runtime'


def git(*arguments):
    return subprocess.check_output(['git', '-C', str(repo), *arguments], text=True).strip()


tree = git('rev-parse', '--verify', args.revision + '^{tree}')
identity = str(uuid.uuid4())
runtime.mkdir(parents=True, exist_ok=True)
archive = runtime / f'source-{tree}-{identity}.tar'
subprocess.run(['git', '-C', str(repo), 'archive', '--format=tar', '--output', str(archive), tree], check=True)
stage = runtime / f'.source-stage-{identity}'
stage.mkdir(mode=0o700)
links = []
with tarfile.open(archive) as bundle:
    for member in bundle:
        if member.name == 'BLACKBIRD.md' and member.issym() and member.linkname == '../BLACKBIRD.md':
            # This owned repository link points outside a relocated export. Keep
            # the archive intact and materialize the current shared doctrine.
            common = Path(git('rev-parse', '--path-format=absolute', '--git-common-dir'))
            doctrine = common.parent / 'BLACKBIRD.md'
            shutil.copyfile(doctrine, stage / 'BLACKBIRD.md')
            links.append({'path': member.name, 'target': member.linkname,
                          'materialized_from': str(doctrine.resolve())})
        else:
            bundle.extract(member, stage, filter='data')
source = runtime / 'source'
retained = ''
if source.exists():
    previous = runtime / f'source-retained-{identity}'
    source.rename(previous)
    retained = str(previous)
stage.rename(source)
with archive.open('rb') as stream:
    archive_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
record = {'format': 'oxcart.blackbird-runtime-source', 'version': 1, 'tree': tree,
          'requested_revision': args.revision, 'created_at': datetime.datetime.now(datetime.timezone.utc),
          'archive': str(archive), 'archive_sha256': archive_hash,
          'materialized_links': links, 'previous_source': retained}
records = runtime / 'sources'
records.mkdir(exist_ok=True)
with (records / f'{identity}.bplist').open('xb') as output:
    plistlib.dump(record, output, fmt=plistlib.FMT_BINARY, aware_datetime=True)
(runtime / 'SOURCE_TREE').write_text(tree + '\n')
print(f'Blackbird source tree: {tree}\nSource archive: {archive}', flush=True)
sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
build = runtime / 'build/debug'
subprocess.run(['cmake', '--preset', 'debug', '-B', str(build), f'-DCMAKE_OSX_SYSROOT={sdk}'], cwd=source, check=True)
subprocess.run(['cmake', '--build', str(build), '--target', 'blackbird', '--parallel', '4'], cwd=source, check=True)
commit = subprocess.run(['git', '-C', str(repo), 'rev-parse', '--verify', args.revision + '^{commit}'],
                        capture_output=True, text=True)
pin = commit.stdout.strip() if commit.returncode == 0 else 'tree:' + tree
pin_file = runtime / 'SOURCE_COMMIT'
if pin_file.exists():
    shutil.copyfile(pin_file, records / f'{identity}-previous-pin.txt')
pin_file.write_text(pin + '\n')
print(f'Blackbird runtime: {build / "blackbird"}', flush=True)
