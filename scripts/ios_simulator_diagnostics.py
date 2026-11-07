#!/usr/bin/env python3
"""Expose bounded, synthetic-CI simulator failure evidence via check annotations."""
from pathlib import Path
import subprocess
import sys


def notice(title, text):
    escaped = text[-3000:].replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print(f'::notice title={title}::{escaped}', flush=True)


try:
    result = subprocess.run(
        ['xcrun', 'simctl', 'spawn', sys.argv[1], 'log', 'show', '--last', '5m',
         '--style', 'compact', '--predicate', 'process == "Runner"'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=20)
    notice('Simulator Runner diagnostics', result.stdout)
except (subprocess.SubprocessError, OSError) as error:
    notice('Simulator diagnostic unavailable', type(error).__name__)

reports = Path.home() / 'Library/Logs/DiagnosticReports'
if reports.exists():
    for report in sorted(reports.glob('Runner*'), key=lambda p: p.stat().st_mtime, reverse=True)[:2]:
        try:
            notice('Simulator crash report', report.read_text(errors='replace'))
        except OSError:
            pass
