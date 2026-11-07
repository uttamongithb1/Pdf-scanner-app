#!/usr/bin/env python3
"""Publish only pinned successful build artifacts, never relabel an unsigned IPA.

Run on GitHub-hosted Linux: Actions artifact redirects are blocked in the Arena
workspace. GH_TOKEN must have contents:write and actions:read. Secrets are never
written to files or included in command arguments.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APP_PATHS = ['lib', 'android', 'ios', 'pubspec.yaml', 'pubspec.lock',
             'analysis_options.yaml', 'integration_test', 'test', 'scripts']
# Release-only tooling/tests do not change the previously tested application.
RELEASE_ONLY = [':(exclude)scripts/publish_release.py', ':(exclude)test/release_test.py']
REQUIRED_JOBS = {'shared', 'android', 'android-integration', 'ios', 'pdf-writer'}


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def api(path):
    return json.loads(command('gh', 'api', path))


def validate_manifest(manifest):
    if not re.fullmatch(r'v\d+\.\d+\.\d+-preview\.\d+', manifest['tag']):
        raise ValueError('Only explicitly named preview tags are supported')
    for key in ['source_commit', 'target_commit']:
        if not re.fullmatch(r'[0-9a-f]{40}', manifest[key]):
            raise ValueError('A full immutable commit SHA is required')
    if not isinstance(manifest['run_id'], int) or manifest['run_id'] <= 0:
        raise ValueError('Invalid build run ID')
    if set(manifest['artifacts']) != {'android-release-development-apk', 'ios-simulator-app'}:
        raise ValueError('Expected one development APK and one simulator archive')
    for artifact in manifest['artifacts'].values():
        if not isinstance(artifact['id'], int) or artifact['id'] <= 0:
            raise ValueError('Invalid artifact ID')
        if not re.fullmatch(r'sha256:[0-9a-f]{64}', artifact['digest']):
            raise ValueError('Artifact digest must be pinned')


def validate_run(manifest, run, jobs, artifacts):
    if run['head_sha'] != manifest['source_commit'] or run['conclusion'] != 'success' or run['status'] != 'completed':
        raise ValueError('Release requires the exact completed successful build')
    successful = {job['name'] for job in jobs if job['conclusion'] == 'success'}
    if not REQUIRED_JOBS.issubset(successful):
        raise ValueError('A required native build/test job did not pass')
    for name, expected in manifest['artifacts'].items():
        actual = next((item for item in artifacts if item['id'] == expected['id']), None)
        if actual is None or actual['name'] != name or actual['expired'] or actual.get('digest') != expected['digest']:
            raise ValueError(f'Pinned artifact missing, expired or changed: {name}')


def verify_apk(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError('Corrupt APK')
        names = archive.namelist()
        if 'AndroidManifest.xml' not in names or not any(name.endswith('/libapp.so') for name in names):
            raise ValueError('Expected a release-mode Flutter Android APK')


def verify_simulator(path):
    with tarfile.open(path, 'r:gz') as archive:
        info = archive.extractfile('Runner.app/Info.plist')
        if info is None:
            raise ValueError('Simulator Info.plist is absent')
        metadata = plistlib.loads(info.read())
        if metadata.get('CFBundleIdentifier') != 'com.lumen.pdfscanner':
            raise ValueError('Unexpected simulator application ID')
        if 'iPhoneSimulator' not in metadata.get('CFBundleSupportedPlatforms', []):
            raise ValueError('Archive is not an iOS simulator app')
        if not archive.getmember('Runner.app/Runner').isfile():
            raise ValueError('Simulator executable missing')


def sha256(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def main():
    manifest = json.loads((ROOT / 'docs/releases/preview.json').read_text())
    validate_manifest(manifest)
    repo = os.environ['GH_REPO']
    if repo != 'uttamongithb1/Pdf-scanner-app':
        raise ValueError('Release repository does not match the pinned artifacts')
    run_id = manifest['run_id']
    base = f'repos/{repo}'
    run = api(f'{base}/actions/runs/{run_id}')
    jobs = api(f'{base}/actions/runs/{run_id}/jobs?per_page=100')['jobs']
    artifacts = api(f'{base}/actions/runs/{run_id}/artifacts?per_page=100')['artifacts']
    validate_run(manifest, run, jobs, artifacts)
    command('git', 'merge-base', '--is-ancestor', manifest['source_commit'], manifest['target_commit'])
    command('git', 'diff', '--exit-code', manifest['source_commit'], manifest['target_commit'], '--', *APP_PATHS, *RELEASE_ONLY)
    # The requested tag target must be part of main, not an arbitrary branch.
    command('git', 'merge-base', '--is-ancestor', manifest['target_commit'], 'origin/main')
    tag = manifest['tag']
    existing = api(f'{base}/releases?per_page=100')
    if any(release['tag_name'] == tag for release in existing):
        raise ValueError('Release already exists; refusing to overwrite published assets')
    with tempfile.TemporaryDirectory(prefix='scanner-release-') as directory:
        temporary = Path(directory)
        for name in manifest['artifacts']:
            command('gh', 'run', 'download', str(run_id), '--repo', repo,
                    '--name', name, '--dir', str(temporary / name))
        apk = temporary / 'android-release-development-apk/app-release.apk'
        simulator = temporary / 'ios-simulator-app/ios-simulator-app.tar.gz'
        verify_apk(apk)
        verify_simulator(simulator)
        output = temporary / 'release'
        output.mkdir()
        shutil.copyfile(apk, output / f'pdf-scanner-{tag}-android.apk')
        shutil.copyfile(simulator, output / f'pdf-scanner-{tag}-ios-simulator.tar.gz')
        shutil.copyfile(ROOT / 'docs/releases/NOTES.md', output / 'INSTALL.md')
        (output / 'BUILD_PROVENANCE.json').write_text(json.dumps(manifest, indent=2) + '\n')
        checksums = ''.join(f'{sha256(path)}  {path.name}\n'
                            for path in sorted(output.iterdir()))
        (output / 'SHA256SUMS.txt').write_text(checksums)
        files = [str(path) for path in sorted(output.iterdir())]
        # Upload all assets in draft state; only expose the release after success.
        command('gh', 'release', 'create', tag, '--repo', repo, '--target', manifest['target_commit'],
                '--draft', '--prerelease', '--title', 'PDF Scanner 0.1.0 — Development Preview',
                '--notes-file', str(ROOT / 'docs/releases/NOTES.md'))
        command('gh', 'release', 'upload', tag, '--repo', repo, *files)
        command('gh', 'release', 'edit', tag, '--repo', repo, '--draft=false', '--prerelease')
        print(f'Published https://github.com/{repo}/releases/tag/{tag}', flush=True)


if __name__ == '__main__':
    main()
