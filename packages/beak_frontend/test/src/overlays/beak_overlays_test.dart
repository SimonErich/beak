import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  /// Pumps a single button that opens an overlay from its own context, so
  /// the overlay mounts through a real obers overlay host.
  Future<BeakOverlays> pumpHost(
    WidgetTester tester,
    void Function(BeakOverlays overlays) onTap,
  ) async {
    late BeakOverlays overlays;
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: Builder(
          builder: (context) {
            overlays = BeakOverlays(context);
            return OiButton.primary(
              label: 'open',
              onTap: () => onTap(overlays),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return overlays;
  }

  group('confirm', () {
    testWidgets('resolves true when confirmed', (tester) async {
      var result = false;
      await pumpHost(
        tester,
        (overlays) async =>
            result = await overlays.confirm(title: 'Delete this?'),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this?'), findsWidgets);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('resolves false when cancelled', (tester) async {
      var result = true;
      await pumpHost(
        tester,
        (overlays) async =>
            result = await overlays.confirm(title: 'Delete this?'),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('modal', () {
    testWidgets('renders a block body and dismisses', (tester) async {
      await pumpHost(
        tester,
        (overlays) => overlays.modal(
          title: 'Details',
          body: const BeakTextBlock('modal body text'),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('modal body text'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('modal body text'), findsNothing);
    });
  });

  group('dialog', () {
    testWidgets('returns the value the content closes with', (tester) async {
      String? saved;
      await pumpHost(tester, (overlays) async {
        saved = await overlays.dialog<String>(
          title: 'Compose',
          builder: (close) =>
              OiButton.primary(label: 'send', onTap: () => close('sent!')),
        );
      });

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('send'));
      await tester.pumpAndSettle();

      expect(saved, 'sent!');
    });
  });

  group('sheet', () {
    testWidgets('slides a block body in from the edge', (tester) async {
      await pumpHost(
        tester,
        (overlays) => overlays.sheet<void>(
          title: 'Filters',
          body: const BeakTextBlock('sheet body text'),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('sheet body text'), findsOneWidget);
    });
  });

  group('toast', () {
    testWidgets('shows a transient message', (tester) async {
      await pumpHost(
        tester,
        (overlays) => overlays.toast('Saved successfully'),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Saved successfully'), findsOneWidget);
    });
  });
}
