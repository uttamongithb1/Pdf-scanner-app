import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/core/models.dart';
import 'package:pdf_scanner/core/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = ScannerPlatform.channel;
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('stage sends paths, not full-resolution bytes', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'stage');
          expect(call.arguments, {
            'session': 's',
            'paths': ['/picked.jpg'],
          });
          return [
            {
              'id': 'p',
              'path': '/source.jpg',
              'thumb': '/thumb.jpg',
              'width': 200,
              'height': 300,
            },
          ];
        });
    final pages = await ScannerPlatform().stage('s', ['/picked.jpg']);
    expect(pages.single.height, 300);
  });
  test('native failure maps to a stable, non-sensitive error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'folder',
            message: '/sensitive/document-name',
          );
        });
    await expectLater(
      ScannerPlatform().call<void>('export'),
      throwsA(
        isA<ScanFailure>().having(
          (e) => e.message,
          'sanitised',
          (isNot(contains('sensitive'))),
        ),
      ),
    );
  });
}
