#!/usr/bin/env python3
"""Offline integrity regression tests; does not download or touch the installed model."""
import hashlib
from pathlib import Path
import runpy
import tempfile
import unittest

module = runpy.run_path(str(Path(__file__).with_name('provision-local-model.py')))

class ProvisionTests(unittest.TestCase):
    def test_regular_git_blob_and_sha256(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixture.json'
            body = b'{"language":"de"}'
            path.write_bytes(body)
            entry = dict(size=len(body), gitBlob=hashlib.sha1(b'blob '+str(len(body)).encode()+b'\0'+body).hexdigest())
            self.assertEqual(module['verify'](path, entry), hashlib.sha256(body).hexdigest())
            path.write_bytes(body.replace(b'de',b'en'))
            with self.assertRaises(RuntimeError): module['verify'](path, entry)
    def test_lfs_size_and_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixture.bin'
            body = b'local fixture'
            path.write_bytes(body)
            entry = dict(size=len(body), lfsSha256=hashlib.sha256(body).hexdigest())
            module['verify'](path, entry)
            entry['size'] += 1
            with self.assertRaises(RuntimeError): module['verify'](path, entry)
            entry['size'] -= 1
            entry['lfsSha256'] = '0'*64
            with self.assertRaises(RuntimeError): module['verify'](path, entry)

if __name__ == '__main__': unittest.main(verbosity=2)
