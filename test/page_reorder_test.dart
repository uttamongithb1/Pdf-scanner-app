import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/ui/page_reorder.dart';

void main() {
  testWidgets('long press drag reorders without removing accessible content', (
    tester,
  ) async {
    String? moved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: PageReorderTile(
                  key: const ValueKey('first'),
                  id: 'a',
                  label: 'Page 1',
                  enabled: true,
                  onMove: (_) {},
                  child: const Text('First page'),
                ),
              ),
              SizedBox(
                width: 160,
                height: 160,
                child: PageReorderTile(
                  key: const ValueKey('second'),
                  id: 'b',
                  label: 'Page 2',
                  enabled: true,
                  onMove: (id) => moved = id,
                  child: const Text('Second page'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('first'))),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('second'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moved, 'a');
    expect(find.text('First page'), findsOneWidget);
    expect(find.text('Second page'), findsOneWidget);
  });

  testWidgets('large text and RTL fixture do not require dragging', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 250,
                  height: 200,
                  child: PageReorderTile(
                    id: 'a',
                    label: 'Page 1',
                    enabled: false,
                    onMove: (_) {},
                    child: const Text(
                      'Move earlier or later with the page menu',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('page menu'), findsOneWidget);
  });
}
