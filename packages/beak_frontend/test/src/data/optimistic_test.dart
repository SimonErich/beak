import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  late List<String> log;

  Widget host({required Future<void> Function() commit}) => OiApp(
    theme: OiThemeData.light(),
    home: Builder(
      builder: (context) => OiButton.primary(
        label: 'Delete note',
        onTap: () {
          BeakOptimistic.mutate(
            context,
            apply: () => log.add('apply'),
            rollback: () => log.add('rollback'),
            commit: () async {
              log.add('commit');
              await commit();
            },
            message: 'Note deleted',
            undoDuration: const Duration(seconds: 2),
          );
        },
      ),
    ),
  );

  setUp(() {
    log = [];
  });

  /// Lets the undo window elapse so no pending action leaks into the next
  /// test (the optimistic runner keeps one global pending slot).
  Future<void> drainPending(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('applies immediately and shows the undo affordance', (
    tester,
  ) async {
    await tester.pumpWidget(host(commit: () async {}));
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();

    expect(log, ['apply']);
    expect(find.text('Note deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await drainPending(tester);
  });

  testWidgets('the undo affordance follows the panel language', (tester) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        locale: const Locale('de'),
        supportedLocales: BeakLocalizations.supportedLocales,
        localizationsDelegates: const [BeakLocalizations.delegate],
        home: Builder(
          builder: (context) => OiButton.primary(
            label: 'Löschen',
            onTap: () => BeakOptimistic.mutate(
              context,
              apply: () {},
              rollback: () {},
              commit: () async {},
              message: 'Notiz gelöscht',
              undoDuration: const Duration(seconds: 2),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Rückgängig'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);

    await drainPending(tester);
  });

  testWidgets('commits after the undo window passes', (tester) async {
    await tester.pumpWidget(host(commit: () async {}));
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();

    await drainPending(tester);

    expect(log, ['apply', 'commit']);
  });

  testWidgets('undo rolls back and never commits', (tester) async {
    await tester.pumpWidget(host(commit: () async {}));
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(log, ['apply', 'rollback']);

    await drainPending(tester);
    expect(log, ['apply', 'rollback'], reason: 'no late commit');
  });

  testWidgets('a failing commit rolls back', (tester) async {
    await tester.pumpWidget(
      host(commit: () async => throw const BeakStorageExceptionLike()),
    );
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();

    await drainPending(tester);

    expect(log, ['apply', 'commit', 'rollback']);
  });
}

/// A stand-in failure so the test stays independent of beak_core.
final class BeakStorageExceptionLike implements Exception {
  const BeakStorageExceptionLike();
}
