import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

final class _Model extends BeakModel {
  const _Model({this.canDelete = _allowed, this.deletableWhen});

  final bool Function() canDelete;
  final bool Function(BeakRecord record)? deletableWhen;

  @override
  BeakModelBehavior get behavior =>
      BeakModelBehavior(deletableWhen: deletableWhen);

  static bool _allowed() => true;

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const NoteModel().columns;

  @override
  BeakPermissions get permissions => BeakPermissions({
    BeakOperation.read: () => true,
    BeakOperation.delete: canDelete,
  });
}

final class _Source extends FakeDataSource {
  _Source()
    : super(
        records: {
          'notes': {
            'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'One note'}),
          },
        },
      );

  final completion = Completer<void>();
  int started = 0;
  int batchAttempts = 0;

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async {
    batchAttempts++;
    throw const BeakConfigurationException('Batch lookup is unsupported.');
  }

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async {
    started++;
    await completion.future;
    await super.delete(table, id, force: force);
  }
}

void main() {
  tearDown(beakLocator.reset);

  Finder actionButton(String label) => find.byWidgetPredicate(
    (widget) => widget is OiButton && widget.semanticLabel == label,
  );

  Future<void> pumpList(
    WidgetTester tester,
    _Source source, {
    bool Function() canDelete = _Model._allowed,
    void Function(BeakException)? onError,
    List<BeakRecordAction> recordActions = const [],
    BeakRecordAction deleteAction = const BeakArchiveAction(),
    bool Function(BeakRecord record)? deletableWhen,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        config: BeakPanelConfig(
          title: 'Admin',
          resources: [
            BeakResource(
              model: _Model(canDelete: canDelete, deletableWhen: deletableWhen),
              icon: const BeakIconToken(OiIcons.notebook),
              deleteAction: deleteAction,
              onActionError: onError,
              recordActions: recordActions,
            ),
          ],
        ),
        dataSource: source,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes').first);
    await tester.pumpAndSettle();
  }

  testWidgets('a record the model says is not deletable offers no archive', (
    tester,
  ) async {
    await pumpList(
      tester,
      _Source(),
      deletableWhen: (record) => record['title']?.raw != 'One note',
    );

    expect(find.text('One note'), findsOneWidget);
    expect(actionButton('Archive'), findsNothing);
  });

  testWidgets(
    'a built-in action listed as a record action follows permissions',
    (tester) async {
      await pumpList(
        tester,
        _Source(),
        canDelete: () => false,
        deleteAction: const BeakArchiveAction(),
        recordActions: const [BeakDeleteAction()],
      );

      expect(find.text('One note'), findsOneWidget);
      expect(actionButton('Delete'), findsNothing);
      expect(actionButton('Archive'), findsNothing);
    },
  );

  testWidgets('a deletable record offers the archive action', (tester) async {
    await pumpList(tester, _Source(), deletableWhen: (_) => true);

    expect(actionButton('Archive'), findsOneWidget);
  });

  testWidgets(
    'resource delete hides immediately, undo restores, and commit stays removed',
    (tester) async {
      final source = _Source();
      await pumpList(tester, source, deleteAction: const BeakDeleteAction());
      tester.widget<OiButton>(actionButton('Delete')).onTap!();
      await tester.pumpAndSettle();
      expect(find.text('One note'), findsNothing);
      expect(source.started, 0);
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('One note'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(source.started, 0);
      tester.widget<OiButton>(actionButton('Delete')).onTap!();
      await tester.pumpAndSettle();
      expect(find.text('One note'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(source.started, 1);
      expect(find.text('One note'), findsNothing);
      source.completion.complete();
      await tester.pumpAndSettle();
      expect(source.deleteCalls, [('notes', 'n1', false)]);
      expect(find.text('One note'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('custom record actions still fetch the complete current record', (
    tester,
  ) async {
    final source = _Source();
    BeakRecord? received;
    await pumpList(
      tester,
      source,
      recordActions: [
        BeakRecordAction(
          key: 'inspect',
          label: 'Inspect',
          onExecute: (record, _) async => received = record,
        ),
      ],
    );
    await source.update(
      'notes',
      'n1',
      BeakRecord.fromRow({'title': 'Changed on server'}),
    );
    source.getOneCalls.clear();
    final OiButton inspect = tester.widget(actionButton('Inspect'));
    inspect.onTap!();
    await tester.pumpAndSettle();
    expect(source.getOneCalls, [('notes', 'n1')]);
    expect(received?['title']?.raw, 'Changed on server');
  });

  testWidgets('read-only resources have no row delete or archive action', (
    tester,
  ) async {
    final source = _Source();
    await pumpList(tester, source, canDelete: () => false);
    expect(find.text('One note'), findsOneWidget);
    expect(actionButton('Delete'), findsNothing);
    expect(actionButton('Archive'), findsNothing);
    expect(source.started, 0);
  });

  testWidgets('stale row action checks permission before confirmation', (
    tester,
  ) async {
    final source = _Source();
    var allowed = true;
    final errors = <BeakException>[];
    await pumpList(
      tester,
      source,
      canDelete: () => allowed,
      onError: errors.add,
    );
    final OiButton archive = tester.widget(actionButton('Archive'));
    allowed = false;
    archive.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Archive?'), findsNothing);
    expect(source.started, 0);
    expect(errors.single, isA<BeakAuthorizationException>());
  });

  testWidgets('archive rechecks permission after confirmation', (tester) async {
    final source = _Source();
    var allowed = true;
    final errors = <BeakException>[];
    await pumpList(
      tester,
      source,
      canDelete: () => allowed,
      onError: errors.add,
    );
    final OiButton archive = tester.widget(actionButton('Archive'));
    archive.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Archive?'), findsOneWidget);
    allowed = false;
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    expect(source.started, 0);
    expect(source.deleteCalls, isEmpty);
    expect(errors.single, isA<BeakAuthorizationException>());
  });

  testWidgets('row archive cannot run twice while pending', (tester) async {
    final source = _Source();
    await pumpList(tester, source);
    final OiButton archive = tester.widget(actionButton('Archive'));
    archive.onTap!();
    archive.onTap!();
    await tester.pumpAndSettle();
    expect(
      source.getOneCalls,
      isEmpty,
      reason: 'built-in archive uses only the known row identity',
    );
    expect(find.text('Archive?'), findsOneWidget);
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    archive.onTap!();
    await tester.pumpAndSettle();
    expect(source.started, 1);
    expect(find.text('Archive?'), findsNothing);
    source.completion.complete();
    await tester.pumpAndSettle();
    expect(source.deleteCalls, [('notes', 'n1', false)]);
  });

  testWidgets('row archive confirms and awaits without batch lookup or undo', (
    tester,
  ) async {
    final source = _Source();
    await pumpList(tester, source);
    expect(actionButton('Delete'), findsNothing);
    source.queryCalls.clear();
    final OiButton archive = tester.widget(actionButton('Archive'));
    archive.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Archive?'), findsOneWidget);
    expect(
      source.getOneCalls,
      isEmpty,
      reason: 'built-in archive uses only the known row identity',
    );
    expect(source.batchAttempts, 0);
    expect(source.started, 0);
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    expect(source.started, 1);
    expect(source.deleteCalls, isEmpty);
    expect(find.text('One note'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);

    source.completion.complete();
    await tester.pumpAndSettle();
    expect(source.deleteCalls, [('notes', 'n1', false)]);
    expect(source.restoreCalls, isEmpty);
    expect(
      source.queryCalls,
      hasLength(1),
      reason: 'successful archive performs one fresh list query',
    );
    expect(find.byType(BeakResourceListPage), findsOneWidget);
    expect(find.text('One note'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
