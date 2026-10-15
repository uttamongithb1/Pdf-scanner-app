#!/usr/bin/env python3
"""Dependency-free structural checks; not a substitute for native compilation."""
from pathlib import Path
import json
import plistlib
import re
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
def check():
    for name in ('README.md', 'PRD.md', 'DESIGN_SYSTEM.md'):
        text = (ROOT / name).read_text()
        assert text.count('```') % 2 == 0, name
        for link in re.findall(r'\]\(([^)]+)\)', text):
            if not link.startswith(('http:', 'https:', '#')):
                assert (ROOT / link.split('#')[0]).exists(), (name, link)
    for path in (ROOT / 'ios').rglob('*.plist'):
        plistlib.loads(path.read_bytes())
    for path in (ROOT / 'android/app/src').rglob('*.xml'):
        ET.parse(path)
    for path in (ROOT / 'ios/Runner/Assets.xcassets').rglob('*.json'):
        json.loads(path.read_text())
    project = (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
    assert 'ScannerEngine.swift in Sources' in project
    assert '{{' not in project
    assert 'IPHONEOS_DEPLOYMENT_TARGET = 16.0' in project
    manifest = (ROOT / 'android/app/src/main/AndroidManifest.xml').read_text()
    assert 'MANAGE_EXTERNAL_STORAGE' not in manifest
    assert 'READ_MEDIA_IMAGES' not in manifest
    assert 'firebase_crashlytics_collection_enabled' in manifest
    info = plistlib.loads((ROOT / 'ios/Runner/Info.plist').read_bytes())
    assert info['FirebaseCrashlyticsCollectionEnabled'] is False
    assert info['FIREBASE_ANALYTICS_COLLECTION_ENABLED'] is False
    assert info['UIFileSharingEnabled'] is True
    with zipfile.ZipFile(ROOT / 'android/gradle/wrapper/gradle-wrapper.jar') as jar:
        assert 'org/gradle/wrapper/GradleWrapperMain.class' in jar.namelist()
    for path in (ROOT / 'lib').rglob('*.dart'):
        for imp in re.findall(r"import '([^']+)'", path.read_text()):
            if not imp.startswith(('package:', 'dart:')):
                assert (path.parent / imp).exists(), (path, imp)
    print('Repository checks passed: platform metadata, wrapper, imports, privacy defaults and documentation links.')
if __name__ == '__main__':
    check()
