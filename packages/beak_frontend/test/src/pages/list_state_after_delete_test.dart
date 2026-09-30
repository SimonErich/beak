import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    sortable: true,
  ),
);

/// The `list` URL parameter of a list searched for [term].
String _viewOf(String term) => base64Url.encode(
  utf8.encode(jsonEncode(BeakQueryState(search: term).toJson())),
);

/// The search term the router's current address carries.
String? _searchOf(GoRouter router) => BeakQueryController.readUri(
  router.routeInformationProvider.value.uri,
)?.search;

void main() {
  tearDown(beakLocator.reset);

  testWidgets('deleting a row keeps the list on the view the person chose', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Note one'}),
          'n2': BeakRecord.fromRow({'id': 'n2', 'title': 'Note two'}),
          'x1': BeakRecord.fromRow({'id': 'x1', 'title': 'Unrelated'}),
        },
      },
    );
    await tester.pumpWidget(
      BeakPanel(
        resources: [
          BeakResource(
            model: const NoteModel(),
            screens: [
              BeakTableScreen(
                definition: BeakListDefinition(
                  columns: [BeakTableColumn.field(_title)],
                  showPresetCounts: false,
                ),
              ),
            ],
          ),
        ],
        dataSource: source,
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    router.go(
      Uri(
        path: '/notes',
        queryParameters: {'list': _viewOf('Note')},
      ).toString(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unrelated'), findsNothing);

    await tester.tap(find.bySemanticsLabel('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(source.deleteCalls, hasLength(1));
    expect(_searchOf(router), 'Note');
    expect(find.text('Unrelated'), findsNothing);
  });

  testWidgets('the create button remembers the list it was pressed on', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        resources: const [BeakResource(model: NoteModel())],
        dataSource: FakeDataSource(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    router.go(
      Uri(
        path: '/notes',
        queryParameters: {'list': _viewOf('Note')},
      ).toString(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OiButton, 'Create').first);
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/notes/create');
    expect(
      BeakBackButton.destination(uri, '/notes'),
      startsWith('/notes?list='),
    );
  });

  testWidgets('editing a record and saving keeps the way back to the list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Note one'}),
          'x1': BeakRecord.fromRow({'id': 'x1', 'title': 'Unrelated'}),
        },
      },
    );
    await tester.pumpWidget(
      BeakPanel(
        resources: [
          BeakResource(
            model: const NoteModel(),
            screens: [
              BeakTableScreen(
                definition: BeakListDefinition(
                  columns: [BeakTableColumn.field(_title)],
                  showPresetCounts: false,
                ),
              ),
            ],
          ),
        ],
        dataSource: source,
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    router.go(
      Uri(
        path: '/notes',
        queryParameters: {'list': _viewOf('Note')},
      ).toString(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note one'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OiButton, 'Edit'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/notes/n1/edit');

    await tester.enterText(find.byType(EditableText).last, 'Renamed note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/notes/n1');
    await tester.tap(find.widgetWithText(OiButton, 'Back'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/notes');
    expect(_searchOf(router), 'Note');
  });

  testWidgets('deleting from a record page returns to the view it came from', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Note one'}),
          'x1': BeakRecord.fromRow({'id': 'x1', 'title': 'Unrelated'}),
        },
      },
    );
    await tester.pumpWidget(
      BeakPanel(
        resources: [
          BeakResource(
            model: const NoteModel(),
            screens: [
              BeakTableScreen(
                definition: BeakListDefinition(
                  columns: [BeakTableColumn.field(_title)],
                  showPresetCounts: false,
                ),
              ),
            ],
          ),
        ],
        dataSource: source,
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    router.go(
      Uri(
        path: '/notes',
        queryParameters: {'list': _viewOf('Note')},
      ).toString(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note one'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/notes/n1');

    await tester.tap(find.widgetWithText(OiButton, 'Delete'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(source.deleteCalls, hasLength(1));
    expect(router.routeInformationProvider.value.uri.path, '/notes');
    expect(_searchOf(router), 'Note');
  });
}
