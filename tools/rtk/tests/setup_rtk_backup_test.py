import os
import signal
import subprocess
import time
import unittest
from contextlib import suppress

from setup_rtk_fixture import SETUP, SetupRtkCase


class BackupTests(SetupRtkCase):
    def test_install_and_uninstall_preserve_both_backups(self):
        for args in [(), ("--uninstall",)]:
            with self.subTest(args=args):
                self.backup.write_bytes(b"ORIGINAL")
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
        for mode, status in [("fail", 23), ("second-fail", 24)]:
            with self.subTest(mode=mode):
                self.backup.write_bytes(b"ORIGINAL")
                result = self.run_setup(mode=mode)
                self.assertEqual(status, result.returncode)
                self.archived(result)
                self.assertFalse(
                    (self.root / ".config/opencode/plugins/rtk.ts").exists()
                )
                self.assertNotEqual(0, self.run_setup().returncode)
                self.assertEqual(b"ORIGINAL", self.pre.read_bytes())
                self.assertEqual(self.original, self.snapshot.read_bytes())
                self.pre.unlink()
                self.snapshot.unlink()

    def test_preflight_refuses_file_and_dangling_link(self):
        for kind in ["file", "link"]:
            with self.subTest(kind=kind):
                self.backup.write_bytes(b"ORIGINAL")
                if kind == "file":
                    self.pre.write_bytes(b"OTHER")
                else:
                    self.pre.symlink_to(self.root / "missing")
                self.assertNotEqual(0, self.run_setup().returncode)
                self.assertEqual(b"ORIGINAL", self.backup.read_bytes())
                self.assertTrue(
                    self.pre.is_symlink()
                    if kind == "link"
                    else self.pre.read_bytes() == b"OTHER"
                )
                self.pre.unlink()

    def test_collision_during_init_retains_source_and_destination(self):
        for mode in ["collision", "directory"]:
            with self.subTest(mode=mode):
                result = self.run_setup(mode=mode)
                self.assertNotEqual(0, result.returncode)
                self.assertEqual(self.original, self.backup.read_bytes())
                self.assertIn(str(self.backup), result.stderr)
                if mode == "collision":
                    self.assertEqual(b"OTHER", self.snapshot.read_bytes())
                    self.snapshot.unlink()
                else:
                    self.assertEqual([], list(self.snapshot.iterdir()))
                    self.snapshot.rmdir()
                self.backup.unlink()

    def test_archival_failure_preserves_source_and_reports_location(self):
        result = self.run_setup(mode="archive-fail")
        self.assertNotEqual(0, result.returncode)
        self.assertTrue(self.backup.is_dir())
        self.assertIn(str(self.backup), result.stderr)

    def test_signals_stop_child_and_preserve_backups(self):
        for sig, status in [(signal.SIGINT, 130), (signal.SIGTERM, 143)]:
            with self.subTest(signal=sig):
                self.backup.write_bytes(b"ORIGINAL")
                proc = subprocess.Popen(
                    [str(SETUP)],
                    env={**self.env, "PROBE_MODE": "wait"},
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                ready = self.root / "ready"
                try:
                    deadline = time.monotonic() + 5
                    while (
                        not ready.exists()
                        and proc.poll() is None
                        and time.monotonic() < deadline
                    ):
                        time.sleep(0.01)
                    self.assertTrue(
                        ready.exists(), "init did not reach signal-ready state"
                    )
                    proc.send_signal(sig)
                    stdout, stderr = proc.communicate(timeout=5)
                    self.assertEqual(status, proc.returncode, stderr)
                    self.archived(
                        subprocess.CompletedProcess([], proc.returncode, stdout, stderr)
                    )
                    self.assertFalse(
                        (self.root / ".config/opencode/plugins/rtk.ts").exists()
                    )
                finally:
                    if ready.exists():
                        with suppress(ProcessLookupError):
                            os.kill(int(ready.read_text()), signal.SIGKILL)
                        ready.unlink()
                    if proc.poll() is None:
                        proc.kill()
                        proc.communicate()
                    self.pre.unlink(missing_ok=True)
                    self.snapshot.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main(argv=["setup_rtk_backup_test.py"], verbosity=2)
