#!/usr/bin/env python3
"""Actual native parent startup arguments and inherited environment."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]



class Configuration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='bow-agent-native-config-')
        cls.directory = Path(cls.temporary.name).resolve()
        cls.binary = cls.directory / 'probe'
        subprocess.run(['clang++', '-std=c++17', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
                        '-framework', 'Foundation', '-I', str(ROOT / 'native/cef'),
                        str(ROOT / 'tests/table_agent_configuration_probe.mm'),
                        str(ROOT / 'native/cef/table_connection.mm'),
                        str(ROOT / 'native/cef/continuous_clock.mm'), '-o', str(cls.binary)], check=True)
        cls.peer = cls.directory / 'peer'
        subprocess.run(['clang++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                        str(ROOT / 'tests/table_agent_configuration_peer.cc'),
                        '-o', str(cls.peer)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def launch(self, mode, expected_returncode=0):
        database = self.directory / f'{mode}.sqlite'
        args = [str(self.binary), str(self.peer), str(database), str(self.directory / 'clock'),
                str(self.directory / 'codex'), str(self.directory / 'work'),
                str(self.directory / 'user-home'), str(self.directory / 'codex-home'), 'reserved', mode]
        result = subprocess.run(args, timeout=10)
        self.assertEqual(result.returncode, expected_returncode)
        if expected_returncode:
            self.assertFalse(Path(str(database) + '.launch').exists())
            return None
        lines = Path(str(database) + '.launch').read_text().splitlines()
        return {'args': [line[4:] for line in lines if line.startswith('arg:')],
                'env': dict(line[4:].split('=', 1) for line in lines if line.startswith('env:'))}

    def test_explicit_configuration_is_startup_only(self):
        result = self.launch('configured')
        args = result['args']
        expected = {'--agent-executable': 'codex', '--agent-cwd': 'work',
                    '--agent-user-home': 'user-home', '--agent-home': 'codex-home'}
        for option, name in expected.items():
            self.assertEqual(args[args.index(option) + 1], str(self.directory / name))
        self.assertEqual(args[args.index('--agent-model') + 1], 'fixture-model')
        self.assertEqual(args[args.index('--agent-provider') + 1], 'openai')
        self.assertEqual(args[args.index('--agent-account') + 1], 'fixture-account')
        self.assertEqual(result['env'], {'LANG': 'en_US.UTF-8'})

    def test_ordinary_catalog_has_no_agent_configuration(self):
        result = self.launch('ordinary')
        self.assertEqual(len(result['args']), 6)
        self.assertFalse(any(arg.startswith('--agent-') for arg in result['args']))
        self.assertEqual(result['env'], {'LANG': 'en_US.UTF-8'})

    def test_metadata_baseline_does_not_invent_an_account_expectation(self):
        result = self.launch('baseline')
        self.assertIn('--agent-executable', result['args'])
        self.assertNotIn('--agent-account', result['args'])

    def test_remote_executable_refused_before_spawn(self):
        self.launch('invalid', expected_returncode=1)


if __name__ == '__main__':
    unittest.main()
