#!/usr/bin/env python3
"""Bundle only the own synthetic integration host, never install it."""
from pathlib import Path
import json
import plistlib
import shutil
import subprocess
r=Path(__file__).resolve().parent.parent
config=json.loads((r/'project.json').read_text())
app=r/'checks/CraftVoice Integration Test.app'
contents=app/'Contents';(contents/'MacOS').mkdir(parents=True,exist_ok=True)
shutil.copy2(r/'.build/release/CraftVoiceIntegrationProbe',contents/'MacOS/CraftVoiceIntegrationProbe')
info=dict(CFBundleIdentifier='app.craftvoice.desktop.integrationtest',CFBundleExecutable='CraftVoiceIntegrationProbe',
 CFBundleName='CraftVoice Integration Test',CFBundlePackageType='APPL',LSMinimumSystemVersion='26.0',
 NSPrincipalClass='NSApplication',CraftVoiceTestStatePath=str(r/'checks/phase3-host-state.json'))
(contents/'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['/usr/bin/codesign','--force','--sign',config['signing_fingerprint'],str(app)],check=True)
subprocess.run(['/usr/bin/codesign','--verify','--strict',str(app)],check=True)
print(app)
