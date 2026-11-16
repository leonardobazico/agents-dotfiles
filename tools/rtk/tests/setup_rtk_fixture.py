import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

SETUP = pathlib.Path(__file__).resolve().parents[3] / "tools/rtk/setup-rtk.sh"
REAL_RTK = shutil.which("rtk")
STAMP = "20260930T120000Z"
FAKE = """#!/usr/bin/env python3
import os, pathlib, signal, sys
with open(os.environ['EVENT_LOG'], 'a') as log:
    log.write('rtk ' + ' '.join(sys.argv[1:]) + '\\n')
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
if mode == 'collision':
    collision = pathlib.Path(str(backup) + '.20260930T120000Z.rtk')
    collision.write_text('OTHER')
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
"""
FAKE_BREW = """#!/usr/bin/env python3
import os, pathlib, shutil, sys

args = sys.argv[1:]
with open(os.environ['EVENT_LOG'], 'a') as log:
    log.write('brew ' + ' '.join(args) + '\\n')

formula = 'rtk'
if args == ['list', '--versions', formula]:
    if os.environ.get('BREW_INSTALLED') == '1':
        print('rtk 1.2.0')
        sys.exit(0)
    sys.exit(1)
if args == ['upgrade', formula]:
    sys.exit(int(os.environ.get('BREW_UPGRADE_EXIT', '0')))
if args == ['install', formula]:
    status = int(os.environ.get('BREW_INSTALL_EXIT', '0'))
    if status:
        sys.exit(status)
    target = pathlib.Path(os.environ['RTK_BIN'])
    shutil.copyfile(os.environ['RTK_FIXTURE'], target)
    target.chmod(0o755)
    sys.exit(0)
sys.exit(2)
"""


class SetupRtkCase(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="setup-rtk-")
        self.addCleanup(temp.cleanup)
        self.root = pathlib.Path(temp.name)
        claude = self.root / ".claude"
        claude.mkdir()
        self.settings = claude / "settings.json"
        self.settings.write_text('{"model":"opus","hooks":{"SessionStart":[]}}')
        self.original = self.settings.read_bytes()
        self.backup = claude / "settings.json.bak"
        self.pre = claude / f"settings.json.bak.{STAMP}.pre-rtk"
        self.snapshot = claude / f"settings.json.bak.{STAMP}.rtk"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.event_log = self.root / "events.log"
        self.rtk_fixture = self.root / "rtk-fixture"
        self.rtk_fixture.write_text(FAKE)
        self.rtk_fixture.chmod(0o755)
        self.executable("rtk", FAKE)
        self.executable("brew", FAKE_BREW)
        self.executable("date", '#!/bin/sh\nprintf "%s\\n" ' + STAMP + "\n")
        for tool in ("bash", "python3"):
            (self.bin / tool).symlink_to(shutil.which(tool))
        self.env = {
            **os.environ,
            "HOME": str(self.root),
            "PATH": str(self.bin) + ":" + os.environ["PATH"],
            "EVENT_LOG": str(self.event_log),
            "BREW_INSTALLED": "1",
            "RTK_FIXTURE": str(self.rtk_fixture),
            "RTK_BIN": str(self.bin / "rtk"),
        }

    def executable(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def run_setup(self, *args, mode="", real=False):
        if real:
            (self.bin / "rtk").unlink(missing_ok=True)
            (self.bin / "rtk").symlink_to(REAL_RTK)
        return subprocess.run(
            [str(SETUP), *args],
            env={**self.env, "PROBE_MODE": mode},
            text=True,
            capture_output=True,
            timeout=15,
        )

    def archived(self, result):
        self.assertEqual(b"ORIGINAL", self.pre.read_bytes())
        self.assertEqual(self.original, self.snapshot.read_bytes())
        self.assertFalse(self.backup.exists())
        for path in [self.pre, self.snapshot]:
            self.assertIn(str(path), result.stdout + result.stderr)
