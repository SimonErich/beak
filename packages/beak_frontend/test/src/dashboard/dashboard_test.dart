import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  setUp(() {
    dataSource =
        FakeDataSource(
            records: {
              'articles': {
                'a1': BeakRecord.fromRow(const {
                  'id': 'a1',
                  'title': 'One',
                  'price': 10.0,
                }),
                'a2': BeakRecord.fromRow(const {
                  'id': 'a2',
                  'title': 'Two',
                  'price': 30.0,
                }),
              },
            },
          )
          ..aggregateHandler = (spec) => switch (spec.function) {
            BeakAggregateFunction.count => 42,
            BeakAggregateFunction.sum => 1250.5,
            BeakAggregateFunction.avg => 3,
          };
  });

  final stats = [
    const BeakStat(
      label: 'Articles',
      aggregate: BeakAggregateSpec.count(table: 'articles'),
      icon: OiIcons.newspaper,
    ),
    const BeakStat(
      label: 'Inventory value',
      aggregate: BeakAggregateSpec.sum(
        table: 'articles',
        column: ArticleColumns.price,
      ),
      prefix: '€',
    ),
  ];

  List<BeakChart> charts(BeakChartType type) => [
    BeakChart(
      title: 'Prices',
      type: type,
      query: const BeakQuerySpec(table: 'articles'),
      map: (records) => [
        for (final record in records)
          BeakChartPoint(
            label: record['title']?.raw?.toString() ?? '',
            value: switch (record['price']?.raw) {
              final num price => price.toDouble(),
              _ => 0,
            },
          ),
      ],
    ),
  ];

  Future<void> pumpDashboard(
    WidgetTester tester, {
    List<BeakChart> charts = const [],
    List<BeakStat>? dashboardStats,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakDashboard(
          stats: dashboardStats ?? stats,
          charts: charts,
          dataSource: dataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('stats call aggregate and show formatted values', (tester) async {
    await pumpDashboard(tester);

    expect(dataSource.aggregateCalls, hasLength(2));
    expect(
      dataSource.aggregateCalls.first.function,
      BeakAggregateFunction.count,
    );
    expect(find.text('42'), findsOneWidget);
    expect(find.text('€1250.50'), findsOneWidget);
  });

  testWidgets(
    'metrics refresh after writes and offer retry after load failure',
    (tester) async {
      final registry = BeakModelRegistry()..register(const ArticleModel());
      final source = ModelBeakDataSource(
        registry: registry,
        fallback: dataSource,
      );
      addTearDown(source.dispose);
      dataSource.aggregateHandler = (_) =>
          throw const BeakConfigurationException('Offline');
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakStatCard(stat: stats.first, dataSource: source),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      dataSource.aggregateHandler = (_) => 3;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      dataSource.aggregateHandler = (_) => 4;
      await source.create(
        'articles',
        BeakRecord.fromRow({'id': 'new', 'title': 'New'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
    },
  );

  testWidgets(
    'hidden stats never fetch and permission changes preserve other cards',
    (tester) async {
      var canReadPrivate = false;
      final guardedStats = [
        BeakStat(
          label: 'Private articles',
          aggregate: const BeakAggregateSpec.count(table: 'private_articles'),
          visibleWhen: () => canReadPrivate,
        ),
        stats.first,
      ];

      await pumpDashboard(tester, dashboardStats: guardedStats);
      expect(find.text('Private articles'), findsNothing);
      expect(dataSource.aggregateCalls.map((spec) => spec.table), ['articles']);

      canReadPrivate = true;
      await pumpDashboard(tester, dashboardStats: guardedStats);
      expect(find.text('Private articles'), findsOneWidget);
      expect(dataSource.aggregateCalls.map((spec) => spec.table), [
        'articles',
        'private_articles',
      ]);

      canReadPrivate = false;
      await pumpDashboard(tester, dashboardStats: guardedStats);
      expect(find.text('Private articles'), findsNothing);
      expect(dataSource.aggregateCalls, hasLength(2));

      canReadPrivate = true;
      await pumpDashboard(tester, dashboardStats: guardedStats);
      expect(find.text('Private articles'), findsOneWidget);
      expect(
        dataSource.aggregateCalls.map((spec) => spec.table),
        ['articles', 'private_articles', 'private_articles'],
        reason:
            'Restored access fetches afresh; visible cards keep their state.',
      );
    },
  );

  testWidgets('a bar chart renders from mapped records', (tester) async {
    await pumpDashboard(tester, charts: charts(BeakChartType.bar));

    expect(find.text('Prices'), findsOneWidget);
    final OiBarChart chart = tester.widget(find.byType(OiBarChart));
    expect(chart.categories, hasLength(2));
    expect(chart.categories.first.label, 'One');
    expect(chart.categories.first.values, [10.0]);
  });

  testWidgets('line, pie and area charts render their families', (
    tester,
  ) async {
    await pumpDashboard(tester, charts: charts(BeakChartType.line));
    final OiLineChart line = tester.widget(find.byType(OiLineChart));
    expect(line.series.single.points, hasLength(2));
    expect(line.series.single.points.last.y, 30.0);

    await pumpDashboard(tester, charts: charts(BeakChartType.pie));
    final OiPieChart pie = tester.widget(find.byType(OiPieChart));
    expect(pie.segments, hasLength(2));

    await pumpDashboard(tester, charts: charts(BeakChartType.area));
    expect(find.byType(OiAreaChart<BeakChartPoint>), findsOneWidget);
  });

  testWidgets('renders no Material or Cupertino widgets', (tester) async {
    await pumpDashboard(tester, charts: charts(BeakChartType.bar));

    const banned = {
      'Material',
      'Scaffold',
      'AppBar',
      'ElevatedButton',
      'TextField',
      'CupertinoApp',
      'CupertinoPageScaffold',
      'MaterialApp',
    };
    final offenders = tester.allWidgets
        .where((widget) => banned.contains(widget.runtimeType.toString()))
        .toList();
    expect(offenders, isEmpty, reason: 'obers_ui only — no Material');
  });
}
