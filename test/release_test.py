"""Fail-closed tests for publishing prebuilt Android/simulator release assets."""
import copy
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import tarfile
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('publisher', ROOT / 'scripts/publish_release.py')
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT / 'docs/releases/preview.json').read_text())
        self.run = {'head_sha': self.manifest['source_commit'], 'status': 'completed', 'conclusion': 'success'}
        self.jobs = [{'name': name, 'conclusion': 'success'} for name in publisher.REQUIRED_JOBS]
        self.artifacts = [{'id': item['id'], 'digest': item['digest'], 'name': name, 'expired': False}
                          for name, item in self.manifest['artifacts'].items()]

    def test_pinned_preview_is_valid(self):
        publisher.validate_manifest(self.manifest)
        publisher.validate_run(self.manifest, self.run, self.jobs, self.artifacts)

    def test_stable_tag_is_rejected(self):
        self.manifest['tag'] = 'v1.0.0'
        with self.assertRaises(ValueError):
            publisher.validate_manifest(self.manifest)

    def test_failure_or_different_source_cannot_publish(self):
        for change in [{'conclusion': 'failure'}, {'status': 'in_progress'}, {'head_sha': '0' * 40}]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                publisher.validate_run(self.manifest, {**self.run, **change}, self.jobs, self.artifacts)

    def test_missing_native_test_job_cannot_publish(self):
        with self.assertRaises(ValueError):
            publisher.validate_run(self.manifest, self.run, [], self.artifacts)

    def test_changed_or_expired_artifact_cannot_publish(self):
        for change in [{'expired': True}, {'id': 1}, {'digest': 'sha256:' + '0' * 64}]:
            items = copy.deepcopy(self.artifacts)
            items[0].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                publisher.validate_run(self.manifest, self.run, self.jobs, items)

    def test_non_release_apk_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'test.apk'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('AndroidManifest.xml', b'fixture')
            with self.assertRaises(ValueError):
                publisher.verify_apk(path)
            with zipfile.ZipFile(path, 'a') as archive:
                archive.writestr('lib/arm64-v8a/libapp.so', b'fixture')
            publisher.verify_apk(path)

    def test_device_archive_cannot_be_labeled_simulator(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'ios.tar.gz'
            for platform in ['iPhoneOS', 'iPhoneSimulator']:
                with tarfile.open(path, 'w:gz') as archive:
                    for name, data in {
                        'Runner.app/Info.plist': plistlib.dumps({
                            'CFBundleIdentifier': 'com.lumen.pdfscanner',
                            'CFBundleSupportedPlatforms': [platform]}),
                        'Runner.app/Runner': b'fixture',
                    }.items():
                        info = tarfile.TarInfo(name)
                        info.size = len(data)
                        archive.addfile(info, io.BytesIO(data))
                if platform == 'iPhoneOS':
                    with self.assertRaises(ValueError):
                        publisher.verify_simulator(path)
                else:
                    publisher.verify_simulator(path)


if __name__ == '__main__':
    unittest.main()
