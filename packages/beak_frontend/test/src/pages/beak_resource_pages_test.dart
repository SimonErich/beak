import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  final config = BeakPanelConfig(
    title: 'Beak Admin',
    apiBaseUrl: 'http://api.test',
    resources: [
      BeakResource(
        model: const NotePageModel(),
        icon: const BeakIconToken(OiIcons.notebook),
        filters: [NotePageModel.title.textFilter(label: 'Title')],
      ),
    ],
  );

  setUp(() {
    dataSource = FakeDataSource(
      models: const [NotePageModel(), NoteCommentModel()],
      records: {
        'notes': {
          'n1': BeakRecord(
            values: const {
              'id': BeakStringValue('n1'),
              'title': BeakStringValue('First note'),
            },
            relations: {
              'comments': [
                BeakRecord.fromRow(const {'id': 'k1', 'text': 'Nice one'}),
              ],
            },
          ),
        },
      },
    );
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(BeakPanel(config: config, dataSource: dataSource));
    await tester.pumpAndSettle();
  }

  Future<void> goToList(WidgetTester tester) async {
    await tester.tap(find.text('Notes').first);
    await tester.pumpAndSettle();
  }

  testWidgets('the panel opens on its first navigation destination', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.byType(BeakResourceListPage), findsOneWidget);
  });

  testWidgets('a BeakResource yields a working list page', (tester) async {
    await pumpPanel(tester);
    await goToList(tester);

    expect(find.byType(BeakResourceListPage), findsOneWidget);
    expect(find.byType(BeakDataTable), findsOneWidget);
    expect(find.byType(BeakFilterBar), findsOneWidget);
    expect(find.text('First note'), findsOneWidget);
  });

  testWidgets('list → create → save lands back in the list with the record', (
    tester,
  ) async {
    await pumpPanel(tester);
    await goToList(tester);

    await tester.tap(find.text('Create').first);
    await tester.pumpAndSettle();
    expect(find.byType(BeakResourceCreatePage), findsOneWidget);
    expect(find.byType(BeakConfiguredForm), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'Second note');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BeakConfiguredForm),
        matching: find.text('Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(dataSource.createCalls, hasLength(1));
    expect(find.byType(BeakResourceListPage), findsOneWidget);
    expect(find.text('Second note'), findsOneWidget);
  });

  testWidgets('the show page renders the detail view with actions', (
    tester,
  ) async {
    await pumpPanel(tester);
    await goToList(tester);

    final OiTable<BeakRecord> table = tester.widget(
      find.byType(OiTable<BeakRecord>),
    );
    table.onRowTap!(
      BeakRecord.fromRow(const {'id': 'n1', 'title': 'First note'}),
      0,
    );
    await tester.pumpAndSettle();

    expect(find.byType(BeakResourceShowPage), findsOneWidget);
    // The layout the model implies: the fields, then a tab per to-many.
    expect(find.text('First note'), findsWidgets);
    expect(find.text('Comments'), findsWidgets);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('the default show page is a read-mode form over the model', (
    tester,
  ) async {
    await pumpPanel(tester);
    await goToList(tester);
    final OiTable<BeakRecord> table = tester.widget(
      find.byType(OiTable<BeakRecord>),
    );
    table.onRowTap!(
      BeakRecord.fromRow(const {'id': 'n1', 'title': 'First note'}),
      0,
    );
    await tester.pumpAndSettle();

    final form = tester.widget<BeakConfiguredForm>(
      find.byType(BeakConfiguredForm),
    );
    expect(form.mode, BeakFormMode.read);
    expect(form.recordId, 'n1');
    // A to-many relationship keeps its own tab with the related rows.
    expect(find.text('Comments'), findsWidgets);
    expect(find.text('Nice one'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('read-role record actions appear on the default show page', (
    tester,
  ) async {
    final executed = <String?>[];
    final withAction = BeakPanelConfig(
      title: 'Beak Admin',
      resources: [
        BeakResource(
          model: const NotePageModel(),
          recordActions: [
            BeakRecordAction(
              key: 'ping',
              label: 'Ping',
              roles: const {BeakScreenRole.read},
              onExecute: (record, context) async =>
                  executed.add(record['title']?.raw?.toString()),
            ),
            BeakRecordAction(
              key: 'listOnly',
              label: 'List only',
              roles: const {BeakScreenRole.list},
              onExecute: (record, context) async {},
            ),
          ],
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(config: withAction, dataSource: dataSource),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes/n1');
    await tester.pumpAndSettle();

    expect(find.text('List only'), findsNothing);
    await tester.tap(find.text('Ping'));
    await tester.pumpAndSettle();
    expect(executed, ['First note']);
  });

  testWidgets('the default show page reloads when the record changes', (
    tester,
  ) async {
    await pumpPanel(tester);
    GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes/n1');
    await tester.pumpAndSettle();
    expect(find.text('First note'), findsWidgets);

    final source = beakDependencies(
      tester.element(find.byType(BeakResourceShowPage)),
    )<BeakDataSource>();
    await source.update(
      'notes',
      'n1',
      BeakRecord.fromRow(const {'title': 'Renamed note'}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Renamed note'), findsWidgets);
    expect(find.text('First note'), findsNothing);
  });

  testWidgets('the show page costs one query, relations included', (
    tester,
  ) async {
    await pumpPanel(tester);
    await goToList(tester);
    dataSource.clearRecordedCalls();

    final OiTable<BeakRecord> table = tester.widget(
      find.byType(OiTable<BeakRecord>),
    );
    table.onRowTap!(
      BeakRecord.fromRow(const {'id': 'n1', 'title': 'First note'}),
      0,
    );
    await tester.pumpAndSettle();

    // The record and its comments arrive together: the relation manager
    // renders its rows without a query of its own.
    expect(find.text('Nice one'), findsOneWidget);
    expect(dataSource.queryCalls, hasLength(1));
    expect(dataSource.getOneCalls, isEmpty);
    expect(
      dataSource.queryCalls.single.relationLoads.single.relationKey,
      'comments',
    );
  });

  testWidgets('the edit page prefills and saves back to the show page', (
    tester,
  ) async {
    await pumpPanel(tester);
    await goToList(tester);
    final OiTable<BeakRecord> table = tester.widget(
      find.byType(OiTable<BeakRecord>),
    );
    table.onRowTap!(
      BeakRecord.fromRow(const {'id': 'n1', 'title': 'First note'}),
      0,
    );
    await tester.pumpAndSettle();

    dataSource.clearRecordedCalls();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(BeakResourceEditPage), findsOneWidget);
    expect(
      tester.widget<BeakPageScaffold>(find.byType(BeakPageScaffold)).title,
      'First note',
    );
    expect(find.text('Edit Notes'), findsNothing);
    expect(find.textContaining('Edit Notes ·'), findsNothing);
    expect(
      dataSource.queryCalls,
      hasLength(1),
      reason: 'The heading needs no additional record fetch.',
    );
    expect(dataSource.getOneCalls, isEmpty);
    expect(find.text('First note'), findsWidgets);

    await tester.enterText(find.byType(EditableText).last, 'Renamed note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(dataSource.updateCalls, hasLength(1));
    expect(find.byType(BeakResourceShowPage), findsOneWidget);
  });

  testWidgets('typing into the list filter re-queries with the predicate', (
    tester,
  ) async {
    await pumpPanel(tester);
    await goToList(tester);
    dataSource.queryCalls.clear();

    tester
        .widget<OiFilterChip>(
          find.byWidgetPredicate(
            (widget) => widget is OiFilterChip && widget.label == 'Title',
          ),
        )
        .onTap!
        .call();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'First');
    await tester.pumpAndSettle();

    expect(dataSource.queryCalls, isNotEmpty);
    final BeakFieldFilter filter = switch (dataSource.queryCalls.last.filter) {
      final BeakFieldFilter field => field,
      final Object? other => fail('Expected a field filter, got $other.'),
    };
    expect(filter.columnKey, 'title');
    expect(filter.operator, BeakOperator.contains);
    expect(filter.value, const BeakStringValue('First'));
  });
}

/// Typed column constants of the pages fixture model.
abstract final class NotePageColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Required title.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    sortable: true,
    rules: [BeakRequired()],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [id, title];
}

/// The pages fixture model: the minimal notes resource the page-flow
/// tests drive end-to-end.
final class NotePageModel extends BeakModel {
  /// Creates the model.
  const NotePageModel();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => NotePageColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    NotePageRelations.comments,
  ];

  @override
  List<BeakModel> get relatedModels => const [NoteCommentModel()];

  /// The typed title field the resource filters and forms address.
  static const title = BeakScalarField<String>(
    model: NotePageModel(),
    column: NotePageColumns.title,
  );
}

/// The comments a [NotePageModel] note owns.
final class NoteCommentModel extends BeakModel {
  /// Creates the model.
  const NoteCommentModel();

  @override
  String get table => 'comments';

  @override
  String get displayColumnKey => 'text';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'text', label: 'Text'),
    BeakStringColumn(key: 'note_id', label: 'Note'),
  ];
}

/// Typed relations of the [NotePageModel] fixture.
abstract final class NotePageRelations {
  /// The note's comments.
  static const comments = BeakHasMany(
    key: 'comments',
    label: 'Comments',
    relatedTable: 'comments',
    displayColumnKey: 'text',
    foreignKey: 'note_id',
  );
}
