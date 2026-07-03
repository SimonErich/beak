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
    List<BeakTableAction> actions = const [],
    List<BeakTableAction> bulkActions = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakDataTable(
          model: const NoteModel(),
          dataSource: dataSource,
          controller: controller,
          actions: actions,
          bulkActions: bulkActions,
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

  group('rendering', () {
    testWidgets('renders one column per table-visible column plus rows', (
      tester,
    ) async {
      await pumpTable(tester);

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Note 1'), findsOneWidget);
      expect(find.text('Note 3'), findsOneWidget);
    });

    testWidgets('empty data renders the typed empty state', (tester) async {
      dataSource = FakeDataSource();
      await pumpTable(tester);

      expect(find.byType(OiEmptyState), findsOneWidget);
      expect(find.text('No notes yet'), findsOneWidget);
    });

    testWidgets('a fetch failure renders the error state with retry', (
      tester,
    ) async {
      dataSource = _FailingSource();
      await pumpTable(tester);

      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('backend unreachable'), findsOneWidget);
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

      expect(dataSource.deleteCalls, [('notes', 'n1')]);
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
