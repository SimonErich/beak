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
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakDashboard(
          stats: stats,
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
