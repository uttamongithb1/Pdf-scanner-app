#!/usr/bin/env python3
"""CI must prove a production build cannot silently fall back to debug signing."""
import os
from pathlib import Path
import subprocess

if Path('android/key.properties').exists():
    raise SystemExit('Signing guard test requires no private signing configuration')
environment = dict(os.environ)
environment.pop('LUMEN_ALLOW_DEBUG_SIGNING', None)
result = subprocess.run(['flutter', 'build', 'apk', '--release'], env=environment,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
if result.returncode == 0 or 'Release signing is not configured' not in result.stdout:
    print(result.stdout[-6000:])
    raise SystemExit('Release signing guard did not reject the unconfigured production build')
print('PASS: unconfigured production release rejected; no silent debug-signing fallback.')
