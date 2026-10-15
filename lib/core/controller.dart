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
  int completed = 0, total = 0;
  StreamSubscription<Map<String, dynamic>>? _progress;
  Future<void> _writes = Future.value();
  ThemeMode get theme => ThemeMode.values[prefs.getInt('theme') ?? 0];
  bool get saveImages => prefs.getBool('images') ?? true;
  bool get keepOriginals => prefs.getBool('originals') ?? false;
  bool get diagnostics => prefs.getBool('diagnostics') ?? false;
  bool get analytics => prefs.getBool('analytics') ?? false;
  bool get onboarded => prefs.getBool('onboarded') ?? false;
  int get quality => prefs.getInt('quality') ?? 1;
  String get format => prefs.getString('format') ?? 'a4';
  String get defaultFilter => prefs.getString('filter') ?? 'original';
  Future<void> initialise() async {
    final state = Map<String, dynamic>.from(
      (await platform.call<Map>('initialise'))!,
    );
    location = state['location'] as String;
    final receipts = (state['receipts'] as List? ?? []);
    for (final receipt in receipts) {
      final doc = SavedDocument(Map<String, dynamic>.from(receipt as Map));
      await store.saveDocument(doc);
      await store.clearDraft(doc.data['session'] as String);
      await platform.call<void>('acknowledge', {
        'session': doc.data['session'],
      });
    }
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
    _progress = platform.progress.listen((e) {
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
    if (key == 'diagnostics' || key == 'analytics')
      await monitoring.consent(diagnostics, analytics);
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
    if (draft == null || draft!.pages.isEmpty || busy || exporting)
      throw ScanFailure('busy');
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
      await store.saveDocument(doc);
      await store.clearDraft(draft!.id);
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
    if (exporting) throw ScanFailure('busy');
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

  Future<void> rename(SavedDocument doc, String title) async {
    final result = await platform.call<Map>('rename', {
      ...doc.data,
      'newTitle': safeStem(title),
    });
    await store.saveDocument(SavedDocument(Map<String, dynamic>.from(result!)));
    documents = await store.documents();
    notifyListeners();
  }

  Future<void> delete(SavedDocument doc, {required bool images}) async {
    await platform.call<void>('delete', {...doc.data, 'deleteImages': images});
    await store.removeDocument(doc.id);
    documents = await store.documents();
    notifyListeners();
  }

  Future<void> refresh() async {
    documents = await store.documents();
    notifyListeners();
  }

  @override
  void dispose() {
    _progress?.cancel();
    super.dispose();
  }
}
