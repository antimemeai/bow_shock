#!/usr/bin/env python3
"""Run the owned catalog and dedicated native browser together."""
import argparse
from pathlib import Path
import subprocess
import sys
import shutil

from fixture_service import ROOT, arguments, serve


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path, default=ROOT / 'context/runtime/poc')
    parser.add_argument('--port', type=int, default=43177,
                        help='Keep this port for same-origin saved-table reopen.')
    parser.add_argument('--page', choices=['amber', 'birch'], default='amber')
    parser.add_argument('--agent', action='store_true', help='Enable explicit native Ask/Use proposal controls with installed Codex.')
    parser.add_argument('--agent-executable', type=Path, help='Trusted installed Codex executable; default: codex on PATH.')
    parser.add_argument('--agent-model', default='gpt-6.1-sol')
    parser.add_argument('--agent-home', type=Path, default=Path.home() / '.codex')
    parser.add_argument('--agent-account', help='Optional expected backend account ID; credentials remain in Codex.')
    options = parser.parse_args()
    if not 0 <= options.port <= 65535:
        parser.error('--port must be between 0 and 65535.')
    app = ROOT / 'context/build/native/Bow Shock.app/Contents/MacOS/Bow Shock'
    if sys.platform != 'darwin' or not app.is_file():
        parser.error('Build the macOS ARM64 app with python3 scripts/build-native.py first.')
    agent_args = []
    if options.agent:
        selected = options.agent_executable or shutil.which('codex')
        if not selected or not Path(selected).expanduser().is_file():
            parser.error('Install Codex or select its executable with --agent-executable.')
        agent_args = [f'--bs-agent-executable={Path(selected).expanduser().resolve()}',
                      f'--bs-agent-cwd={ROOT}', f'--bs-agent-user-home={Path.home()}',
                      f'--bs-agent-home={options.agent_home.expanduser().resolve()}',
                      f'--bs-agent-model={options.agent_model}']
        if options.agent_account:
            agent_args.append(f'--bs-agent-account={options.agent_account}')
    elif options.agent_executable or options.agent_account:
        parser.error('Agent settings require --agent.')
    data = options.data_dir.expanduser().resolve()
    data.mkdir(parents=True, exist_ok=True)
    try:
        server = serve(options.port)
    except OSError as error:
        parser.error(f'Cannot bind the owned catalog port: {error}')
    origin = f'http://127.0.0.1:{server.server_port}'
    try:
        print(f'Owned catalog: {origin}; retained tables: {data / "tables.sqlite"}', flush=True)
        print('Use the native controls to observe, review and save. Quit Bow Shock to close the table store cleanly.', flush=True)
        # A separate process group keeps terminal Ctrl-C from destroying the
        # app before its native asynchronous table-close workflow can finish.
        child = subprocess.Popen(arguments(app, data, origin, options.page) + agent_args, start_new_session=True)
        while True:
            try:
                return child.wait()
            except KeyboardInterrupt:
                print('Close Bow Shock with its Quit button or window close; the catalog remains available for clean shutdown.', flush=True)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == '__main__':
    raise SystemExit(main())
