#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
python3 - "$repo_root" <<'PY'
import json, os, pathlib, shutil, signal, subprocess, sys, tempfile, time, unittest

SETUP = pathlib.Path(sys.argv[1]) / 'scripts/setup-rtk.sh'
REAL_RTK = shutil.which('rtk')
STAMP = '20260930T120000Z'
FAKE = '''#!/usr/bin/env python3
import os, pathlib, signal, sys
root = pathlib.Path(os.environ['HOME'])
settings = root / '.claude/settings.json'
backup = pathlib.Path(str(settings) + '.bak')
mode = os.environ.get('PROBE_MODE', '')
if '--opencode' in sys.argv:
    if mode == 'second-fail': sys.exit(24)
    plugin = root / '.config/opencode/plugins/rtk.ts'
    plugin.parent.mkdir(parents=True, exist_ok=True)
    plugin.write_text('plugin')
    sys.exit(0)
backup.write_bytes(settings.read_bytes())
if mode == 'collision': pathlib.Path(str(backup) + '.20260930T120000Z.rtk').write_text('OTHER')
if mode == 'directory': pathlib.Path(str(backup) + '.20260930T120000Z.rtk').mkdir()
if mode == 'archive-fail':
    backup.unlink()
    backup.mkdir()
if mode == 'fail': sys.exit(23)
if mode == 'wait':
    signal.signal(signal.SIGINT, lambda *_: sys.exit(130))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    (root / 'ready').write_text(str(os.getpid()))
    signal.pause()
'''

class SetupTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='setup-rtk-')
        self.addCleanup(temp.cleanup)
        self.root = pathlib.Path(temp.name)
        claude = self.root / '.claude'
        claude.mkdir()
        self.settings = claude / 'settings.json'
        self.settings.write_text('{"model":"opus","hooks":{"SessionStart":[]}}')
        self.original = self.settings.read_bytes()
        self.backup = claude / 'settings.json.bak'
        self.pre = claude / f'settings.json.bak.{STAMP}.pre-rtk'
        self.snapshot = claude / f'settings.json.bak.{STAMP}.rtk'
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.executable('rtk', FAKE)
        self.executable('date', '#!/bin/sh\nprintf "%s\\n" ' + STAMP + '\n')
        self.env = {**os.environ, 'HOME': str(self.root), 'PATH': str(self.bin) + ':' + os.environ['PATH']}

    def executable(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def run_setup(self, *args, mode='', real=False):
        if real:
            (self.bin / 'rtk').unlink(missing_ok=True)
            (self.bin / 'rtk').symlink_to(REAL_RTK)
        return subprocess.run([str(SETUP), *args], env={**self.env, 'PROBE_MODE': mode}, text=True, capture_output=True, timeout=15)

    def archived(self, result):
        self.assertEqual(b'ORIGINAL', self.pre.read_bytes())
        self.assertEqual(self.original, self.snapshot.read_bytes())
        self.assertFalse(self.backup.exists())
        for path in [self.pre, self.snapshot]: self.assertIn(str(path), result.stdout + result.stderr)

    def test_install_and_uninstall_preserve_both_backups(self):
        for args in [(), ('--uninstall',)]:
            with self.subTest(args=args):
                self.backup.write_bytes(b'ORIGINAL')
                result = self.run_setup(*args)
                self.assertEqual(0, result.returncode, result.stderr)
                self.archived(result)
                self.pre.unlink()
                self.snapshot.unlink()

    def test_generated_backup_is_preserved_without_original(self):
        result = self.run_setup()
        self.assertEqual(0, result.returncode)
        self.assertEqual(self.original, self.snapshot.read_bytes())
        self.assertFalse(self.pre.exists())
        self.assertFalse(self.backup.exists())
        self.assertIn(str(self.snapshot), result.stdout + result.stderr)

    def test_init_failures_archive_and_preserve_status(self):
        for mode, status in [('fail', 23), ('second-fail', 24)]:
            with self.subTest(mode=mode):
                self.backup.write_bytes(b'ORIGINAL')
                result = self.run_setup(mode=mode)
                self.assertEqual(status, result.returncode)
                self.archived(result)
                self.assertFalse((self.root / '.config/opencode/plugins/rtk.ts').exists())
                self.assertNotEqual(0, self.run_setup().returncode)
                self.assertEqual(b'ORIGINAL', self.pre.read_bytes())
                self.assertEqual(self.original, self.snapshot.read_bytes())
                self.pre.unlink()
                self.snapshot.unlink()

    def test_preflight_refuses_file_and_dangling_link(self):
        for kind in ['file', 'link']:
            with self.subTest(kind=kind):
                self.backup.write_bytes(b'ORIGINAL')
                if kind == 'file': self.pre.write_bytes(b'OTHER')
                else: self.pre.symlink_to(self.root / 'missing')
                self.assertNotEqual(0, self.run_setup().returncode)
                self.assertEqual(b'ORIGINAL', self.backup.read_bytes())
                self.assertTrue(self.pre.is_symlink() if kind == 'link' else self.pre.read_bytes() == b'OTHER')
                self.pre.unlink()

    def test_collision_during_init_retains_source_and_destination(self):
        for mode in ['collision', 'directory']:
            with self.subTest(mode=mode):
                result = self.run_setup(mode=mode)
                self.assertNotEqual(0, result.returncode)
                self.assertEqual(self.original, self.backup.read_bytes())
                self.assertIn(str(self.backup), result.stderr)
                if mode == 'collision':
                    self.assertEqual(b'OTHER', self.snapshot.read_bytes())
                    self.snapshot.unlink()
                else:
                    self.assertEqual([], list(self.snapshot.iterdir()))
                    self.snapshot.rmdir()
                self.backup.unlink()

    def test_archival_failure_preserves_source_and_reports_location(self):
        result = self.run_setup(mode='archive-fail')
        self.assertNotEqual(0, result.returncode)
        self.assertTrue(self.backup.is_dir())
        self.assertIn(str(self.backup), result.stderr)

    def test_signals_stop_child_and_preserve_backups(self):
        for sig, status in [(signal.SIGINT, 130), (signal.SIGTERM, 143)]:
            with self.subTest(signal=sig):
                self.backup.write_bytes(b'ORIGINAL')
                proc = subprocess.Popen([str(SETUP)], env={**self.env, 'PROBE_MODE': 'wait'}, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                ready = self.root / 'ready'
                try:
                    deadline = time.monotonic() + 5
                    while not ready.exists() and proc.poll() is None and time.monotonic() < deadline: time.sleep(0.01)
                    self.assertTrue(ready.exists(), 'init did not reach signal-ready state')
                    proc.send_signal(sig)
                    stdout, stderr = proc.communicate(timeout=5)
                    self.assertEqual(status, proc.returncode, stderr)
                    self.archived(subprocess.CompletedProcess([], proc.returncode, stdout, stderr))
                    self.assertFalse((self.root / '.config/opencode/plugins/rtk.ts').exists())
                finally:
                    if ready.exists():
                        try: os.kill(int(ready.read_text()), signal.SIGKILL)
                        except ProcessLookupError: pass
                        ready.unlink()
                    if proc.poll() is None:
                        proc.kill()
                        proc.communicate()
                    self.pre.unlink(missing_ok=True)
                    self.snapshot.unlink(missing_ok=True)

    def test_missing_rtk_uninstall_fails_without_mutation(self):
        result = subprocess.run([str(SETUP), '--uninstall'], env={**self.env, 'PATH': '/usr/bin:/bin'}, text=True, capture_output=True)
        self.assertNotEqual(0, result.returncode)
        self.assertIn('reinstall', result.stderr.lower())
        self.assertEqual(self.original, self.settings.read_bytes())

    def test_missing_rtk_and_brew_fails(self):
        result = subprocess.run([str(SETUP)], env={**self.env, 'PATH': '/usr/bin:/bin'}, text=True, capture_output=True)
        self.assertEqual(1, result.returncode)
        self.assertIn('homebrew', result.stderr.lower())

    def test_invalid_mode_does_not_touch_backup(self):
        self.backup.write_bytes(b'ORIGINAL')
        result = self.run_setup('invalid')
        self.assertEqual(2, result.returncode)
        self.assertIn('usage:', result.stderr)
        self.assertEqual(b'ORIGINAL', self.backup.read_bytes())

    @unittest.skipUnless(REAL_RTK, 'real rtk not installed')
    def test_real_rtk_install_rerun_and_uninstall(self):
        print('integration rtk:', subprocess.check_output([REAL_RTK, '--version'], text=True).strip())
        for stamp, args in [('20260930T120000Z', ()), ('20260930T120001Z', ()), ('20260930T120002Z', ('--uninstall',))]:
            self.executable('date', '#!/bin/sh\nprintf "%s\\n" ' + stamp + '\n')
            result = self.run_setup(*args, real=True)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn('SessionStart', json.loads(self.settings.read_text())['hooks'])
            self.assertEqual(0 if args else 1, self.settings.read_text().count('rtk hook claude'))
            self.assertEqual(not bool(args), (self.root / '.config/opencode/plugins/rtk.ts').exists())

unittest.main(argv=['setup_rtk_test'], verbosity=2)
PY
