import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  const config = BeakPanelConfig(
    title: 'Beak Admin',
    apiBaseUrl: 'http://api.test',
    resources: [
      BeakResource(
        model: NotePageModel(),
        icon: BeakIconToken(OiIcons.notebook),
        filters: [
          BeakTextFilter(column: NotePageColumns.title, label: 'Title'),
        ],
      ),
    ],
    dashboardStats: [
      BeakStat(
        label: 'Notes',
        aggregate: BeakAggregateSpec.count(table: 'notes'),
      ),
    ],
  );

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'First note'}),
        },
      },
    )..aggregateHandler = (spec) => 41;
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

  testWidgets('the dashboard route renders the configured stats', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('41'), findsOneWidget);
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
    expect(find.byType(BeakDataForm), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'Second note');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BeakDataForm),
        matching: find.text('Create'),
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
    expect(find.byType(BeakDetailView), findsOneWidget);
    expect(find.text('First note'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
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

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(BeakResourceEditPage), findsOneWidget);
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
}
