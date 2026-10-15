import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase is opt-in at build-time AND at user level. Native collection is
/// disabled in platform configuration before Firebase can auto-initialise.
class Monitoring {
  bool ready = false;
  bool _diagnostics = false, _analytics = false;
  Future<void> initialise(bool diagnostics, bool analytics) async {
    if (!const bool.fromEnvironment('FIREBASE_ENABLED')) return;
    try {
      await Firebase.initializeApp();
      ready = true;
      await consent(diagnostics, analytics);
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        failure('framework', details.stack, fatal: true);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        failure('uncaught', stack, fatal: true);
        return false;
      };
    } catch (_) {
      ready = false;
    } // App must work without remote configuration.
  }

  Future<void> consent(bool diagnostics, bool analytics) async {
    if (!ready) return;
    _diagnostics = diagnostics;
    _analytics = analytics;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      diagnostics,
    );
    if (!diagnostics) await FirebaseCrashlytics.instance.deleteUnsentReports();
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(analytics);
  }

  void failure(String code, StackTrace? stack, {bool fatal = false}) {
    if (!ready || !_diagnostics) return;
    // Never pass raw platform error messages, document names, URIs or content.
    FirebaseCrashlytics.instance
        .recordError(
          StateError('scanner_${code.replaceAll(RegExp('[^a-z_]'), '')}'),
          stack,
          fatal: fatal,
        )
        .catchError((Object _) {});
  }

  Future<void> event(String name) async {
    if (!ready ||
        !_analytics ||
        !const {
          'scan_started',
          'scan_completed',
          'pdf_export_succeeded',
          'pdf_export_failed',
          'share_opened',
        }.contains(name)) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(name: name);
    } catch (_) {
      /* Diagnostics must never break document work. */
    }
  }
}
