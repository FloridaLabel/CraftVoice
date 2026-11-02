#!/usr/bin/env python3
"""Synthetic tests, no real codesign, keychain changes, build or installation."""
from pathlib import Path
import hashlib
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import verify_signature as module
from project import load_config


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='verify-test-', dir=module.ROOT / 'checks')
        self.root = Path(self.temp.name)
        self.app = self.root / 'Beispiel mit Leerzeichen.app'
        (self.app / 'Contents').mkdir(parents=True)
        self.config = dict(load_config())
        self.certificate = b'public certificate fixture'
        self.config['signing_fingerprint'] = hashlib.sha1(self.certificate).hexdigest().upper()
        self.info = {'CFBundleIdentifier': self.config['bundle_id'], 'CFBundleExecutable': self.config['executable']}
        self.write_info()
        self.missing = False
        self.bad_signature = False
        self.bad_hash = False

    def write_info(self):
        (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps(self.info))

    def tearDown(self): self.temp.cleanup()

    def codesign(self, args, **kwargs):
        self.assertEqual(args[0], '/usr/bin/codesign')
        if '--verify' in args:
            self.assertIn('-R=identifier "' + self.config['bundle_id'] + '"', args)
            if self.bad_signature: raise subprocess.CalledProcessError(1, args)
        if '--display' in args:
            prefix = next(arg.split('=', 1)[1] for arg in args if arg.startswith('--extract-certificates='))
            if not self.missing: Path(prefix + '0').write_bytes(b'wrong' if self.bad_hash else self.certificate)
        return subprocess.CompletedProcess(args, 0, stdout='synthetic requirement', stderr='')

    def verify(self, expected=None):
        with patch.object(module, 'ROOT', self.root), patch.object(module, 'load_config', return_value=self.config), patch.object(module.subprocess, 'run', side_effect=self.codesign):
            module.verify(self.app, expected or self.config['signing_fingerprint'])
        self.assertFalse(list((self.root / 'checks').glob('cert-*')))

    def test_success(self): self.verify()
    def test_signature_rejected(self):
        self.bad_signature = True
        with self.assertRaises(subprocess.CalledProcessError): self.verify()
    def test_missing_export(self):
        self.missing = True
        with self.assertRaisesRegex(ValueError, 'Kein Signierzertifikat'): self.verify()
    def test_bad_fingerprint(self):
        self.bad_hash = True
        with self.assertRaisesRegex(ValueError, 'Falscher Zertifikatsfingerabdruck'): self.verify()
    def test_other_identity(self):
        with self.assertRaisesRegex(ValueError, 'Nicht freigegebener'): self.verify('0' * 40)
    def test_other_bundle(self):
        self.info['CFBundleIdentifier'] = 'de.example.other'; self.write_info()
        with self.assertRaisesRegex(ValueError, 'Bundle-ID'): self.verify()
    def test_other_executable(self):
        self.info['CFBundleExecutable'] = 'other'; self.write_info()
        with self.assertRaisesRegex(ValueError, 'Programmname'): self.verify()


if __name__ == '__main__': unittest.main(verbosity=2)
