import 'package:flutter/services.dart';
import 'models.dart';

/// File descriptors/opaque URIs cross the boundary; never full-page batches.
class ScannerPlatform {
  static const channel = MethodChannel('com.lumen.pdfscanner/engine');
  static const events = EventChannel('com.lumen.pdfscanner/progress');
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw ScanFailure(e.code);
    }
  }

  Future<List<PageAsset>> stage(String session, List<String> paths) async {
    final result = await call<List<dynamic>>('stage', {
      'session': session,
      'paths': paths,
    });
    return (result ?? [])
        .map((e) => PageAsset.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PageAsset>> scan(String session, int remaining) async {
    final paths = await call<List<dynamic>>('scan', {'limit': remaining});
    final selected = List<String>.from(paths ?? []);
    if (selected.length > remaining) throw ScanFailure('limit');
    return stage(session, selected);
  }

  Future<String> preview(PageAsset page) async =>
      (await call<String>('preview', page.toJson()))!;
  Stream<Map<String, dynamic>> get progress => events
      .receiveBroadcastStream()
      .map((e) => Map<String, dynamic>.from(e as Map));
}
