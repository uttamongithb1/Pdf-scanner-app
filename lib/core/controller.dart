import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'monitoring.dart';
import 'platform.dart';
import 'store.dart';

class ScannerController extends ChangeNotifier {
  ScannerController(this.store, this.prefs, this.platform, this.monitoring);
  final LocalStore store;
  final SharedPreferences prefs;
  final ScannerPlatform platform;
  final Monitoring monitoring;
  List<SavedDocument> documents = [];
  Draft? draft;
  SavedDocument? pendingCommit;
  bool busy = false, exporting = false;
  String location = 'App storage', phase = 'Preparing…';
  List<Map<String, dynamic>> recovery = [];
  bool needsRecovery = false;
  int completed = 0, total = 0;
  StreamSubscription<Map<String, dynamic>>? _progress;
  Future<void> _writes = Future.value();
  ThemeMode get theme =>
      ThemeMode.values[(prefs.getInt('theme') ?? 0).clamp(
        0,
        ThemeMode.values.length - 1,
      )];
  bool get saveImages => prefs.getBool('images') ?? true;
  bool get keepOriginals => prefs.getBool('originals') ?? false;
  bool get diagnostics => prefs.getBool('diagnostics') ?? false;
  bool get analytics => prefs.getBool('analytics') ?? false;
  bool get onboarded => prefs.getBool('onboarded') ?? false;
  int get quality =>
      (prefs.getInt('quality') ?? 1).clamp(0, qualityLabels.length - 1);
  String get format =>
      const ['a4', 'letter', 'fit'].contains(prefs.getString('format'))
      ? prefs.getString('format')!
      : 'a4';
  String get defaultFilter => filters.contains(prefs.getString('filter'))
      ? prefs.getString('filter')!
      : 'original';
  Future<void> initialise() async {
    final state = Map<String, dynamic>.from(
      (await platform.call<Map>('initialise'))!,
    );
    await _applyRecovery(state);
    documents = await store.documents();
    draft = await store.draft();
    // Android may recreate the process while the system camera is open.
    final lost = Platform.isAndroid
        ? await ImagePicker().retrieveLostData()
        : null;
    if (lost?.files?.isNotEmpty ?? false) {
      final current = draft ?? Draft(const Uuid().v4(), [], DateTime.now());
      final staged = await platform.stage(
        current.id,
        lost!.files!
            .take(maxPages - current.pages.length)
            .map((f) => f.path)
            .toList(),
      );
      draft = current.withPages([...current.pages, ...staged]);
      await store.saveDraft(draft!);
    }
    await maintainCache();
    _progress = platform.progress.listen((e) {
      if (e['captureReady'] == true && !busy && !exporting) {
        unawaited(retryRecovery().catchError((Object _) {}));
      }
      phase = e['phase'] as String? ?? 'Processing…';
      completed = (e['completed'] as num?)?.toInt() ?? 0;
      total = (e['total'] as num?)?.toInt() ?? 0;
      notifyListeners();
    }, onError: (Object _) {});
    notifyListeners();
  }

