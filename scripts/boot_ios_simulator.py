#!/usr/bin/env python3
"""Choose an installed iPhone runtime instead of pinning a runner-specific name."""
import json
import os
import subprocess

payload = json.loads(subprocess.check_output(
    ['xcrun', 'simctl', 'list', 'devices', 'available', '--json'], text=True))
devices = [device for runtime, values in payload['devices'].items()
           if '.iOS-' in runtime for device in values
           if device.get('isAvailable') and device['name'].startswith('iPhone')]
if not devices:
    raise SystemExit('No installed available iPhone simulator runtime')
devices.sort(key=lambda device: device['state'] != 'Booted')
device = devices[0]
if device['state'] != 'Booted':
    subprocess.run(['xcrun', 'simctl', 'boot', device['udid']], check=True)
subprocess.run(['xcrun', 'simctl', 'bootstatus', device['udid'], '-b'], check=True)
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    output.write(f"device={device['udid']}\n")
print(f"Ready: {device['name']} ({device['udid']})")
