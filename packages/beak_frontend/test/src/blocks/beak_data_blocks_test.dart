import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'Alpha'}),
          'n2': BeakRecord.fromRow(const {'id': 'n2', 'title': 'Beta'}),
        },
      },
    )..aggregateHandler = (spec) => spec.table == 'notes' ? 200 : 160;
    registerBeakDependencies(
      config: const BeakPanelConfig(
        title: 'Demo',
        apiBaseUrl: 'http://localhost',
        resources: [
          BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
        ],
      ),
      dataSource: dataSource,
    );
  });

  Future<void> pump(WidgetTester tester, BeakBlock block) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakBlockHost(block: block),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('BeakChartBlock', () {
    BeakChartBlock chartOf(BeakChartType type) => BeakChartBlock(
      title: 'Notes',
      type: type,
      query: const NoteModel().query(),
      map: (records) => [
        for (final (index, record) in records.indexed)
          BeakChartPoint(
            label: record['title']?.raw?.toString() ?? '',
            value: index + 1,
          ),
      ],
    );

    testWidgets('maps records to a line chart', (tester) async {
      await pump(tester, chartOf(BeakChartType.line));

      final chart = tester.widget<OiLineChart>(find.byType(OiLineChart));
      expect(chart.series.single.points.map((point) => (point.x, point.y)), [
        (0, 1),
        (1, 2),
      ]);
    });

    testWidgets('an explicit x positions a line point', (tester) async {
      await pump(
        tester,
        BeakChartBlock(
          title: 'Notes',
          type: BeakChartType.line,
          query: const NoteModel().query(),
          map: (_) => const [BeakChartPoint(label: 'Q3', value: 4, x: 3)],
        ),
      );

      final chart = tester.widget<OiLineChart>(find.byType(OiLineChart));
      expect(chart.series.single.points.single.x, 3);
    });

    testWidgets('maps records to a bar chart', (tester) async {
      await pump(tester, chartOf(BeakChartType.bar));

      final chart = tester.widget<OiBarChart>(find.byType(OiBarChart));
      expect(chart.categories.map((category) => category.label), [
        'Alpha',
        'Beta',
      ]);
    });

    testWidgets('maps records to a pie chart', (tester) async {
      await pump(tester, chartOf(BeakChartType.pie));

      final chart = tester.widget<OiPieChart>(find.byType(OiPieChart));
      expect(chart.segments.map((segment) => segment.value), [1, 2]);
    });

    testWidgets('maps records to an area chart', (tester) async {
      await pump(tester, chartOf(BeakChartType.area));

      final chart = tester.widget<OiAreaChart<BeakChartPoint>>(
        find.byType(OiAreaChart<BeakChartPoint>),
      );
      final series = chart.series.single;
      final data = series.data ?? const <BeakChartPoint>[];
      expect(data.map(series.xMapper), [0, 1]);
      expect(data.map(series.yMapper), [1, 2]);
    });

    testWidgets('a failed query says so and a retry reads again', (
      tester,
    ) async {
      final flaky = _Flaky(
        records: {
          'notes': {
            'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'Alpha'}),
            'n2': BeakRecord.fromRow(const {'id': 'n2', 'title': 'Beta'}),
          },
        },
      )..failing = true;
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Demo',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
          ],
        ),
        dataSource: flaky,
      );
      await pump(tester, chartOf(BeakChartType.pie));

      expect(
        find.text('The operation could not be completed.'),
        findsOneWidget,
      );
      expect(find.textContaining('disk detail'), findsNothing);
      expect(
        tester.widget<OiPieChart>(find.byType(OiPieChart)).segments,
        isEmpty,
      );

      flaky.failing = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
      expect(
        tester.widget<OiPieChart>(find.byType(OiPieChart)).segments,
        hasLength(2),
      );
    });

    testWidgets('a list block says so when its read fails', (tester) async {
      final flaky = _Flaky(records: const {})..failing = true;
      registerBeakDependencies(
        config: const BeakPanelConfig(
          title: 'Demo',
          apiBaseUrl: 'http://localhost',
          resources: [
            BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
          ],
        ),
        dataSource: flaky,
      );
      await pump(
        tester,
        BeakGalleryBlock(
          query: const NoteModel().query(),
          imageUrlField: const NoteModel().columns.first,
        ),
      );

      expect(
        find.text('The operation could not be completed.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('maps records to a donut chart', (tester) async {
      await pump(
        tester,
        BeakChartBlock(
          title: 'Notes',
          type: BeakChartType.donut,
          query: const BeakQuerySpec(table: 'notes'),
          map: (records) => [
            for (final record in records)
              BeakChartPoint(
                label: record['title']?.raw?.toString() ?? '',
                value: 1,
              ),
          ],
        ),
      );

      expect(find.byType(OiDonutChart), findsOneWidget);
      final chart = tester.widget<OiDonutChart>(find.byType(OiDonutChart));
      expect(chart.segments.map((segment) => segment.label), ['Alpha', 'Beta']);
    });

    testWidgets('maps records to a radar chart', (tester) async {
      await pump(
        tester,
        BeakChartBlock(
          title: 'Notes',
          type: BeakChartType.radar,
          query: const BeakQuerySpec(table: 'notes'),
          map: (records) => [
            for (final record in records)
              BeakChartPoint(
                label: record['title']?.raw?.toString() ?? '',
                value: 3,
              ),
          ],
        ),
      );

      final chart = tester.widget<OiRadarChart>(find.byType(OiRadarChart));
      expect(chart.axes, ['Alpha', 'Beta']);
    });

    testWidgets('maps records to a funnel chart', (tester) async {
      await pump(
        tester,
        BeakChartBlock(
          title: 'Notes',
          type: BeakChartType.funnel,
          query: const BeakQuerySpec(table: 'notes'),
          map: (records) => [
            for (final record in records)
              BeakChartPoint(
                label: record['title']?.raw?.toString() ?? '',
                value: 5,
              ),
          ],
        ),
      );

      final chart = tester.widget<OiFunnelChart>(find.byType(OiFunnelChart));
      expect(chart.stages.map((stage) => stage.label), ['Alpha', 'Beta']);
    });
  });

  group('BeakTableBlock', () {
    testWidgets(
      'typed fields are exact and read-only blocks omit delete actions',
      (tester) async {
        const fields = [
          BeakScalarField<String>(
            model: ArticleModel(),
            column: ArticleColumns.title,
          ),
          BeakScalarField<String>(
            model: ArticleModel(),
            column: BeakStringColumn(key: 'name', label: 'Category'),
            path: [ArticleRelations.category],
          ),
        ];
        await pump(
          tester,
          const BeakTableBlock(
            model: ArticleModel(),
            fields: fields,
            enableDelete: false,
          ),
        );
        final table = tester.widget<BeakDataTable>(find.byType(BeakDataTable));
        final rendered = tester.widget<OiTable<BeakRecord>>(
          find.byType(OiTable<BeakRecord>),
        );
        expect(table.fields, fields);
        expect(table.enableDelete, false);
        expect(rendered.columns.map((column) => column.id), [
          'title',
          'category.name',
        ]);
        expect(
          dataSource.queryCalls.single.relationLoads.map(
            (load) => load.relationKey,
          ),
          ['category'],
        );
        expect(find.bySemanticsLabel('Delete'), findsNothing);
      },
    );

    testWidgets('binds the model into a bounded data table', (tester) async {
      await pump(
        tester,
        const BeakTableBlock(title: 'All notes', model: NoteModel()),
      );

      final table = tester.widget<BeakDataTable>(find.byType(BeakDataTable));
      expect(table.model.table, 'notes');
      expect(table.enableDelete, true);
      expect(
        tester
            .widget<OiTable<BeakRecord>>(find.byType(OiTable<BeakRecord>))
            .columns
            .map((column) => column.id),
        contains('_actions'),
      );
      expect(find.text('All notes'), findsWidgets);
      expect(find.text('Alpha'), findsWidgets);
    });
  });
}

/// A source whose reads fail while [failing] is set.
final class _Flaky extends FakeDataSource {
  _Flaky({required super.records});

  bool failing = false;

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    if (failing) throw const BeakStorageException('disk detail');
    return super.query(spec);
  }
}
