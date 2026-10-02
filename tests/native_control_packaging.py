#!/usr/bin/env python3
"""Actual bundled helper/clock oracle without launching CEF."""
import json
from pathlib import Path
import subprocess
from native_control_helper import frame, reply, read_frame

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'context/build/native/Bow Shock.app'
CONTROL = APP / 'Contents/MacOS/bow-shock-native-control'
CLOCK = APP / 'Contents/MacOS/bow_shock_clock_probe'


def main():
    for executable in [CONTROL, CLOCK]:
        assert executable.is_file(), f'owned executable is absent: {executable.name}'
        subprocess.run(['/usr/bin/codesign', '--verify', '--strict', str(executable)], check=True)
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(APP)], check=True)
    process = subprocess.Popen([str(CONTROL)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, bufsize=0, env={'LANG': 'C'}, close_fds=True)
    try:
        for request, expected in [(frame(lease=1000), reply(1, 1)),
            (frame(3, 2, 1, 0), reply(3, 2, 1, status=2)),
            (frame(5, 3, 1, 0), reply(5, 3, 1, status=3))]:
            process.stdin.write(request)
            assert read_frame(process.stdout) == expected, 'bundled helper wire mismatch'
        assert process.wait(timeout=2) == 0
        assert process.stdout.read() == b''
    finally:
        if process.poll() is None:
            process.terminate()
            try: process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(timeout=1)
        for stream in [process.stdin, process.stdout, process.stderr]: stream.close()
    witness = json.loads(subprocess.check_output([str(CLOCK)], timeout=2))
    actual_boot = subprocess.check_output(['/usr/sbin/sysctl', '-n', 'kern.bootsessionuuid'], text=True).strip()
    assert witness['boot_id'] == actual_boot and type(witness['continuous_ns']) is int
    assert witness['continuous_ns'] > 0
    print('Bundled control trace, strict signatures and actual clock witness pass')


if __name__ == '__main__':
    main()
