#!/usr/bin/env python3
"""Verify packaging and exact preservation of the supplied PNG; no Downloads dependency."""
from pathlib import Path
import hashlib
import json
import tempfile
import unittest
from make_icon import build_icon, png_size
from project import ROOT

class IconTests(unittest.TestCase):
    def test_supplied_source_is_unchanged(self):
        source=ROOT/'Icon/CraftVoice.png'
        provenance=json.loads((ROOT/'Icon/source.json').read_text())
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),provenance['sha256'])
        self.assertEqual(png_size(source),(1254,1254))
    def test_invalid_source_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'checks') as path:
            source=Path(path)/'bad.png';source.write_bytes(b'not a PNG')
            with self.assertRaises(ValueError):png_size(source)
    def test_real_icns_pipeline_preserves_original(self):
        source=ROOT/'Icon/CraftVoice.png';original=source.read_bytes()
        with tempfile.TemporaryDirectory(prefix='icon-test-',dir=ROOT/'checks') as path:
            folder=Path(path)
            build_icon(source,folder/'resources',folder/'work')
            self.assertEqual((folder/'resources/CraftVoice.png').read_bytes(),original)
            self.assertEqual(source.read_bytes(),original)
            self.assertEqual((folder/'resources/AppIcon.icns').read_bytes()[:4],b'icns')
            self.assertEqual(len(list((folder/'work/AppIcon.iconset').glob('*.png'))),10)

if __name__ == '__main__':unittest.main(verbosity=2)
