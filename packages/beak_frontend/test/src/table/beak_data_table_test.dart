import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;
  late OiTableController controller;

  BeakRecord note(int index) =>
      BeakRecord.fromRow({'id': 'n$index', 'title': 'Note $index'});

  Future<void> pumpTable(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    bool enableDelete = true,
    List<BeakTableAction> actions = const [],
    List<BeakTableAction> bulkActions = const [],
    List<BeakTableColumn>? presentations,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        locale: locale,
        supportedLocales: BeakLocalizations.supportedLocales,
        localizationsDelegates: const [BeakLocalizations.delegate],
        theme: OiThemeData.light(),
        home: BeakDataTable(
          model: const NoteModel(),
          dataSource: dataSource,
          controller: controller,
          actions: actions,
          enableDelete: enableDelete,
          bulkActions: bulkActions,
          presentations: presentations,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          for (var index = 1; index <= 3; index += 1) 'n$index': note(index),
        },
      },
    );
    controller = OiTableController(serverSidePagination: true);
  });

  testWidgets('initial query sorting is reflected by its presentation header', (
    tester,
  ) async {
    const field = BeakScalarField<String>(
      model: NoteModel(),
      column: BeakStringColumn(key: 'title', label: 'Title', sortable: true),
    );
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakDataTable(
          model: const NoteModel(),
          dataSource: dataSource,
          controller: controller,
          initialSpec: const NoteModel().query().orderBy(
            const BeakStringColumn(key: 'title', label: 'Title', sortable: true),
            descending: true,
          ),
          presentations: [
            BeakTableColumn(
              key: 'identity',
              label: 'Identity',
              sortBy: field,
              template: BeakRecordTemplate.fields(title: field),
            ),
          ],
          enableDelete: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.sortColumnId, 'identity');
    expect(controller.sortAscending, isFalse);
    expect(find.descendant(of: find.byKey(const Key('oi_table_header')), matching: find.byIcon(OiIcons.arrowDown)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'typed table fields preserve declared order and load related paths',
    (tester) async {
      const related = ArticleRelations.category;
      const name = BeakStringColumn(key: 'name', label: 'Category name');
      dataSource = FakeDataSource(
        records: {
          'articles': {
            'a1': BeakRecord.fromRow({
              'id': 'a1',
              'title': 'Main',
              'category_id': 'c1',
            }),
          },
          'categories': {
            'c1': BeakRecord.fromRow({'id': 'c1', 'name': 'Related title'}),
          },
        },
      );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakDataTable(
            model: const ArticleModel(),
            dataSource: dataSource,
            enableDelete: false,
            fields: const [
              BeakScalarField<String>(
                model: ArticleModel(),
                column: name,
                path: [related],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Related title'), findsOneWidget);
      expect(find.text('Main'), findsNothing);
      final table = tester.widget<OiTable<BeakRecord>>(
        find.byType(OiTable<BeakRecord>),
      );
      expect(table.columns.map((column) => column.id), ['category.name']);
      expect(
        dataSource.queryCalls.last.relationLoads.single.relationKey,
        'category',
      );
    },
  );

  group('rendering', () {
    testWidgets('presentation columns forward header and cell alignment', (
      tester,
    ) async {
      await pumpTable(
        tester,
        enableDelete: false,
        presentations: [
          BeakTableColumn.field(
            const BeakScalarField<String>(
              model: NoteModel(),
              column: BeakStringColumn(key: 'title', label: 'Title'),
            ),
            textAlign: TextAlign.end,
            cellPadding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ],
      );
      final table = tester.widget<OiTable<BeakRecord>>(
        find.byType(OiTable<BeakRecord>),
      );
      expect(table.columns.single.textAlign, TextAlign.end);
      expect(
        table.columns.single.cellPadding,
        const EdgeInsets.symmetric(horizontal: 4),
      );
      expect(
        tester.getTopRight(find.text('Title')).dx,
        closeTo(tester.getTopRight(find.text('Note 1')).dx, 1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow tables scroll without squeezing readable columns', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakDataTable(
            model: const ArticleModel(),
            dataSource: FakeDataSource(
              records: {
                'articles': {
                  'a1': BeakRecord.fromRow({'id': 'a1', 'title': 'Cold brew'}),
                },
              },
            ),
            actions: [
              BeakTableAction(id: 'view', label: 'View', onRun: (_) async {}),
              BeakTableAction(id: 'edit', label: 'Edit', onRun: (_) async {}),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final table = tester.widget<OiTable<BeakRecord>>(
        find.byType(OiTable<BeakRecord>),
      );
      expect(
        table.columns.where((column) => column.id != '_actions'),
        everyElement(
          predicate<OiTableColumn<BeakRecord>>(
            (column) => column.minWidth >= 160,
          ),
        ),
      );
      final horizontal = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontal, findsOneWidget);
      final scroll = tester.widget<SingleChildScrollView>(horizontal);
      expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
      await tester.drag(horizontal, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(scroll.controller!.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('German table chrome follows the ambient locale', (
      tester,
    ) async {
      await pumpTable(tester, locale: const Locale('de'));
      expect(find.text('Einträge pro Seite'), findsOneWidget);
      expect(find.text('1–3 von 3 Einträgen'), findsOneWidget);
      expect(find.text('3 Einträge'), findsOneWidget);
      final table = tester.widget<OiTable<BeakRecord>>(
        find.byType(OiTable<BeakRecord>),
      );
      expect(table.labels.columns, 'Spalten');
      expect(table.labels.manageColumns, 'Sichtbare Spalten verwalten');
      expect(find.text('Rows per page'), findsNothing);
      final pagination = tester.widget<OiPagination>(find.byType(OiPagination));
      expect(pagination.labels.navigation, 'Seitennavigation');
      expect(pagination.labels.firstPage, 'Erste Seite');
      expect(pagination.labels.previousPage, 'Vorherige Seite');
      expect(pagination.labels.nextPage, 'Nächste Seite');
      expect(pagination.labels.lastPage, 'Letzte Seite');
      expect(pagination.labels.page?.call(2), 'Seite 2');
    });

    testWidgets('English table chrome keeps its default labels', (
      tester,
    ) async {
      await pumpTable(tester);
      expect(find.text('Rows per page'), findsOneWidget);
      expect(find.text('Showing 1–3 of 3'), findsOneWidget);
      expect(find.text('3 rows'), findsOneWidget);
    });

    testWidgets('renders one column per table-visible column plus rows', (
      tester,
    ) async {
      await pumpTable(tester);

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Note 1'), findsOneWidget);
      expect(find.text('Note 3'), findsOneWidget);
    });

    testWidgets('a foreign key renders the related record, in one query', (
      tester,
    ) async {
      final articles = FakeDataSource(
        records: {
          'articles': {
            'a1': BeakRecord(
              values: const {
                'id': BeakStringValue('a1'),
                'title': BeakStringValue('Cold brew'),
              },
              relations: {
                'category': [
                  BeakRecord.fromRow(const {'id': 'c1', 'name': 'Coffee'}),
                ],
              },
            ),
          },
        },
      );
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakDataTable(
            model: const ArticleModel(),
            dataSource: articles,
            enableDelete: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The relationship, not the key it stores.
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('c1'), findsNothing);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Category id'), findsNothing);
      // And it cost the one page query, not one lookup per row.
      expect(articles.queryCalls, hasLength(1));
      expect(articles.getOneCalls, isEmpty);
      expect(articles.batchGetCalls, isEmpty);
      expect(
        articles.queryCalls.single.relationLoads.single.relationKey,
        'category',
      );
    });

    testWidgets('empty data renders the typed empty state', (tester) async {
      dataSource = FakeDataSource();
      await pumpTable(tester);

      expect(find.byType(OiEmptyState), findsOneWidget);
      expect(find.text('No records yet'), findsOneWidget);
    });

    testWidgets('a fetch failure renders the error state with retry', (
      tester,
    ) async {
      dataSource = _FailingSource();
      await pumpTable(tester);

      expect(find.text('Retry'), findsOneWidget);
      expect(
        find.text('The operation could not be completed.'),
        findsOneWidget,
      );
      expect(find.textContaining('backend unreachable'), findsNothing);
    });

    testWidgets('renders no Material widgets', (tester) async {
      await pumpTable(tester);
      final offenders = tester.allWidgets.where(
        (widget) => const {
          'Material',
          'Scaffold',
          'DataTable',
          'Card',
        }.contains(widget.runtimeType.toString()),
      );
      expect(offenders, isEmpty);
    });
  });

  group('server-side operations', () {
    testWidgets('tapping a sortable header emits a replaced BeakSort', (
      tester,
    ) async {
      await pumpTable(tester);

      await tester.tap(find.text('Title'));
      await tester.pumpAndSettle();
      expect(dataSource.queryCalls.last.sorts, [const BeakSort('title')]);

      await tester.tap(find.text('Title'));
      await tester.pumpAndSettle();
      expect(dataSource.queryCalls.last.sorts, [
        const BeakSort('title', descending: true),
      ]);
    });

    testWidgets('pagination emits the requested BeakPagination', (
      tester,
    ) async {
      dataSource = FakeDataSource(
        records: {
          'notes': {
            for (var index = 1; index <= 60; index += 1) 'n$index': note(index),
          },
        },
      );
      await pumpTable(tester);

      controller.pagination.goToPage(2);
      await tester.pumpAndSettle();

      expect(dataSource.queryCalls.last.pagination.page, 3);
    });

    testWidgets('changing the page size refetches from page one', (
      tester,
    ) async {
      await pumpTable(tester);

      controller.pagination.setPageSize(50);
      await tester.pumpAndSettle();

      expect(
        dataSource.queryCalls.last.pagination,
        const BeakPagination(perPage: 50),
      );
    });
  });

  group('actions', () {
    testWidgets('typed action columns reuse permission and pending execution', (
      tester,
    ) async {
      final selected = <Object>[];
      final pending = Completer<void>();
      const title = BeakScalarField<String>(
        model: NoteModel(),
        column: BeakStringColumn(key: 'title', label: 'Title'),
      );
      await pumpTable(
        tester,
        enableDelete: false,
        presentations: [
          BeakTableColumn.action(
            key: 'next',
            label: 'Next step',
            width: 180,
            selector: BeakValueBinding.field(title),
            choices: const {
              'Note 1': BeakActionPresentation(
                key: 'resolve',
                label: 'Resolve now',
              ),
              'Note 2': BeakActionPresentation(
                key: 'resolve',
                label: 'Unavailable',
              ),
            },
            fallback: const BeakActionPresentation(
              key: 'view',
              label: 'View details',
            ),
          ),
        ],
        actions: [
          BeakTableAction(
            id: 'resolve',
            label: 'Resolve',
            placement: BeakActionPlacement.column,
            visibleWhen: (record) => record['id']?.raw != 'n2',
            onRun: (ids) async {
              selected.addAll(ids);
              await pending.future;
            },
          ),
          BeakTableAction(
            id: 'view',
            label: 'View',
            placement: BeakActionPlacement.column,
            onRun: (ids) async => selected.addAll(ids),
          ),
        ],
      );
      expect(find.text('Resolve now'), findsOneWidget);
      expect(find.text('Unavailable'), findsNothing);
      expect(find.text('View details'), findsOneWidget);
      expect(find.bySemanticsLabel('More actions'), findsNothing);
      final resolveButton = tester.widget<OiButton>(
        find.byWidgetPredicate(
          (widget) => widget is OiButton && widget.label == 'Resolve now',
        ),
      );
      expect(resolveButton.semanticLabel, 'Resolve');
      expect(resolveButton.tooltip, 'Resolve');
      await tester.tap(find.text('Resolve now'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(selected, ['n1']);
      final waitingButton = tester.widget<OiButton>(
        find.byWidgetPredicate(
          (widget) => widget is OiButton && widget.label == 'Resolve now',
        ),
      );
      expect(waitingButton.onTap, isNull);
      expect(waitingButton.loading, isTrue);
      expect(selected, ['n1']);
      pending.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(selected, ['n1', 'n3']);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'overflow-only actions stay compact and invoke the selected record',
      (tester) async {
        final selected = <Object>[];
        await pumpTable(
          tester,
          enableDelete: false,
          actions: [
            BeakTableAction(
              id: 'inspect',
              label: 'Inspect record',
              placement: BeakActionPlacement.overflow,
              onRun: (ids) async => selected.addAll(ids),
            ),
          ],
        );
        expect(find.bySemanticsLabel('More actions'), findsNWidgets(3));
        final table = tester.widget<OiTable<BeakRecord>>(
          find.byType(OiTable<BeakRecord>),
        );
        expect(table.columns.last.width, lessThanOrEqualTo(80));
        await tester.tap(find.bySemanticsLabel('More actions').first);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Inspect record'), findsOneWidget);
        await tester.tap(find.text('Inspect record'));
        await tester.pumpAndSettle();
        expect(selected, ['n1']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a bulk action receives every selected id', (tester) async {
      final received = <List<Object>>[];
      await pumpTable(
        tester,
        bulkActions: [
          BeakTableAction(
            id: 'archive',
            label: 'Archive',
            onRun: (ids) async => received.add(ids),
          ),
        ],
      );

      controller
        ..selectRow('n1', multi: true)
        ..selectRow('n3', multi: true);
      await tester.pumpAndSettle();

      _tapButton(
        tester,
        find.byWidgetPredicate(
          (widget) => widget is OiButton && widget.label == 'Archive',
        ),
      );
      await tester.pumpAndSettle();

      expect(received.single, unorderedEquals(['n1', 'n3']));
    });

    testWidgets('a row action receives that row id', (tester) async {
      final received = <List<Object>>[];
      await pumpTable(
        tester,
        actions: [
          BeakTableAction(
            id: 'ping',
            label: 'Ping',
            icon: OiIcons.bell,
            onRun: (ids) async => received.add(ids),
          ),
        ],
      );

      // Taps inside OiTable are absorbed by its keyboard overlay (see
      // obers_ui's own table tests) — invoke the button's handler.
      _tapButton(
        tester,
        find.byWidgetPredicate(
          (widget) => widget is OiButton && widget.semanticLabel == 'Ping',
        ),
      );
      await tester.pumpAndSettle();

      expect(received.single, ['n1']);
    });

    testWidgets('delete removes optimistically, undo restores', (tester) async {
      await pumpTable(tester);

      _tapButton(tester, _deleteButton());
      await tester.pumpAndSettle();

      expect(find.text('Note 1'), findsNothing, reason: 'optimistic removal');
      expect(find.text('Undo'), findsOneWidget);
      expect(dataSource.deleteCalls, isEmpty, reason: 'not committed yet');

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Note 1'), findsOneWidget, reason: 'rolled back');
      expect(dataSource.deleteCalls, isEmpty);
    });

    testWidgets('delete commits to the data source after the undo window', (
      tester,
    ) async {
      await pumpTable(tester);

      _tapButton(tester, _deleteButton());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(dataSource.deleteCalls, [('notes', 'n1', false)]);
      expect(find.text('Note 1'), findsNothing);
    });
  });
}

Finder _deleteButton() => find.byWidgetPredicate(
  (widget) => widget is OiButton && widget.semanticLabel == 'Delete',
);

/// A data source whose queries always fail.
final class _FailingSource extends FakeDataSource {
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    throw const BeakStorageException('backend unreachable');
  }
}

/// Invokes the first matching button's handler directly — taps inside
/// OiTable are absorbed by its keyboard overlay (see obers_ui's own table
/// tests, which drive the controller for the same reason).
void _tapButton(WidgetTester tester, Finder finder) {
  final button = tester.widget<OiButton>(finder.first);
  final VoidCallback? onTap = button.onTap;
  expect(onTap, isNotNull, reason: 'button must be enabled');
  onTap?.call();
}
