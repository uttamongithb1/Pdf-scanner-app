import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/controller.dart';
import 'core/monitoring.dart';
import 'core/platform.dart';
import 'core/store.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  ScannerController? controller;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    setState(() => failed = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = await LocalStore.open();
      final monitoring = Monitoring();
      await monitoring.initialise(
        prefs.getBool('diagnostics') ?? false,
        prefs.getBool('analytics') ?? false,
      );
      final c = ScannerController(store, prefs, ScannerPlatform(), monitoring);
      await c.initialise();
      if (mounted) setState(() => controller = c);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => controller == null
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: Lumen.theme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.document_scanner_outlined,
                      size: 48,
                      color: Lumen.indigo,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      failed
                          ? 'Could not open your library'
                          : 'Getting your library ready',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (failed) ...[
                      const Text(
                        'Your files have not been deleted. Try opening the app again.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: start,
                        child: const Text('Try again'),
                      ),
                    ] else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        )
      : ProviderScope(
          overrides: [scannerProvider.overrideWith((ref) => controller!)],
          child: const ScannerApp(),
        );
}
