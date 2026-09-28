import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/src/actions/beak_action.dart';
import 'package:beak_frontend/src/actions/beak_action_button.dart';
import 'package:beak_frontend/src/localization/beak_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  final record = BeakRecord.fromRow(const {'id': 'n1', 'title': 'One'});
  late _DeferredDeleteSource source;
  late List<BeakException> failures;
  late int refreshes;

  setUp(() {
    source = _DeferredDeleteSource(record);
    failures = [];
    refreshes = 0;
  });

  Future<GoRouter> pumpAction(
    WidgetTester tester,
    BeakRecordAction action, {
    Locale locale = const Locale('en'),
  }) async {
    source.completion = Completer<void>();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => BeakActionButton(
            action: action,
            record: record,
            actionContext: BeakActionContext(
              buildContext: context,
              model: const NoteModel(),
              dataSource: source,
              router: GoRouter.of(context),
              refresh: () async => refreshes++,
              onError: failures.add,
            ),
          ),
        ),
        GoRoute(
          path: '/elsewhere',
          builder: (_, _) => const OiLabel.body('Another page'),
        ),
        GoRoute(
          path: '/notes',
          builder: (_, _) => const OiLabel.body('List page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      OiApp.router(
        locale: locale,
        supportedLocales: BeakLocalizations.supportedLocales,
        localizationsDelegates: const [BeakLocalizations.delegate],
        theme: OiThemeData.light(),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('cancelling archive leaves the record unchanged', (tester) async {
    await pumpAction(tester, const BeakArchiveAction());
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Archive?'), findsOneWidget);
    expect(source.started, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(source.started, 0);
    expect(refreshes, 0);
    expect(find.text('List page'), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });

  for (final (action, label) in const [
    (BeakArchiveAction(), 'Archive'),
    (BeakDeleteAction.confirmed(), 'Delete'),
  ]) {
    testWidgets('$label waits for success before refresh and navigation', (
      tester,
    ) async {
      await pumpAction(tester, action);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();

      expect(source.started, 1);
      expect(source.deleteCalls, isEmpty);
      expect(source.restoreCalls, isEmpty);
      expect(refreshes, 0);
      expect(find.text('List page'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(source.started, 1);

      source.completion.complete();
      await tester.pumpAndSettle();

      expect(source.deleteCalls, [('notes', 'n1', false)]);
      expect(source.restoreCalls, isEmpty);
      expect(refreshes, 1);
      expect(find.text('List page'), findsOneWidget);
      expect(failures, isEmpty);
    });
  }

  testWidgets('archive failure stays on the record and can be retried', (
    tester,
  ) async {
    await pumpAction(tester, const BeakArchiveAction());
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    source.completion.completeError(
      const BeakValidationException('The cutoff has passed.'),
    );
    await tester.pumpAndSettle();

    expect(failures.single, isA<BeakValidationException>());
    expect(source.deleteCalls, isEmpty);
    expect(refreshes, 0);
    expect(find.text('List page'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(tester.takeException(), isNull);

    source.completion = Completer<void>();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    expect(source.started, 2);
    source.completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('List page'), findsOneWidget);
  });

  testWidgets('completion preserves navigation after the action is unmounted', (
    tester,
  ) async {
    final router = await pumpAction(tester, const BeakArchiveAction());
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    expect(source.started, 1);

    router.go('/elsewhere');
    await tester.pumpAndSettle();
    source.completion.complete();
    await tester.pumpAndSettle();

    expect(source.deleteCalls, [('notes', 'n1', false)]);
    expect(refreshes, 0);
    expect(find.text('Another page'), findsOneWidget);
    expect(find.text('List page'), findsNothing);
  });

  testWidgets('archive label and confirmation follow the host locale', (
    tester,
  ) async {
    await pumpAction(
      tester,
      const BeakArchiveAction(),
      locale: const Locale('de'),
    );
    await tester.tap(find.text('Archivieren'));
    await tester.pumpAndSettle();
    expect(find.text('Archivieren?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(source.started, 0);
  });
}

final class _DeferredDeleteSource extends FakeDataSource {
  _DeferredDeleteSource(BeakRecord record)
    : super(
        records: {
          'notes': {'n1': record},
        },
      );

  int started = 0;
  late Completer<void> completion;

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async {
    started++;
    await completion.future;
    await super.delete(table, id, force: force);
  }
}
