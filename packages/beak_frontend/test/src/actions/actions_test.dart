import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  final note = BeakRecord.fromRow(const {'id': 'n1', 'title': 'One'});

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {'n1': note},
      },
    );
  });

  Future<GoRouter> pumpHost(
    WidgetTester tester,
    List<BeakAction> actions, {
    BeakRecord? record,
    List<BeakRecord> records = const [],
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => OiColumn(
            breakpoint: context.breakpoint,
            children: [
              for (final action in actions)
                Builder(
                  builder: (buttonContext) => BeakActionButton(
                    action: action,
                    actionContext: BeakActionContext(
                      buildContext: buttonContext,
                      model: const NoteModel(),
                      dataSource: dataSource,
                      router: GoRouter.of(buttonContext),
                    ),
                    record: record,
                    records: records,
                  ),
                ),
            ],
          ),
        ),
        GoRoute(
          path: '/notes',
          builder: (context, state) => const OiLabel.body('list page'),
        ),
        GoRoute(
          path: '/notes/create',
          builder: (context, state) => const OiLabel.body('create page'),
        ),
        GoRoute(
          path: '/notes/:id',
          builder: (context, state) => const OiLabel.body('show page'),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => const OiLabel.body('edit page'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      OiApp.router(routerConfig: router, theme: OiThemeData.light()),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// Lets the optimistic undo window elapse so no pending action leaks
  /// into the next test.
  Future<void> drainPending(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  group('execution', () {
    testWidgets(
      'failed custom actions report a safe error and can be retried',
      (tester) async {
        var calls = 0;
        await pumpHost(tester, [
          BeakRecordAction(
            key: 'fail',
            label: 'Try operation',
            onExecute: (_, _) async {
              calls++;
              throw const BeakValidationException('Cannot change this record.');
            },
          ),
        ], record: note);
        await tester.tap(find.text('Try operation'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Cannot change this record.'), findsOneWidget);
        await tester.tap(find.text('Try operation'));
        await tester.pumpAndSettle();
        expect(calls, 2);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
      },
    );
    testWidgets('a record action receives its record', (tester) async {
      BeakRecord? executed;
      await pumpHost(tester, [
        BeakRecordAction(
          key: 'ping',
          label: 'Ping',
          onExecute: (record, context) async => executed = record,
        ),
      ], record: note);

      await tester.tap(find.text('Ping'));
      await tester.pumpAndSettle();

      expect(executed, note);
    });

    testWidgets('a bulk action receives the selection', (tester) async {
      List<BeakRecord>? executed;
      await pumpHost(
        tester,
        [
          BeakBulkAction(
            key: 'export',
            label: 'Export',
            onExecute: (records, context) async => executed = records,
          ),
        ],
        records: [note],
      );

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(executed, [note]);
    });

    testWidgets('a global action navigates through the router', (tester) async {
      await pumpHost(tester, const [BeakCreateAction()]);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('create page'), findsOneWidget);
    });

    testWidgets('view and edit navigate to the record pages', (tester) async {
      await pumpHost(tester, const [BeakViewAction()], record: note);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('show page'), findsOneWidget);

      await pumpHost(tester, const [BeakEditAction()], record: note);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('edit page'), findsOneWidget);
    });
  });

  group('confirmation', () {
    testWidgets('cancelling the dialog aborts execution', (tester) async {
      var executed = false;
      await pumpHost(tester, [
        BeakRecordAction(
          key: 'archive',
          label: 'Archive',
          requiresConfirmation: true,
          onExecute: (record, context) async => executed = true,
        ),
      ], record: note);

      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archive?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(executed, isFalse);
      expect(find.text('Archive?'), findsNothing);
    });

    testWidgets('confirming runs the action', (tester) async {
      var executed = false;
      await pumpHost(tester, [
        BeakRecordAction(
          key: 'archive',
          label: 'Archive',
          requiresConfirmation: true,
          onExecute: (record, context) async => executed = true,
        ),
      ], record: note);

      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive').last);
      await tester.pumpAndSettle();

      expect(executed, isTrue);
    });
  });

  group('built-in delete', () {
    testWidgets('commits after the undo window and returns to the list', (
      tester,
    ) async {
      await pumpHost(tester, const [BeakDeleteAction()], record: note);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsOneWidget);
      expect(dataSource.deleteCalls, isEmpty);

      await drainPending(tester);

      expect(dataSource.deleteCalls, [('notes', 'n1', false)]);
      expect(find.text('list page'), findsOneWidget);
    });

    testWidgets('undo prevents the delete entirely', (tester) async {
      await pumpHost(tester, const [BeakDeleteAction()], record: note);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      await drainPending(tester);

      expect(dataSource.deleteCalls, isEmpty);
      expect(find.text('list page'), findsNothing);
    });
  });

  group('rendering', () {
    testWidgets('compact mode renders icon buttons by semantic label', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Builder(
              builder: (buttonContext) => BeakActionButton(
                action: const BeakViewAction(),
                actionContext: BeakActionContext(
                  buildContext: buttonContext,
                  model: const NoteModel(),
                  dataSource: dataSource,
                  router: GoRouter.of(buttonContext),
                ),
                record: note,
                compact: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        OiApp.router(routerConfig: router, theme: OiThemeData.light()),
      );
      await tester.pumpAndSettle();

      final OiButton button = tester.widget(find.byType(OiButton));
      expect(button.semanticLabel, 'View');
    });
  });
}
