#!/usr/bin/env python3
"""Installer tests: exclusively synthetic apps inside project-local temp dirs."""
import importlib.util
import sys
from pathlib import Path
import os
import plistlib
import shutil
import tempfile
import unittest
from unittest.mock import patch
import subprocess

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
spec = importlib.util.spec_from_file_location('installer', ROOT / 'tools/install_app.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='installer-test-', dir=ROOT / 'checks')
        self.root = Path(self.temp.name)
        self.source = self.root / 'dist/BeispielApp.app'
        self.destination = self.root / 'Applications/BeispielApp.app'
        self.destination.parent.mkdir()
        self.app(self.source, 'new')
        self.app(self.destination, 'old')
        self.calls = 0

    def tearDown(self):
        self.temp.cleanup()

    def app(self, path, version):
        (path / 'Contents').mkdir(parents=True)
        (path / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': m.BUNDLE_ID}))
        (path / 'version').write_text(version)

    def verify(self, path):
        self.assertEqual(m.bundle_id(path), m.BUNDLE_ID)
        self.assertEqual((path / 'version').read_text(), 'new')

    def run_install(self, **kwargs):
        options = dict(verify=self.verify, stopped=lambda: None, copy=shutil.copytree)
        options.update(kwargs)
        m.install(self.source, self.destination, **options)

    def old_intact(self):
        self.assertEqual((self.destination / 'version').read_text(), 'old')
        self.assertEqual(list(self.destination.parent.glob(f'.{m.EXECUTABLE}*')), [])

    def test_upgrade(self):
        self.run_install()
        self.assertEqual((self.destination / 'version').read_text(), 'new')
        self.assertEqual(list(self.destination.parent.glob(f'.{m.EXECUTABLE}*')), [])

    def test_first_install(self):
        shutil.rmtree(self.destination)
        self.run_install()
        self.assertEqual((self.destination / 'version').read_text(), 'new')

    def test_invalid_source_never_touches_target(self):
        def reject(_): raise m.InstallError('invalid signature/fingerprint')
        with self.assertRaises(m.InstallError): self.run_install(verify=reject)
        self.old_intact()

    def test_running_app_never_touched(self):
        def running(): raise m.InstallError('running')
        with self.assertRaises(m.InstallError): self.run_install(stopped=running)
        self.old_intact()

    def test_app_started_during_staging(self):
        def running():
            self.calls += 1
            if self.calls == 2: raise m.InstallError('running')
        with self.assertRaises(m.InstallError): self.run_install(stopped=running)
        self.old_intact()

    def test_app_started_after_backup_restores_old(self):
        def running():
            self.calls += 1
            if self.calls == 3: raise m.InstallError('running')
        with self.assertRaises(m.InstallError): self.run_install(stopped=running)
        self.old_intact()

    def test_copy_failure_keeps_old(self):
        def copy(_, target):
            target.mkdir()
            raise OSError('copy failed')
        with self.assertRaises(OSError): self.run_install(copy=copy)
        self.old_intact()

    def test_damaged_staged_copy_keeps_old(self):
        def verify(path):
            if path != self.source: raise m.InstallError('damaged copy')
        with self.assertRaises(m.InstallError): self.run_install(verify=verify)
        self.old_intact()

    def test_publish_failure_rolls_back(self):
        def move(source, destination):
            if source.name == 'new.app': raise OSError('publish failure')
            os.rename(source, destination)
        with self.assertRaises(m.InstallError): self.run_install(move=move)
        self.old_intact()

    def test_post_install_verification_failure_rolls_back(self):
        def verify(path):
            if path == self.destination: raise m.InstallError('installed verification failed')
        with self.assertRaises(m.InstallError): self.run_install(verify=verify)
        self.old_intact()

    def test_failed_first_install_removes_new_app(self):
        shutil.rmtree(self.destination)
        def verify(path):
            if path == self.destination: raise m.InstallError('installed verification failed')
        with self.assertRaises(m.InstallError): self.run_install(verify=verify)
        self.assertFalse(self.destination.exists())

    def test_failed_recovery_preserves_backup(self):
        def move(source, destination):
            if source.name in ('new.app', 'previous.app'): raise OSError('move failure')
            os.rename(source, destination)
        with self.assertRaisesRegex(m.InstallError, 'bleiben erhalten'): self.run_install(move=move)
        backup = list(self.destination.parent.glob(f'.{m.EXECUTABLE}-install-*/previous.app'))
        self.assertEqual(len(backup), 1)
        self.assertEqual((backup[0] / 'version').read_text(), 'old')

    def test_newly_running_app_blocks_rollback_and_preserves_backup(self):
        def verify(path):
            if path == self.destination: raise m.InstallError('installed verification failed')
        def stopped():
            self.calls += 1
            if self.calls == 4: raise m.InstallError('running')
        with self.assertRaisesRegex(m.InstallError, 'bleiben erhalten'):
            self.run_install(verify=verify, stopped=stopped)
        self.assertEqual((self.destination / 'version').read_text(), 'new')
        self.assertEqual(len(list(self.destination.parent.glob(f'.{m.EXECUTABLE}-install-*/previous.app'))), 1)

    def test_symlink_target_refused(self):
        old = self.root / 'other.app'
        self.destination.rename(old)
        self.destination.symlink_to(old)
        with self.assertRaises(m.InstallError): self.run_install()
        self.assertEqual((old / 'version').read_text(), 'old')

    def test_other_bundle_not_replaced(self):
        (self.destination / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'another.app'}))
        with self.assertRaises(m.InstallError): self.run_install()
        self.old_intact()

    def test_concurrent_install_refused(self):
        (self.destination.parent / f'.{m.EXECUTABLE}.install-lock').mkdir()
        with self.assertRaises(m.InstallError): self.run_install()
        self.assertEqual((self.destination / 'version').read_text(), 'old')

    def test_missing_write_permission_explained(self):
        original = Path.mkdir
        def mkdir(path, *args, **kwargs):
            if path.name == f'.{m.EXECUTABLE}.install-lock': raise PermissionError('denied')
            return original(path, *args, **kwargs)
        with patch.object(Path, 'mkdir', mkdir):
            with self.assertRaisesRegex(m.InstallError, 'Keine Schreibrechte'): self.run_install()
        self.old_intact()

    def test_process_probe_fails_closed(self):
        for code in (0, 2):
            with self.subTest(code=code), patch.object(m.subprocess, 'run', return_value=subprocess.CompletedProcess([], code)):
                with self.assertRaises(m.InstallError): m.ensure_stopped()
        with patch.object(m.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)):
            m.ensure_stopped()

    def test_keyboard_interrupt_rolls_back(self):
        def move(source, destination):
            if source.name == 'new.app': raise KeyboardInterrupt()
            os.rename(source, destination)
        with self.assertRaises(m.InstallError): self.run_install(move=move)
        self.old_intact()

    def test_malformed_existing_bundle_refused(self):
        (self.destination / 'Contents/Info.plist').write_text('invalid plist')
        with self.assertRaisesRegex(m.InstallError, 'Bundle-ID'): self.run_install()
        self.old_intact()

    def test_unavailable_process_probe_aborts(self):
        with patch.object(m.subprocess, 'run', side_effect=PermissionError('process inspection denied')):
            with self.assertRaises(PermissionError): m.ensure_stopped()


if __name__ == '__main__':
    unittest.main(verbosity=2)
