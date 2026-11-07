#!/usr/bin/env python3
"""Run real native tests and sample whole-app Android PSS/RSS (not Dart heap only).

These are emulator/debug-build samples, not physical-device release benchmarks;
short peaks between samples and hosted scanner processes are not measured.
"""
import json
from pathlib import Path
import re
import subprocess
import threading
import time

samples = []
stop = threading.Event()
started = time.monotonic()


def sample():
    while not stop.is_set():
        try:
            output = subprocess.run(
                ['adb', 'shell', 'dumpsys', 'meminfo', 'com.lumen.pdfscanner'],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                text=True, timeout=3).stdout
            pss = re.search(r'TOTAL PSS:\s*(\d+)', output)
            rss = re.search(r'TOTAL RSS:\s*(\d+)', output)
            if pss and rss:
                samples.append({'seconds': round(time.monotonic() - started, 2),
                                'pss_kib': int(pss[1]), 'rss_kib': int(rss[1])})
        except (subprocess.SubprocessError, OSError):
            pass
        stop.wait(2)


worker = threading.Thread(target=sample, daemon=True)
worker.start()
try:
    result = subprocess.run(['flutter', 'test', 'integration_test/native_flow_test.dart',
                             '--reporter', 'expanded', '--fail-fast'])
finally:
    stop.set()
    worker.join(timeout=5)

report = {
    'environment': 'Android API 35 x86_64 emulator, debug integration build',
    'scope': 'Whole app including native PDF/image pipeline; excludes hosted scanner',
    'caveat': 'Two-second sampling can miss peaks; not physical-device qualification',
    'seconds': round(time.monotonic() - started, 2),
    'max_sampled_pss_kib': max((x['pss_kib'] for x in samples), default=None),
    'max_sampled_rss_kib': max((x['rss_kib'] for x in samples), default=None),
    'samples': samples,
}
path = Path('build/reports/android-native-memory.json')
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(report, indent=2) + '\n')
print(f"Emulator/debug native memory report: {len(samples)} samples; "
      f"max sampled PSS={report['max_sampled_pss_kib']} KiB; "
      f"max sampled RSS={report['max_sampled_rss_kib']} KiB", flush=True)
raise SystemExit(result.returncode)
