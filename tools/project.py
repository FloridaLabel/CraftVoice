"""Validated configuration shared by build, verification and installation."""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
FINGERPRINT = 'C357A87EC48947E3C69F9C9925D7EE7FD34A1003'


def load_config():
    value = json.loads((ROOT / 'project.json').read_text())
    name = value['name']
    if not name.strip() or name != name.strip() or len(name) > 80 or name in ('.', '..') or any(c in name for c in '/:\\') or any(ord(c) < 32 for c in name):
        raise ValueError('Ungültiger App-Name.')
    if not re.fullmatch(r'[a-z][a-z0-9-]*(?:\.[a-z][a-z0-9-]*){2,}', value['bundle_id']):
        raise ValueError('Ungültige oder noch nicht konfigurierte Bundle-ID.')
    if not re.fullmatch(r'Craft[0-9a-f]{8}', value['executable']):
        raise ValueError('Ungültiger interner Programmname.')
    if value['certificate_name'] != 'Craft Code Signing' or value['signing_fingerprint'] != FINGERPRINT:
        raise ValueError('Ausschließlich die freigegebene Signieridentität Craft Code Signing ist zulässig.')
    return value