  Future<void> preference(String key, Object value) async {
    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is String) await prefs.setString(key, value);
    if (key == 'diagnostics' || key == 'analytics') {
      await monitoring.consent(diagnostics, analytics);
    }
    notifyListeners();
  }

  Future<void> capture({bool manual = false, bool gallery = false}) async {
    if (busy || exporting) throw ScanFailure('busy');
    if (pendingCommit != null) throw ScanFailure('index');
    final current = draft ?? Draft(const Uuid().v4(), [], DateTime.now());
    final remaining = maxPages - current.pages.length;
    if (remaining <= 0) throw ScanFailure('limit');
    draft = current;
    busy = true;
    notifyListeners();
    try {
      await _writes;
      await store.saveDraft(current);
      List<PageAsset> pages;
      if (gallery) {
        final selected = await ImagePicker().pickMultiImage(
          limit: remaining > 1 ? remaining : null,
        );
        pages = await platform.stage(
          current.id,
          selected.take(remaining).map((e) => e.path).toList(),
        );
      } else if (manual) {
        final selected = await ImagePicker().pickImage(
          source: ImageSource.camera,
        );
        pages = selected == null
            ? []
            : await platform.stage(current.id, [selected.path]);
      } else {
        await monitoring.event('scan_started');
        pages = await platform.scan(current.id, remaining);
        await monitoring.event('scan_completed');
      }
      final prepared = <PageAsset>[];
      for (final page in pages) {
        final edited = page.copyWith(filter: defaultFilter);
        if (defaultFilter == 'original') {
          prepared.add(edited);
        } else {
          prepared.add(edited.copyWith(thumb: await platform.preview(edited)));
        }
      }
      draft = current.withPages([...current.pages, ...prepared]);
      await store.saveDraft(draft!);
      if (!gallery && !manual)
        await platform.call<void>('acknowledgeCapture', {
          'session': current.id,
        });
    } catch (e, stack) {
      monitoring.failure('capture', stack);
      if (e is ScanFailure) rethrow;
      throw ScanFailure('permission');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> updatePages(List<PageAsset> pages) async {
    if (draft == null) return;
    if (busy || exporting) throw ScanFailure('busy');
    if (pendingCommit != null) throw ScanFailure('index');
    draft = draft!.withPages(pages);
    notifyListeners();
    final snapshot = draft!;
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => store.saveDraft(snapshot));
    await _writes;
  }

  Future<void> discard() async {
    if (draft == null || busy || exporting) return;
    if (pendingCommit != null) throw ScanFailure('index');
    await _writes;
    await store.clearDraft(draft!.id);
    await platform.call<void>('discard', {'session': draft!.id});
    draft = null;
    notifyListeners();
  }

  Future<SavedDocument> export({
    required String title,
    required String format,
    required int quality,
    required int margin,
    required bool landscape,
  }) async {
    if (draft == null || draft!.pages.isEmpty || busy || exporting) {
      throw ScanFailure('busy');
    }
    if (quality < 0 ||
        quality >= qualityDpi.length ||
        !const ['a4', 'letter', 'fit'].contains(format) ||
        !const [0, 5, 10].contains(margin)) {
      throw ScanFailure('invalid');
    }
    exporting = true;
    phase = 'Preparing…';
    completed = 0;
    total = draft!.pages.length;
    notifyListeners();
    final id = draft!.id;
    try {
      await _writes;
      final receipt =
          pendingCommit?.data ??
          await platform.call<Map>('export', {
            'id': id,
            'session': draft!.id,
            'title': safeStem(title),
            'format': format,
            'dpi': qualityDpi[quality],
            'quality': qualityJpeg[quality],
            'margin': margin,
            'landscape': landscape,
            'saveImages': saveImages,
            'keepOriginals': keepOriginals,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'pages': draft!.pages.map((p) => p.toJson()).toList(),
          });
      final doc = SavedDocument(Map<String, dynamic>.from(receipt!));
      pendingCommit = doc;
      await store.commitExport(doc, draft!.id);
      await platform.call<void>('acknowledge', {'session': draft!.id});
      pendingCommit = null;
      draft = null;
      documents = await store.documents();
      await monitoring.event('pdf_export_succeeded');
      return doc;
    } catch (e, stack) {
      monitoring.failure('export', stack);
      await monitoring.event('pdf_export_failed');
      if (pendingCommit != null) throw ScanFailure('index');
      if (e is ScanFailure) rethrow;
      throw ScanFailure('export');
    } finally {
      exporting = false;
      notifyListeners();
    }
  }

  Future<void> cancel() => platform.call<void>('cancel');
  Future<void> chooseFolder({bool private = false}) async {
    if (exporting || busy) throw ScanFailure('busy');
    location =
        (await platform.call<String>(
          private ? 'privateFolder' : 'chooseFolder',
        )) ??
        location;
    notifyListeners();
  }

  Future<void> open(SavedDocument doc, {bool share = false}) async {
    await platform.call<void>(share ? 'share' : 'open', doc.data);
    if (share) await monitoring.event('share_opened');
  }

  Future<void> _applyRecovery(Map<String, dynamic> state) async {
    location = state['location'] as String? ?? location;
    recovery = (state['recovery'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (final receipt in state['receipts'] as List? ?? []) {
      final data = Map<String, dynamic>.from(receipt as Map);
      if (data['deleted'] == true) {
        await store.removeDocument(data['id'] as String);
        await platform.call<void>('acknowledgeDeletion', {'id': data['id']});
      } else {
        final doc = SavedDocument(data);
        final session = data['session'] as String?;
        if (session != null) {
          await store.commitExport(doc, session);
          await platform.call<void>('acknowledge', {'session': session});
          if (draft?.id == session) draft = null;
          if (pendingCommit?.id == doc.id) pendingCommit = null;
        } else {
          await store.saveDocument(doc);
        }
      }
    }
    for (final raw in state['captures'] as List? ?? []) {
      final capture = Map<String, dynamic>.from(raw as Map);
      final session = capture['session'] as String;
      final saved = await store.drafts();
      final existing = saved.where((item) => item.id == session).firstOrNull;
      final current = existing ?? Draft(session, [], DateTime.now());
      final known = current.pages.map((page) => page.id).toSet();
      final pages = (capture['pages'] as List)
          .map((e) => PageAsset.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((page) => !known.contains(page.id))
          .toList();
      if (current.pages.length + pages.length > maxPages) {
        recovery.add({'id': session, 'kind': 'captureLimit'});
        continue;
      }
      final restored = current.withPages([...current.pages, ...pages]);
      await store.saveDraft(restored);
      await platform.call<void>('acknowledgeCapture', {'session': session});
      if (draft == null || draft?.id == session) draft = restored;
    }
    needsRecovery = recovery.isNotEmpty;
  }

  Future<void> resumeDraft(String id) async {
    if (busy || exporting || pendingCommit != null) throw ScanFailure('busy');
    await _writes;
    final selected = (await store.drafts())
        .where((item) => item.id == id)
        .firstOrNull;
    if (selected == null) throw ScanFailure('missing');
    await store.saveDraft(
      selected,
    ); // Move the explicitly selected draft to most recent.
    draft = selected;
    notifyListeners();
  }

  Future<void> retryRecovery() async {
    if (busy || exporting) throw ScanFailure('busy');
    busy = true;
    notifyListeners();
    try {
      final state = await platform.call<Map>('retryRecovery');
      await _applyRecovery(Map<String, dynamic>.from(state!));
      documents = await store.documents();
    } catch (_) {
      needsRecovery = true;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> rename(SavedDocument doc, String title) async {
    if (busy || exporting) throw ScanFailure('busy');
    if (needsRecovery) throw ScanFailure('recovery');
    busy = true;
    notifyListeners();
    try {
      final result = await platform.call<Map>('rename', {
        ...doc.data,
        'newTitle': safeStem(title),
      });
      await store.saveDocument(
        SavedDocument(Map<String, dynamic>.from(result!)),
      );
      documents = await store.documents();
    } catch (_) {
      needsRecovery = true;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> delete(SavedDocument doc, {required bool images}) async {
    if (busy || exporting) throw ScanFailure('busy');
    if (needsRecovery) throw ScanFailure('recovery');
    busy = true;
    notifyListeners();
    try {
      await platform.call<void>('delete', {
        ...doc.data,
        'deleteImages': images,
      });
      await store.removeDocument(doc.id);
      await platform.call<void>('acknowledgeDeletion', {'id': doc.id});
      documents = await store.documents();
    } catch (_) {
      needsRecovery = true;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> maintainCache() async {
    if (busy || exporting) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (prefs.getInt('lastMaintenance') ?? 0) <
        const Duration(days: 1).inMilliseconds) {
      return;
    }
    try {
      await _writes;
      await platform.call<void>('maintenance', {
        'protectedPaths': await store.protectedPreviewPaths(),
      });
      await prefs.setInt('lastMaintenance', now);
    } catch (_) {
      /* Cleanup must never prevent opening the library. */
    }
  }

  Future<void> refresh() async {
    await maintainCache();
    documents = await store.documents();
    notifyListeners();
  }

  @override
  void dispose() {
    _progress?.cancel();
    super.dispose();
  }
}
