import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pdf_scanner/core/controller.dart';
import 'package:pdf_scanner/core/models.dart';
import 'package:pdf_scanner/core/monitoring.dart';
import 'package:pdf_scanner/core/platform.dart';
import 'package:pdf_scanner/core/store.dart';

class UnusedDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used');
}

class MemoryStore extends LocalStore {
  MemoryStore() : super(UnusedDatabase());
  bool failNextCommit = false;
  bool failNextRemove = false;
  final saved = <SavedDocument>[];
  @override
  Future<void> saveDocument(SavedDocument doc) async {
    if (failNextCommit) {
      failNextCommit = false;
      throw StateError('database unavailable');
    }
    saved.removeWhere((d) => d.id == doc.id);
    saved.add(doc);
  }

  @override
  Future<void> commitExport(SavedDocument doc, String session) async {
    await saveDocument(doc);
    await clearDraft(session);
  }

  @override
  Future<void> removeDocument(String id) async {
    if (failNextRemove) {
      failNextRemove = false;
      throw StateError('database unavailable');
    }
    saved.removeWhere((doc) => doc.id == id);
  }

  @override
  Future<void> clearDraft(String id) async {}
  @override
  Future<void> saveDraft(Draft d) async {}
  @override
  Future<List<SavedDocument>> documents() async => saved;
}

class ExportPlatform extends ScannerPlatform {
  int calls = 0;
  final methods = <String>[];
  Map<String, dynamic> recoveryState = {'receipts': [], 'recovery': []};
  Completer<void>? deleteGate;
  Completer<Map<String, dynamic>>? gate;
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    methods.add(method);
    if (method == 'retryRecovery') return recoveryState as T;
    if (method == 'delete') await deleteGate?.future;
    if (method == 'export') {
      calls++;
      final result =
          await (gate?.future ??
              Future.value(<String, dynamic>{
                'id': args!['id'],
                'session': args['session'],
                'title': 'Test',
                'uri': 'local:/PDFs/test.pdf',
                'pages': 1,
                'bytes': 1234,
                'createdAt': '2026-10-15T00:00:00Z',
                'images': <String>[],
              }));
      return result as T;
    }
    return null;
  }
}

Draft fixture() => Draft('session', [
  const PageAsset(
    id: 'p',
    path: '/source',
    thumb: '/thumb',
    width: 200,
    height: 300,
  ),
], DateTime.utc(2026));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<ScannerController> controller(
    MemoryStore store,
    ExportPlatform platform,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = ScannerController(
      store,
      await SharedPreferences.getInstance(),
      platform,
      Monitoring(),
    );
    c.draft = fixture();
    return c;
  }

  test('a second export cannot race before the first await', () async {
    final store = MemoryStore(),
        platform = ExportPlatform()..gate = Completer<Map<String, dynamic>>();
    final c = await controller(store, platform);
    final first = c.export(
      title: 'Test',
      format: 'a4',
      quality: 1,
      margin: 5,
      landscape: false,
    );
    await expectLater(
      c.export(
        title: 'Other',
        format: 'a4',
        quality: 1,
        margin: 5,
        landscape: false,
      ),
      throwsA(isA<ScanFailure>()),
    );
    platform.gate!.complete({
      'id': 'session',
      'session': 'session',
      'title': 'Test',
      'uri': 'local:/test.pdf',
      'pages': 1,
      'bytes': 123,
      'createdAt': '2026-10-15T00:00:00Z',
    });
    await first;
    expect(platform.calls, 1);
    expect(c.exporting, isFalse);
    expect(c.draft, isNull);
    c.dispose();
  });
  test(
    'index retry reuses the saved receipt instead of creating another PDF',
    () async {
      final store = MemoryStore()..failNextCommit = true;
      final platform = ExportPlatform();
      final c = await controller(store, platform);
      await expectLater(
        c.export(
          title: 'Test',
          format: 'a4',
          quality: 1,
          margin: 5,
          landscape: false,
        ),
        throwsA(isA<ScanFailure>().having((e) => e.code, 'code', 'index')),
      );
      expect(c.draft, isNotNull);
      expect(c.pendingCommit, isNotNull);
      await expectLater(c.discard(), throwsA(isA<ScanFailure>()));
      await c.export(
        title: 'Test',
        format: 'a4',
        quality: 1,
        margin: 5,
        landscape: false,
      );
      expect(platform.calls, 1);
      expect(store.saved.length, 1);
      expect(c.draft, isNull);
      c.dispose();
    },
  );
  test(
    'delete failure preserves recovery intent until SQLite removal succeeds',
    () async {
      final store = MemoryStore()..failNextRemove = true;
      final platform = ExportPlatform();
      final c = await controller(store, platform);
      final doc = SavedDocument({
        'id': 'old',
        'title': 'Old',
        'uri': 'local:/old.pdf',
        'createdAt': '2026-01-01',
        'pages': 1,
        'bytes': 100,
      });
      store.saved.add(doc);
      await expectLater(c.delete(doc, images: true), throwsStateError);
      expect(c.needsRecovery, isTrue);
      expect(platform.methods, isNot(contains('acknowledgeDeletion')));
      platform.recoveryState = {
        'receipts': [
          {'id': 'old', 'deleted': true},
        ],
        'recovery': [],
      };
      await c.retryRecovery();
      expect(store.saved, isEmpty);
      expect(c.needsRecovery, isFalse);
      expect(platform.methods, contains('acknowledgeDeletion'));
      c.dispose();
    },
  );

  test('rename/delete/export cannot overlap a pending delete', () async {
    final store = MemoryStore();
    final platform = ExportPlatform()..deleteGate = Completer<void>();
    final c = await controller(store, platform);
    final doc = SavedDocument({'id': 'old'});
    final first = c.delete(doc, images: false);
    expect(c.busy, isTrue);
    await expectLater(c.rename(doc, 'Other'), throwsA(isA<ScanFailure>()));
    await expectLater(
      c.delete(doc, images: false),
      throwsA(isA<ScanFailure>()),
    );
    platform.deleteGate!.complete();
    await first;
    expect(c.busy, isFalse);
    c.dispose();
  });

  test('invalid export options do not reach native code', () async {
    final platform = ExportPlatform();
    final c = await controller(MemoryStore(), platform);
    await expectLater(
      c.export(
        title: 'Bad',
        format: 'a4',
        quality: 99,
        margin: 5,
        landscape: false,
      ),
      throwsA(isA<ScanFailure>()),
    );
    expect(c.exporting, isFalse);
    expect(platform.calls, 0);
    c.dispose();
  });

  test('unresolved provider operations remain visible after retry', () async {
    final platform = ExportPlatform()
      ..recoveryState = {
        'receipts': [],
        'recovery': [
          {'id': 'pending', 'kind': 'exportRollback'},
        ],
      };
    final c = await controller(MemoryStore(), platform);
    await c.retryRecovery();
    expect(c.needsRecovery, isTrue);
    expect(c.recovery.single['id'], 'pending');
    c.dispose();
  });
}
