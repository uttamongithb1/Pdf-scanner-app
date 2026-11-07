"""Public lockfile transfer must survive GitHub's 4 KiB annotation API cap."""
import contextlib
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from scripts import ci_lockfiles


class LockfileTransferTests(unittest.TestCase):
    def setUp(self):
        self.previous = Path.cwd()
        self.temp = tempfile.TemporaryDirectory()
        os.chdir(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(os.chdir, self.previous)

    def annotations(self, data):
        Path('pubspec.lock').write_bytes(data)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            ci_lockfiles.emit('pubspec.lock')
        Path('pubspec.lock').unlink()
        result = []
        for line in output.getvalue().splitlines():
            message = line.split('::', 2)[2]
            self.assertLess(len(message), 4096)
            result.append({'title': ci_lockfiles.TITLE, 'message': message})
        return result

    def fetch(self, annotations):
        replies = [
            {'headSha': 'test-sha', 'jobs': [{'databaseId': 123}]},
            {'nameWithOwner': 'owner/repo'}, annotations,
        ]
        with patch.object(ci_lockfiles, 'gh', side_effect=replies), patch.object(
                ci_lockfiles.subprocess, 'check_output', return_value='test-sha\n'):
            with contextlib.redirect_stdout(io.StringIO()):
                ci_lockfiles.fetch('456')

    def test_multi_chunk_round_trip(self):
        # Large enough to cross chunk boundaries even after compression.
        data = b'# public dependency lock\n' + os.urandom(12000).hex().encode()
        annotations = self.annotations(data)
        self.assertGreater(len(annotations), 1)
        self.fetch(list(reversed(annotations)))
        self.assertEqual(Path('pubspec.lock').read_bytes(), data)

    def test_incomplete_transfer_does_not_write_file(self):
        annotations = self.annotations(os.urandom(12000).hex().encode())
        with self.assertRaisesRegex(ValueError, 'Incomplete lockfile'):
            self.fetch(annotations[:-1])
        self.assertFalse(Path('pubspec.lock').exists())

    def test_checksum_mismatch_does_not_write_file(self):
        annotations = self.annotations(b'packages: {}\n')
        fields = annotations[0]['message'].split()
        fields[1] = '0' * 64
        annotations[0]['message'] = ' '.join(fields)
        with self.assertRaisesRegex(ValueError, 'Checksum mismatch'):
            self.fetch(annotations)
        self.assertFalse(Path('pubspec.lock').exists())

    def test_credentials_cannot_be_published(self):
        with self.assertRaisesRegex(ValueError, 'Only public dependency lockfiles'):
            ci_lockfiles.emit('android/key.properties')


if __name__ == '__main__':
    unittest.main()
