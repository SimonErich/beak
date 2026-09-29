import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/services.dart';
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

  group('ask', () {
    Future<void> openAsk(
      WidgetTester tester,
      void Function(BeakConfirmResult result) onResult,
    ) async {
      await pumpHost(
        tester,
        (overlays) async =>
            onResult(await overlays.ask(title: 'Archive this order?')),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('reports a confirmation', (tester) async {
      BeakConfirmResult? result;
      await openAsk(tester, (value) => result = value);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, BeakConfirmResult.confirmed);
    });

    testWidgets('reports the Cancel button as a refusal', (tester) async {
      BeakConfirmResult? result;
      await openAsk(tester, (value) => result = value);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, BeakConfirmResult.cancelled);
    });

    testWidgets('reports leaving the dialog as a dismissal', (tester) async {
      BeakConfirmResult? result;
      await openAsk(tester, (value) => result = value);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(result, BeakConfirmResult.dismissed);
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
        (overlays) => overlays.sheet(
          title: 'Filters',
          body: const BeakTextBlock('sheet body text'),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('sheet body text'), findsOneWidget);
    });

    testWidgets('a builder sheet returns the value its content closes with', (
      tester,
    ) async {
      String? picked;
      await pumpHost(tester, (overlays) async {
        picked = await overlays.sheetWithResult<String>(
          title: 'Pick one',
          builder: (close) =>
              OiButton.primary(label: 'choose', onTap: () => close('blue')),
        );
      });

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('choose'));
      await tester.pumpAndSettle();

      expect(picked, 'blue');
      expect(find.text('choose'), findsNothing);
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
      await _letToastsExpire(tester);
    });

    testWidgets('stays for the requested duration', (tester) async {
      await pumpHost(
        tester,
        (overlays) =>
            overlays.toast('Long one', duration: const Duration(seconds: 30)),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Long one'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Long one'), findsNothing);
    });

    testWidgets('offers an action that runs once', (tester) async {
      var undone = 0;
      await pumpHost(
        tester,
        (overlays) => overlays.toast(
          'Order archived',
          actionLabel: 'Undo',
          onAction: () => undone++,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(undone, 1);
      await _letToastsExpire(tester);
    });
  });
}

/// The toast queue is shared by the whole test isolate: let a shown toast run
/// out so the next test starts on an empty one.
Future<void> _letToastsExpire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 40));
  await tester.pumpAndSettle();
}
