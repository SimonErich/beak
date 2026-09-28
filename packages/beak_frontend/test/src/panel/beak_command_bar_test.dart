import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  test(
    'explicit password search sources report configuration errors without querying',
    () async {
      const secret = BeakStringColumn(
        key: 'secret',
        label: 'Secret',
        semantic: BeakSemantic.password(),
      );
      const panel = BeakPanelConfig(
        title: 'Private',
        resources: [
          BeakResource(
            model: NoteModel(),
            globalSearchSources: [
              BeakScalarField<String>(model: NoteModel(), column: secret),
            ],
          ),
        ],
      );
      final source = FakeDataSource();
      final result = await beakSearchResourcePage(panel, source, 'private');
      expect(result.items, isEmpty);
      expect(result.errors.values.single, isA<BeakConfigurationException>());
      expect(source.queryCalls, isEmpty);
    },
  );

  const config = BeakPanelConfig(
    title: 'Demo',
    apiBaseUrl: 'http://localhost',
    resources: [
      BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
    ],
    pages: [
      BeakScreen(
        path: '/reports',
        title: 'Reports',
        icon: BeakIconToken(OiIcons.barChart2),
        section: 'Insights',
        body: BeakTextBlock('reports'),
      ),
    ],
  );

  testWidgets(
    'opening the real command dialog focuses its input for immediate typing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = FakeDataSource();
      await tester.pumpWidget(BeakPanel(config: config, dataSource: source));
      await tester.pumpAndSettle();
      openBeakCommandBar(tester.element(find.byType(OiAppShell)), config);
      await tester.pumpAndSettle();
      final input = tester.widget<EditableText>(find.byType(EditableText));
      expect(input.focusNode.hasFocus, true);
      tester.testTextInput.enterText('Immediate');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(source.queryCalls.last.search?.term, 'Immediate');
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'mixed scalar search sends typed alternatives, never text against numbers',
    () async {
      const model = _SearchModel();
      final source = FakeDataSource(
        models: const [model],
        records: {
          'search_records': {
            '42': BeakRecord.fromRow({
              'id': 42,
              'name': 'Coffee',
              'enabled': false,
            }),
          },
        },
      );
      const panel = BeakPanelConfig(
        title: 'Search',
        resources: [BeakResource(model: model)],
      );
      final numeric = await beakSearchResourcePage(panel, source, '42');
      expect(numeric.items.single.title, 'Coffee');
      expect(source.queryCalls.last.search, isNull);
      final predicates = switch (source.queryCalls.last.filter) {
        BeakOrFilter(:final filters) => filters,
        _ => <BeakFilter>[],
      };
      expect(
        predicates,
        contains(
          isA<BeakFieldFilter>()
              .having((f) => f.columnKey, 'column', 'id')
              .having((f) => f.value, 'value', const BeakIntValue(42)),
        ),
      );
      final boolean = await beakSearchResourcePage(panel, source, 'false');
      expect(boolean.items.single.title, 'Coffee');
      await beakSearchResourcePage(panel, source, '2026-09-26');
      final dates = switch (source.queryCalls.last.filter) {
        BeakOrFilter(:final filters) =>
          filters.whereType<BeakAndFilter>().single.filters,
        _ => <BeakFilter>[],
      };
      expect(dates, hasLength(2));
      expect(
        dates.last,
        isA<BeakFieldFilter>()
            .having((f) => f.operator, 'operator', BeakOperator.lt)
            .having((f) => f.value.raw, 'end', DateTime(2026, 9, 27)),
      );
    },
  );

  testWidgets(
    'the palette refreshes the current query after writes and exposes retryable errors',
    (tester) async {
      final storage = _RetrySearch(
        records: {
          'notes': {
            'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Original'}),
          },
        },
      );
      final source = ModelBeakDataSource(
        registry: BeakModelRegistry()..register(const NoteModel()),
        fallback: storage,
      );
      addTearDown(source.dispose);
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: SizedBox(
            width: 640,
            height: 480,
            child: BeakSearchPalette(
              config: config,
              dataSource: source,
              onSelect: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'Original');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.textContaining('Original · Notes'), findsOneWidget);
      await source.update(
        'notes',
        'n1',
        BeakRecord.fromRow({'title': 'Original updated'}),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.textContaining('Original updated · Notes'), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Original',
      );
      storage.fail = true;
      await tester.enterText(find.byType(EditableText), 'Unreachable');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.textContaining('Notes: Search unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      storage.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.textContaining('Search unavailable'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'newest search wins out of order and disposed requests are ignored',
    (tester) async {
      final source = _DelayedSearch();
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: SizedBox(
            width: 640,
            height: 480,
            child: BeakSearchPalette(
              config: config,
              dataSource: source,
              onSelect: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'First');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Loading…'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Second');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      source.finish(1, 'Second');
      await tester.pumpAndSettle();
      source.finish(0, 'First');
      await tester.pumpAndSettle();
      expect(find.textContaining('Second · Notes'), findsOneWidget);
      expect(find.textContaining('First · Notes'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'Disposed');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(const SizedBox());
      source.finish(2, 'Disposed');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'resource search uses configured related fields and skips hidden resources',
    () async {
      final source = FakeDataSource(
        records: {
          'articles': {
            'a1': BeakRecord.fromRow({
              'id': 'a1',
              'title': 'Beans',
              'category_id': 'c1',
            }),
          },
          'categories': {
            'c1': BeakRecord.fromRow({'id': 'c1', 'name': 'Coffee'}),
          },
        },
      );
      final panel = BeakPanelConfig(
        title: 'Demo',
        resources: [
          const BeakResource(
            model: ArticleModel(),
            globalSearchSources: [
              BeakScalarField<String>(
                model: ArticleModel(),
                column: BeakStringColumn(key: 'name', label: 'Category'),
                path: [ArticleRelations.category],
              ),
            ],
          ),
          BeakResource(model: const NoteModel(), visibleWhen: () => false),
        ],
        apiBaseUrl: 'http://localhost',
      );
      final results = await beakSearchResources(panel, source, 'Coffee');
      expect(results.map((result) => result.title), ['Beans']);
      expect(results.single.id, '/articles/a1');
      expect(source.queryCalls.single.search?.columnKeys, ['category.name']);
    },
  );

  test('navigation commands cover the dashboard, resources, and pages', () {
    final routes = <String>[];
    final commands = beakNavigationCommands(config, routes.add);

    final labels = [for (final c in commands) c.label];
    expect(labels, containsAll(<String>['Dashboard', 'Notes', 'Reports']));

    // Executing a command routes to its destination.
    final reports = commands.firstWhere((c) => c.label == 'Reports');
    reports.onExecute!();
    expect(routes, ['/reports']);
  });

  test('the dashboard command is dropped when a page claims /', () {
    const withHome = BeakPanelConfig(
      title: 'Demo',
      apiBaseUrl: 'http://localhost',
      resources: [
        BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
      ],
      pages: [
        BeakScreen(
          path: '/',
          title: 'Home',
          icon: BeakIconToken(OiIcons.home),
          body: BeakTextBlock('home'),
        ),
      ],
    );
    final labels = [
      for (final c in beakNavigationCommands(withHome, (_) {})) c.label,
    ];
    expect(labels, isNot(contains('Dashboard')));
    expect(labels, contains('Home'));
  });

  test('hidden resources never expose navigation commands', () {
    final hidden = BeakPanelConfig(
      title: 'Demo',
      apiBaseUrl: 'http://localhost',
      resources: [
        BeakResource(
          model: const NoteModel(),
          icon: const BeakIconToken(OiIcons.file),
          visibleWhen: () => false,
        ),
      ],
    );
    expect(
      beakNavigationCommands(hidden, (_) {}).map((command) => command.id),
      isNot(contains('nav:/notes')),
    );
  });
}

final class _SearchModel extends BeakModel {
  const _SearchModel();
  @override
  String get table => 'search_records';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id', searchable: true),
    BeakStringColumn(key: 'name', label: 'Name', searchable: true),
    BeakBoolColumn(key: 'enabled', label: 'Enabled', searchable: true),
    BeakDateTimeColumn(key: 'date', label: 'Date', searchable: true),
  ];
}

final class _RetrySearch extends FakeDataSource {
  _RetrySearch({super.records});
  bool fail = false;
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    if (fail) throw const BeakStorageException('Search unavailable');
    return super.query(spec);
  }
}

final class _DelayedSearch extends FakeDataSource {
  final responses = <Completer<BeakPage<BeakRecord>>>[];
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    final pending = Completer<BeakPage<BeakRecord>>();
    responses.add(pending);
    return pending.future;
  }

  void finish(int index, String title) => responses[index].complete(
    BeakPage(
      items: [
        BeakRecord.fromRow({'id': title, 'title': title}),
      ],
      total: 1,
      page: 1,
      perPage: 5,
    ),
  );
}
