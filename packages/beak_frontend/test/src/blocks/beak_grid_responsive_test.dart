import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  for (final viewportWidth in [320.0, 1400.0]) {
    testWidgets(
      'fixed overview spans stack within a narrow container (viewport $viewportWidth)',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(viewportWidth, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          OiApp(
            theme: OiThemeData.light(),
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 288,
                child: BeakBlockHost(block: _overview()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cards = find.byType(OiCard);
        final first = tester.getRect(cards.at(0));
        final second = tester.getRect(cards.at(1));
        final third = tester.getRect(cards.at(2));
        expect(first.width, 288);
        expect(second.width, 288);
        expect(third.width, 288);
        expect(second.top - first.bottom, 24);
        expect(third.top - second.bottom, 24);
        expect(second.height, greaterThan(first.height));
        expect(third.height, greaterThan(second.height));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('fixed overview retains asymmetric desktop spans', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1200,
            child: BeakBlockHost(block: _overview()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cards = find.byType(OiCard);
    final first = tester.getRect(cards.at(0));
    final second = tester.getRect(cards.at(1));
    final third = tester.getRect(cards.at(2));
    expect(first.width, 486);
    expect(second.width, 282);
    expect(third.width, 384);
    expect(second.top, first.top);
    expect(third.top, first.top);
    expect(tester.takeException(), isNull);
  });

  for (final (minimum, width, columns) in [
    (100.0, 600.0, 12),
    (0.0, 288.0, 12),
  ]) {
    testWidgets('fixed grid supports minimum child width $minimum', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: BeakBlockHost(
                block: BeakGridBlock(
                  columns: columns,
                  minChildWidthInPixels: minimum,
                  gapInPixels: 24,
                  children: [
                    for (final span in [5, 3, 4])
                      BeakWidgetBlock(
                        (_) => SizedBox(key: ValueKey(span), height: 40),
                        span: BeakSpan(columns: span),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byKey(const ValueKey(5)));
      final second = tester.getRect(find.byKey(const ValueKey(3)));
      final third = tester.getRect(find.byKey(const ValueKey(4)));
      expect(second.top, first.top);
      expect(third.top, first.top);
      expect(third.right, width);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('auto-fitting grids keep their explicit track minimum', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakBlockHost(
          block: BeakGridBlock(
            minColumnWidthInPixels: 200,
            children: [
              for (var index = 0; index < 3; index++)
                BeakWidgetBlock(
                  (_) => SizedBox(key: ValueKey(index), height: 40),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byKey(const ValueKey(0)));
    final third = tester.getRect(find.byKey(const ValueKey(2)));
    expect(first.width, closeTo((640 - 32) / 3, 0.001));
    expect(third.top, first.top);
    expect(third.right, closeTo(640, 0.001));
    expect(tester.takeException(), isNull);
  });
}

BeakGridBlock _overview() => BeakGridBlock(
  columns: 12,
  gapInPixels: 24,
  children: [
    for (final (title, span, height) in [
      ('Orders by delivery day', 5, 48.0),
      ('Status right now', 3, 96.0),
      ('Delivery slots today', 4, 144.0),
    ])
      BeakCardBlock(
        title: title,
        span: BeakSpan(columns: span),
        child: BeakWidgetBlock((_) => SizedBox(height: height)),
      ),
  ],
);
