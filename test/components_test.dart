import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/ui/theme.dart';

void main() {
  testWidgets('empty state remains readable with large text and dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Lumen.theme(Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: EmptyPanel(
                icon: Icons.folder_outlined,
                title: 'No PDFs yet',
                body: 'Scan your first document to build your local library.',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('No PDFs yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
