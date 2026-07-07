import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  group('BeakResourceView.build', () {
    const model = ArticleModel();

    test('table view builds a table block over the model', () {
      const view = BeakTableView();
      expect(view.key, 'table');
      expect(view.label, 'Table');
      expect(
        view.build(model),
        isA<BeakTableBlock>().having((b) => b.model.table, 'model', 'articles'),
      );
    });

    test('calendar view builds a calendar block with its bindings', () {
      const view = BeakCalendarView(
        titleField: ArticleColumns.title,
        startField: ArticleColumns.publishedAt,
      );
      expect(view.key, 'calendar');
      expect(view.label, 'Calendar');
      expect(
        view.build(model),
        isA<BeakCalendarBlock>()
            .having((b) => b.model.table, 'model', 'articles')
            .having((b) => b.titleField, 'titleField', ArticleColumns.title)
            .having(
              (b) => b.startField,
              'startField',
              ArticleColumns.publishedAt,
            ),
      );
    });

    test('kanban view builds a kanban block grouped by the enum', () {
      const view = BeakKanbanView(
        groupField: ArticleColumns.status,
        titleField: ArticleColumns.title,
        label: 'Board',
      );
      expect(view.key, 'kanban');
      expect(
        view.build(model),
        isA<BeakKanbanBlock>()
            .having((b) => b.groupField, 'groupField', ArticleColumns.status)
            .having((b) => b.titleField, 'titleField', ArticleColumns.title),
      );
    });
  });

  group('BeakResourceListPage view-mode switcher', () {
    late FakeDataSource dataSource;

    const config = BeakPanelConfig(
      title: 'Beak Admin',
      apiBaseUrl: 'http://api.test',
      resources: [
        BeakResource(
          model: ArticleModel(),
          icon: BeakIconToken(OiIcons.notebook),
          viewModes: [
            BeakTableView(),
            BeakKanbanView(
              groupField: ArticleColumns.status,
              titleField: ArticleColumns.title,
            ),
          ],
        ),
      ],
    );

    setUp(() {
      dataSource = FakeDataSource(
        records: {
          'articles': {
            'a1': BeakRecord.fromRow(const {
              'id': 'a1',
              'title': 'Draft one',
              'status': 'draft',
            }),
            'a2': BeakRecord.fromRow(const {
              'id': 'a2',
              'title': 'Live two',
              'status': 'published',
            }),
          },
        },
      );
    });

    Future<void> pumpList(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakPanel(config: config, dataSource: dataSource),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Articles').first);
      await tester.pumpAndSettle();
    }

    testWidgets('offers a segmented control and switches to the board', (
      tester,
    ) async {
      await pumpList(tester);

      expect(find.byType(OiSegmentedControl<int>), findsOneWidget);
      expect(find.byType(BeakDataTable), findsOneWidget);
      expect(find.byType(OiKanban<BeakRecord>), findsNothing);

      await tester.tap(find.text('Board').first);
      await tester.pumpAndSettle();

      expect(find.byType(OiKanban<BeakRecord>), findsOneWidget);
      final board = tester.widget<OiKanban<BeakRecord>>(
        find.byType(OiKanban<BeakRecord>),
      );
      expect(board.columns, hasLength(ArticleStatus.values.length));

      await tester.tap(find.text('Table').first);
      await tester.pumpAndSettle();

      expect(find.byType(BeakDataTable), findsOneWidget);
    });
  });
}
