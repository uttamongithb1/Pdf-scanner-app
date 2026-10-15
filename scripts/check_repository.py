#!/usr/bin/env python3
"""Dependency-free structural checks; not a substitute for native compilation."""
from pathlib import Path
import json
import plistlib
import re
import xml.etree.ElementTree as ET
import zipfile
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]


def check_png(path):
    """Validate PNG framing, checksums and compressed pixels without extra packages."""
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', f'Invalid PNG signature: {path}'
    offset, compressed, dimensions = 8, bytearray(), None
    while offset < len(data):
        assert offset + 12 <= len(data), f'Truncated PNG: {path}'
        length = struct.unpack_from('>I', data, offset)[0]
        tag = data[offset + 4:offset + 8]
        end = offset + 8 + length
        assert end + 4 <= len(data), f'Truncated PNG chunk: {path}'
        payload = data[offset + 8:end]
        crc = struct.unpack_from('>I', data, end)[0]
        assert zlib.crc32(tag + payload) == crc, f'PNG checksum mismatch: {path}'
        if dimensions is None:
            assert tag == b'IHDR' and length == 13, f'Missing PNG header: {path}'
            dimensions = struct.unpack_from('>II', payload)
            assert all(0 < size <= 4096 for size in dimensions), f'Invalid PNG dimensions: {path}'
        if tag == b'IDAT':
            compressed.extend(payload)
        offset = end + 4
        if tag == b'IEND':
            assert length == 0 and offset == len(data), f'Invalid PNG end: {path}'
            inflater = zlib.decompressobj()
            pixels = inflater.decompress(compressed, 32 * 1024 * 1024)
            assert pixels and inflater.eof and not inflater.unused_data, f'Invalid PNG pixels: {path}'
            return dimensions
    raise AssertionError(f'Missing PNG end: {path}')


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
    for path in (ROOT / 'ios/Runner/Assets.xcassets').rglob('Contents.json'):
        catalog = json.loads(path.read_text())
        for image in catalog.get('images', []):
            if 'filename' not in image:
                continue
            asset = path.parent / image['filename']
            dimensions = check_png(asset)
            if 'size' in image:
                scale = float(image['scale'].rstrip('x'))
                expected = tuple(round(float(n) * scale) for n in image['size'].split('x'))
                assert dimensions == expected, f'Incorrect icon size: {asset}'
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
