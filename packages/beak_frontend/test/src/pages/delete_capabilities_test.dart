import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

/// A server that answers what the current account may do, and refuses deletes
/// the way a policy does: with an unapplied receipt.
final class _Server extends FakeDataSource
    implements BeakCapabilityDataSource, BeakCommitDataSource {
  _Server({this.access = const BeakAccessCapabilities()})
    : super(
        records: {
          'notes': {
            'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'One note'}),
          },
        },
      );

  final BeakAccessCapabilities access;
  final List<(String, Object?)> capabilityCalls = [];
  int commits = 0;

  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async {
    capabilityCalls.add((table, id));
    return access;
  }

  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(atomicGraph: true);

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    commits++;
    return BeakSaveResult(
      saveId: plan.saveId,
      mode: BeakSaveMode.atomic,
      outcomes: [
        for (final operation in plan.operations)
          BeakOperationResult(
            id: operation.id,
            status: BeakWriteOutcome.unapplied,
            error: BeakSaveError(
              code: 'authorization',
              message: 'Ask an administrator to delete this note.',
            ),
          ),
      ],
    );
  }

  @override
  Future<BeakSaveResult> recover(String saveId) =>
      throw StateError('Nothing was lost, so nothing is recovered.');
}

void main() {
  tearDown(beakLocator.reset);

  Finder actionButton(String label) => find.byWidgetPredicate(
    (widget) => widget is OiButton && widget.semanticLabel == label,
  );

  Future<void> open(
    WidgetTester tester,
    _Server server, {
    String path = '/notes',
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        resources: const [BeakResource(model: NoteModel())],
        dataSource: server,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OiAppShell))).go(path);
    await tester.pumpAndSettle();
  }

  group('the list follows what the server says this account may do', () {
    testWidgets('an account that may do everything sees both controls', (
      tester,
    ) async {
      final server = _Server();
      await open(tester, server);

      expect(find.text('One note'), findsOneWidget);
      expect(actionButton('Delete'), findsOneWidget);
      expect(find.text('Create'), findsWidgets);
      expect(server.capabilityCalls, contains(('notes', null)));
    });

    testWidgets('an account that may not delete gets no trash icon', (
      tester,
    ) async {
      await open(
        tester,
        _Server(access: const BeakAccessCapabilities(canDelete: false)),
      );

      expect(find.text('One note'), findsOneWidget);
      expect(actionButton('Delete'), findsNothing);
      expect(find.text('Create'), findsWidgets);
    });

    testWidgets('an account that may not create gets no create action', (
      tester,
    ) async {
      await open(
        tester,
        _Server(access: const BeakAccessCapabilities(canCreate: false)),
      );

      expect(find.text('One note'), findsOneWidget);
      expect(actionButton('Delete'), findsOneWidget);
      expect(find.widgetWithText(OiButton, 'Create'), findsNothing);
    });
  });

  testWidgets('a record the account may not delete has no delete button', (
    tester,
  ) async {
    final server = _Server(
      access: const BeakAccessCapabilities(canDelete: false),
    );
    await open(tester, server, path: '/notes/n1');

    expect(find.text('One note'), findsWidgets);
    expect(find.widgetWithText(OiButton, 'Delete'), findsNothing);
    expect(server.capabilityCalls, contains(('notes', 'n1')));
  });

  testWidgets('a refused delete says why and keeps the row', (tester) async {
    final server = _Server();
    await open(tester, server);

    await tester.tap(actionButton('Delete'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('One note'), findsNothing);
    expect(find.text('Record deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(server.commits, 1);
    expect(find.text('One note'), findsOneWidget);
    expect(
      find.text('Ask an administrator to delete this note.'),
      findsOneWidget,
    );
    expect(find.text('Action failed'), findsNothing);
    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();
  });
}
