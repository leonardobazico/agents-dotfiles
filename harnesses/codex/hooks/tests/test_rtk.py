import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
ADAPTER = ROOT / 'harnesses/codex/hooks/rtk.py'
REAL_RTK = shutil.which('rtk')
PAYLOAD = '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status --short"}}'

class HookTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='codex-rtk-hook-')
        self.addCleanup(temp.cleanup)
        self.root = pathlib.Path(temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        fixture = self.bin / 'rtk'
        fixture.write_text('''#!/usr/bin/env python3
import os, sys
sys.stdin.read()
sys.stdout.write(os.environ.get('PROBE_RESPONSE', ''))
sys.stderr.write(os.environ.get('PROBE_STDERR', ''))
sys.exit(int(os.environ.get('PROBE_STATUS', '0')))
''')
        fixture.chmod(0o755)
        self.env = {**os.environ, 'PATH': str(self.bin) + ':' + os.environ['PATH']}

    def invoke(self, response='', status=0, stderr=''):
        self.assertTrue(ADAPTER.is_file(), 'production adapter does not exist')
        return subprocess.run([sys.executable, str(ADAPTER)], input=PAYLOAD, env={**self.env, 'PROBE_RESPONSE': response, 'PROBE_STATUS': str(status), 'PROBE_STDERR': stderr}, capture_output=True, text=True)

    def test_rewrite_without_decision_is_allowed(self):
        result = self.invoke('{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":{"command":"rtk git status --short"}}}')
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual({'hookEventName': 'PreToolUse', 'updatedInput': {'command': 'rtk git status --short'}, 'permissionDecision': 'allow'}, json.loads(result.stdout)['hookSpecificOutput'])

    def test_explicit_decisions_and_other_fields_are_preserved(self):
        for decision in ['allow', 'deny', 'ask']:
            with self.subTest(decision=decision):
                response = {'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'updatedInput': {'command': 'rtk git status --short'}, 'permissionDecision': decision, 'permissionDecisionReason': 'reason', 'additionalContext': 'context'}, 'other': 'retained'}
                result = self.invoke(json.dumps(response))
                self.assertEqual(0, result.returncode)
                self.assertEqual(response, json.loads(result.stdout))

    def test_no_rewrite_does_not_add_authorization(self):
        response = {'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': 'context'}}
        result = self.invoke(json.dumps(response))
        self.assertEqual(response, json.loads(result.stdout))

    def test_empty_response_is_passed_through(self):
        result = self.invoke(stderr='diagnostic')
        self.assertEqual((0, '', 'diagnostic'), (result.returncode, result.stdout, result.stderr))

    def test_malformed_json_has_no_authorization_response(self):
        result = self.invoke('{broken', stderr='rtk diagnostic\n')
        self.assertEqual(1, result.returncode)
        self.assertEqual('', result.stdout)
        self.assertIn('rtk diagnostic', result.stderr)
        self.assertIn('JSON', result.stderr)

    def test_failed_rtk_preserves_status_and_stderr(self):
        result = self.invoke('{broken', status=23, stderr='upstream error')
        self.assertEqual(23, result.returncode)
        self.assertEqual('upstream error', result.stderr)
        self.assertNotIn('permissionDecision', result.stdout)

    def test_hook_uses_active_codex_home_and_default_fallback(self):
        self.assertTrue(ADAPTER.exists(), 'Codex package missing')
        for codex_mode in ['set', 'unset', 'empty']:
            with self.subTest(mode=codex_mode):
                user_root = self.root / ('user-' + codex_mode)
                target = self.root / 'isolated-codex' if codex_mode == 'set' else user_root / '.codex'
                target.mkdir(parents=True)
                subprocess.run(['make', '-C', str(ROOT), 'link-harnesses', 'HARNESSES=codex', 'TARGET_codex=' + str(target)], check=True, capture_output=True)
                self.assertTrue((target / 'hooks/rtk.py').is_symlink())
                self.assertTrue((target / 'hooks.json').is_symlink())
                self.assertFalse((target / 'hooks/tests').exists())
                self.assertFalse((target / 'hooks/run_tests.sh').exists())
                hook = json.loads((target / 'hooks.json').read_text())['hooks']['PreToolUse'][0]
                self.assertEqual('Bash', hook['matcher'])
                env = {**self.env, 'HOME': str(user_root), 'PROBE_RESPONSE': '{"hookSpecificOutput":{"updatedInput":{"command":"rtk git status --short"}}}'}
                env.pop('CODEX_HOME', None)
                if codex_mode != 'unset': env['CODEX_HOME'] = str(target) if codex_mode == 'set' else ''
                result = subprocess.run(['/bin/sh', '-c', hook['hooks'][0]['command']], input=PAYLOAD, env=env, text=True, capture_output=True)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual('allow', json.loads(result.stdout)['hookSpecificOutput']['permissionDecision'])
                if codex_mode == 'set': self.assertFalse((user_root / '.codex').exists())

    @unittest.skipUnless(REAL_RTK, 'real rtk not installed')
    def test_real_rtk_rewrite_and_unwrapped_commands(self):
        print('integration rtk:', subprocess.check_output([REAL_RTK, '--version'], text=True).strip())
        (self.bin / 'rtk').unlink()
        (self.bin / 'rtk').symlink_to(REAL_RTK)
        self.assertTrue(ADAPTER.exists(), 'production adapter does not exist')
        for command in ['git status --short', 'rtk git status --short', 'echo hello']:
            payload = json.dumps({'hook_event_name': 'PreToolUse', 'tool_name': 'Bash', 'tool_input': {'command': command}})
            result = subprocess.run([sys.executable, str(ADAPTER)], input=payload, env=self.env, text=True, capture_output=True)
            self.assertEqual(0, result.returncode, result.stderr)
            if command == 'git status --short':
                output = json.loads(result.stdout)['hookSpecificOutput']
                self.assertEqual('rtk git status --short', output['updatedInput']['command'])
                self.assertEqual('allow', output['permissionDecision'])
            else: self.assertEqual('', result.stdout)

    def test_link_and_unlink_leave_test_files_unmanaged(self):
        target = self.root / 'live'
        tests = target / 'hooks/tests'
        tests.mkdir(parents=True)
        sentinel = tests / 'test_rtk.py'
        sentinel.write_text('USER TEST')
        runner = target / 'hooks/run_tests.sh'
        runner.write_text('USER RUNNER')
        for action in ['link-harnesses', 'relink-harnesses', 'unlink-harnesses']:
            with self.subTest(action=action):
                result = subprocess.run(['make', '-C', str(ROOT), action, 'HARNESSES=codex', 'TARGET_codex=' + str(target)], capture_output=True, text=True)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertFalse(sentinel.is_symlink())
                self.assertEqual('USER TEST', sentinel.read_text())
                self.assertEqual('USER RUNNER', runner.read_text())
                self.assertFalse(pathlib.Path(str(sentinel) + '.bak').exists())
                self.assertFalse(pathlib.Path(str(runner) + '.bak').exists())

    def test_direct_restore_ignores_test_backups(self):
        target = self.root / 'restore'
        tests = target / 'hooks/tests'
        tests.mkdir(parents=True)
        backup = tests / 'test_rtk.py.bak'
        backup.write_text('USER BACKUP')
        result = subprocess.run([str(ROOT / 'scripts/restore-harness.sh'), str(ROOT / 'harnesses/codex'), str(target)], capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual('USER BACKUP', backup.read_text())
        self.assertFalse((tests / 'test_rtk.py').exists())

if __name__ == '__main__':
    unittest.main(verbosity=2)
