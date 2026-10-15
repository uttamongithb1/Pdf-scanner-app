import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/core/models.dart';

void main() {
  group('File names', () {
    test('removes traversal and reserved characters', () {
      expect(safeStem(' ../Invoice:2026? '), 'Invoice2026');
      expect(safeStem('CON'), 'Scan_CON');
      expect(safeStem('...'), 'Scan');
    });
    test('does not duplicate timestamp on user titles', () {
      final title = defaultTitle(DateTime(2026, 10, 15, 9, 4, 3));
      expect(title, 'Scan_2026-10-15_090403');
      expect(safeStem(title), title);
    });
    test('preserves Unicode and clips by code point', () {
      expect(safeStem('विद्यालय'), 'विद्यालय');
      expect(safeStem('📄' * 140).runes.length, 100);
    });
  });
  group('Crop geometry', () {
    test('full image and inner convex quad are valid', () {
      expect(validCorners([0, 0, 1, 0, 1, 1, 0, 1]), isTrue);
      expect(validCorners([0.1, 0.1, 0.8, 0.2, 0.9, 0.8, 0.2, 0.9]), isTrue);
    });
    test('rejects crossing, non-finite, tiny and out-of-range quads', () {
      expect(validCorners([0, 0, 1, 1, 1, 0, 0, 1]), isFalse);
      expect(validCorners([double.nan, 0, 1, 0, 1, 1, 0, 1]), isFalse);
      expect(validCorners([0, 0, .01, 0, .01, .01, 0, .01]), isFalse);
      expect(validCorners([-1, 0, 1, 0, 1, 1, 0, 1]), isFalse);
    });
  });
  test('moving page preserves relative order and input', () {
    final source = ['A', 'B', 'C'];
    expect(moved(source, 0, 2), ['B', 'C', 'A']);
    expect(source, ['A', 'B', 'C']);
    expect(moved(source, 2, 0), ['C', 'A', 'B']);
  });
  test('serialised drafts preserve crop, rotation and page order', () {
    final page = PageAsset(
      id: 'p',
      path: '/source',
      thumb: '/thumb',
      width: 200,
      height: 300,
      rotation: 90,
      filter: 'bw',
      corners: const [.1, .1, .9, .1, .9, .9, .1, .9],
    );
    final original = Draft('s', [page], DateTime.utc(2026, 10, 15));
    final restored = Draft.fromJson(original.toJson());
    expect(restored.pages.single.toJson(), page.toJson());
    expect(restored.createdAt, original.createdAt);
  });
  test('copying an edit never replaces original source', () {
    const original = PageAsset(
      id: 'p',
      path: '/source',
      thumb: '/thumb',
      width: 200,
      height: 300,
    );
    final edit = original.copyWith(
      rotation: 90,
      filter: 'enhanced',
      thumb: '/preview',
    );
    expect(edit.path, original.path);
    expect(original.rotation, 0);
    expect(edit.rotation, 90);
  });
}
