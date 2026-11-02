#!/usr/bin/env python3
"""Preflight tests with synthetic keychain output; no real key or signing."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import build
import project


class ConfigTests(unittest.TestCase):
    def setUp(self): self.config = dict(project.load_config())
    def preflight(self, identities):
        with patch('sys.argv', ['build.py', '--check-signing']), patch.object(build.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=identities)), contextlib.redirect_stdout(io.StringIO()):
            build.main()
    def test_microphone_purpose_and_local_recognition(self):
        info = build.bundle_info(self.config)
        self.assertIn('NSMicrophoneUsageDescription', info)
        self.assertIn('diesem Mac', info['NSMicrophoneUsageDescription'])
        self.assertNotIn('NSSpeechRecognitionUsageDescription', info)
        self.assertEqual(info['CFBundleIdentifier'], self.config['bundle_id'])
        self.assertTrue(info['LSUIElement'])
        self.assertEqual(info['CFBundleIconFile'], 'AppIcon.icns')
    def test_authorized_identity(self):
        self.preflight('1) ' + self.config['signing_fingerprint'] + ' "Craft Code Signing"')
    def test_missing_identity_rejected(self):
        with self.assertRaises(RuntimeError): self.preflight('0 valid identities found')
    def test_wrong_identity_rejected(self):
        with self.assertRaises(RuntimeError): self.preflight('1) ' + '0'*40 + ' "Craft Code Signing"')
    def test_wrong_certificate_name_rejected(self):
        with self.assertRaises(RuntimeError): self.preflight('1) ' + self.config['signing_fingerprint'] + ' "Other Certificate"')
    def test_compile_only_cannot_fake_signing_check(self):
        with patch('sys.argv', ['build.py', '--check-signing', '--compile-only']), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            build.main()
    def test_previous_build_preserved_on_recovery_failure(self):
        with tempfile.TemporaryDirectory(prefix='publication-test-', dir=project.ROOT/'checks') as folder:
            with self.assertRaises(RuntimeError):
                with build.candidate_directory(Path(folder)) as candidate:
                    (candidate / 'previous.app').mkdir()
                    raise RuntimeError('simulated failed recovery')
            self.assertTrue((candidate / 'previous.app').is_dir())
    def test_failed_candidate_without_backup_cleaned(self):
        with tempfile.TemporaryDirectory(prefix='publication-test-', dir=project.ROOT/'checks') as folder:
            with self.assertRaises(RuntimeError):
                with build.candidate_directory(Path(folder)) as candidate:
                    raise RuntimeError('simulated failed candidate')
            self.assertFalse(candidate.exists())
    def test_successful_candidate_cleaned(self):
        with tempfile.TemporaryDirectory(prefix='publication-test-', dir=project.ROOT/'checks') as folder:
            with build.candidate_directory(Path(folder)) as candidate: pass
            self.assertFalse(candidate.exists())
    def test_config_cannot_change_signer(self):
        with tempfile.TemporaryDirectory(prefix='config-test-', dir=project.ROOT/'checks') as folder:
            invalid = dict(self.config, signing_fingerprint='0'*40)
            Path(folder, 'project.json').write_text(json.dumps(invalid))
            with patch.object(project, 'ROOT', Path(folder)), self.assertRaises(ValueError): project.load_config()


if __name__ == '__main__': unittest.main(verbosity=2)
