#!/usr/bin/env python3
"""Bounded self-window screenshots; never requests or changes privacy permissions."""
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
config = json.loads((root / 'project.json').read_text())
program = root / 'dist' / (config['name'] + '.app') / 'Contents/MacOS' / config['executable']
subprocess.run([str(root / 'tools/verify-signature.sh')], cwd=root, check=True)
render = '--render-content' in sys.argv
folder = root / ('checks/phase3-content-renders' if render else 'checks/phase3-screenshots')
folder.mkdir(exist_ok=True)
for mode in ['light', 'dark']:
    for state in ['empty', 'recording', 'transcribing', 'completed', 'error']:
        env = dict(os.environ, APP_SNAPSHOT=str(folder), APP_APPEARANCE=mode, APP_SNAPSHOT_STATE=state)
        if render: env['APP_SNAPSHOT_RENDER'] = '1'
        with (folder / (state + '-' + mode + '.log')).open('w') as log:
            result = subprocess.run([str(program)], env=env, cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=20)
        if result.returncode:
            raise SystemExit('Snapshot nicht verfügbar; keine Freigabe angefordert: ' + str(folder / (state + '-' + mode + '.log')))
        print(('PASS content render ' if render else 'PASS snapshot ') + state + ' ' + mode, flush=True)
paths = sorted(folder.glob('dictation-*-layout.json'))
for path in paths:
    layout = json.loads(path.read_text())
    if len([probe for probe in layout['probes'] if probe['kind'] == 'probe']) < 4:
        raise SystemExit('Keine gültigen Layoutmessungen: ' + str(path))
subprocess.run(['swift', '-module-cache-path', str(root / '.cache/swift'), str(root / 'tools/check-layout.swift'), *map(str, paths)], cwd=root, check=True)
