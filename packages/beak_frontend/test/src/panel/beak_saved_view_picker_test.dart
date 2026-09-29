import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/query/beak_list_toolbar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(key: 'title', label: 'Title', sortable: true),
);

void main() {
  BeakResource resource() => BeakResource(
    model: const NoteModel(),
    screens: [
      BeakTableScreen(
        definition: BeakListDefinition(
          columns: [BeakTableColumn.field(_title)],
          savedViews: _store,
        ),
      ),
    ],
  );

  FakeDataSource source() => FakeDataSource(
    models: const [_View()],
    records: {
      'notes': {
        'a': BeakRecord.fromRow({'id': 'a', 'title': 'Urgent note'}),
        'b': BeakRecord.fromRow({'id': 'b', 'title': 'Ordinary note'}),
      },
      'views': {
        'v1': BeakRecord.fromRow({
          'id': 'v1',
          'name': 'Urgent notes',
          'resource': 'notes',
          'state': jsonEncode(BeakQueryState(search: 'Urgent').toJson()),
        }),
      },
    },
  );

  Future<void> openFilters(WidgetTester tester, FakeDataSource data) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(resources: [resource()], dataSource: data),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes');
    await tester.pumpAndSettle();
    await tester.tap(find.text('All filters'));
    await tester.pumpAndSettle();
  }

  testWidgets('the filter sheet offers the saved views to load', (
    tester,
  ) async {
    final data = source();
    await openFilters(tester, data);

    expect(find.text('Saved views'), findsOneWidget);
    expect(find.text('Save as view'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a view saved from the sheet lands in the views table', (
    tester,
  ) async {
    final data = source();
    await openFilters(tester, data);

    await tester.tap(find.text('Save as view'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Everything');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OiButton, 'Save').last);
    await tester.pumpAndSettle();

    final names = [
      for (final row in data.store.rowsOf('views')) row['name']?.raw,
    ];
    expect(names, containsAll(['Urgent notes', 'Everything']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a saved view applies it to the list and closes', (
    tester,
  ) async {
    final data = source();
    await openFilters(tester, data);

    await tester.tap(find.byType(OiSelect<Object>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Urgent notes').last);
    await tester.pumpAndSettle();

    expect(find.byType(BeakFilterEditor), findsNothing);
    expect(data.queryCalls.last.table, 'notes');
    expect(data.queryCalls.last.search?.term, 'Urgent');
    expect(tester.takeException(), isNull);
  });
}

const _name = BeakScalarField<String>(
  model: _View(),
  column: BeakStringColumn(key: 'name', label: 'Name'),
);
const _resource = BeakScalarField<String>(
  model: _View(),
  column: BeakStringColumn(key: 'resource', label: 'Resource'),
);
const _state = BeakScalarField<String>(
  model: _View(),
  column: BeakStringColumn(key: 'state', label: 'State'),
);
const _store = BeakSavedViewStore.model(
  model: _View(),
  name: _name,
  resource: _resource,
  state: _state,
);

final class _View extends BeakModel {
  const _View();
  @override
  String get table => 'views';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    _name.column,
    _resource.column,
    _state.column,
  ];
}
