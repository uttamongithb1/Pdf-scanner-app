import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf_scanner/core/models.dart';
import 'package:pdf_scanner/core/platform.dart';
import 'package:pdf_scanner/core/store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = ScannerPlatform();

  Future<List<PageAsset>> fixture(String id) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 240, 360),
      ui.Paint()..color = const ui.Color(0xffffffff),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(12, 12, 80, 120),
      ui.Paint()..color = const ui.Color(0xff4f46e5),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(240, 360);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final file = File('${(await getTemporaryDirectory()).path}/$id.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    final pages = await platform.stage(id, [file.path]);
    await file.delete();
    return pages;
  }

  Future<Map<String, dynamic>> export(String id, List<PageAsset> pages) async {
    await platform.call<Map>('initialise');
    if (Platform.isAndroid) await platform.call<String>('privateFolder');
    return Map<String, dynamic>.from(
      (await platform.call<Map>('export', {
        'id': id,
        'session': id,
        'title': 'विद्यालय-$id',
        'format': 'a4',
        'dpi': 150,
        'quality': 85,
        'margin': 5,
        'landscape': false,
        'saveImages': true,
        'keepOriginals': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'pages': pages.map((page) => page.toJson()).toList(),
      }))!,
    );
  }

  testWidgets('native stage/filter/PDF/render/rename/delete round trip', (
    tester,
  ) async {
    final id = const Uuid().v4();
    final pages = await fixture(id);
    for (final filter in filters) {
      final preview = await platform.preview(
        pages.first.copyWith(filter: filter),
      );
      expect(await File(preview).length(), greaterThan(100));
    }
    final data = await export(id, pages);
    final rendered = await platform.call<Map>('pdfPage', {...data, 'index': 0});
    expect(rendered!['count'], 1);
    final renamed = Map<String, dynamic>.from(
      (await platform.call<Map>('rename', {
        ...data,
        'newTitle': 'Renamed-$id',
      }))!,
    );
    expect(renamed['title'], 'Renamed-$id');
    final repeated = await platform.call<Map>('rename', {
      ...renamed,
      'newTitle': 'Renamed-$id',
    });
    expect(repeated!['uri'], renamed['uri']);
    await platform.call<void>('delete', {...renamed, 'deleteImages': true});
    final state = await platform.call<Map>('initialise');
    expect(
      (state!['receipts'] as List).any(
        (e) => e['id'] == id && e['deleted'] == true,
      ),
      isTrue,
    );
    await platform.call<void>('acknowledgeDeletion', {'id': id});
    await platform.call<void>('discard', {'session': id});
  });

  testWidgets(
    'crash-window rename and partial-delete intents replay on Android',
    (tester) async {
      if (!Platform.isAndroid) return;
      final id = const Uuid().v4();
      final pages = await fixture(id);
      final root = File(pages.first.path).parent.parent.parent;
      final data = await export(id, pages);
      final old = File.fromUri(Uri.parse(data['uri'] as String));
      final target = File('${old.parent.path}/Recovered-$id.pdf');
      final after = {
        ...data,
        'title': 'Recovered-$id',
        'uri': target.uri.toString(),
      };
      final mutation = File('${root.path}/mutations/$id.json');
      await mutation.parent.create(recursive: true);
      await mutation.writeAsString(
        jsonEncode({'kind': 'rename', 'before': data, 'after': after}),
        flush: true,
      );
      await old.rename(
        target.path,
      ); // Simulate process death before receipt/index update.
      var state = await platform.call<Map>('initialise');
      final receipt = (state!['receipts'] as List).firstWhere(
        (e) => e['id'] == id,
      );
      expect(receipt['uri'], target.uri.toString());
      expect(await mutation.exists(), isFalse);
      await mutation.writeAsString(
        jsonEncode({
          'kind': 'delete',
          'before': {...after, 'deleteImages': true},
        }),
        flush: true,
      );
      final images = List<String>.from(after['images'] as List);
      if (images.isNotEmpty)
        await File.fromUri(Uri.parse(images.first)).delete();
      state = await platform.call<Map>('initialise');
      expect(await target.exists(), isFalse);
      expect(
        (state!['receipts'] as List).any(
          (e) => e['id'] == id && e['deleted'] == true,
        ),
        isTrue,
      );
      expect(await mutation.exists(), isFalse);
      await platform.call<void>('acknowledgeDeletion', {'id': id});
      await platform.call<void>('discard', {'session': id});
    },
  );

  testWidgets(
    'native fifty-page output is readable and SQLite commits atomically',
    (tester) async {
      final id = const Uuid().v4();
      final pages = await fixture(id);
      final repeated = List<PageAsset>.generate(50, (_) => pages.first);
      final data = await export(id, repeated);
      final last = await platform.call<Map>('pdfPage', {...data, 'index': 49});
      expect(last!['count'], 50);
      final store = await LocalStore.open();
      try {
        await store.saveDraft(Draft(id, repeated, DateTime.now()));
        await store.commitExport(SavedDocument(data), id);
        expect(await store.draft(), isNull);
        expect((await store.documents()).any((doc) => doc.id == id), isTrue);
        await platform.call<void>('delete', {...data, 'deleteImages': true});
        await store.removeDocument(id);
        await platform.call<void>('acknowledgeDeletion', {'id': id});
        await platform.call<void>('discard', {'session': id});
      } finally {
        await store.db.close();
      }
    },
  );
}
