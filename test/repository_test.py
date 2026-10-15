"""Regression tests for asset failures found by the actual iOS build."""
import tempfile
import unittest
from pathlib import Path
from scripts.check_repository import ROOT, check_png


class AssetValidationTests(unittest.TestCase):
    def test_all_catalog_pngs_are_readable(self):
        for asset in (ROOT / 'ios/Runner/Assets.xcassets').rglob('*.png'):
            with self.subTest(asset=asset.name):
                check_png(asset)

    def test_empty_launch_placeholder_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            asset = Path(folder) / 'LaunchImage.png'
            asset.write_bytes(b'')
            with self.assertRaisesRegex(AssertionError, 'Invalid PNG signature'):
                check_png(asset)

    def test_corrupt_png_checksum_is_rejected(self):
        source = ROOT / 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png'
        data = bytearray(source.read_bytes())
        data[29] ^= 1  # IHDR CRC, not pixel data.
        with tempfile.TemporaryDirectory() as folder:
            asset = Path(folder) / 'corrupt.png'
            asset.write_bytes(data)
            with self.assertRaisesRegex(AssertionError, 'PNG checksum mismatch'):
                check_png(asset)

    def test_truncated_png_is_rejected(self):
        source = ROOT / 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png'
        with tempfile.TemporaryDirectory() as folder:
            asset = Path(folder) / 'truncated.png'
            asset.write_bytes(source.read_bytes()[:-5])
            with self.assertRaisesRegex(AssertionError, 'Truncated PNG'):
                check_png(asset)


if __name__ == '__main__':
    unittest.main()
