import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';

import '../../support/panel_fixtures.dart';

/// A model whose rows carry every field the advanced charts and the tile map
/// read.
final class _PointModel extends BeakModel {
  const _PointModel();

  @override
  String get table => 'points';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'label', label: 'Label'),
  ];
}

void main() {
  BeakRecord row(Map<String, Object?> values) => BeakRecord.fromRow(values);

  double number(BeakRecord record, String key) => switch (record[key]?.raw) {
    final num value => value.toDouble(),
    final Object? other => fail('"$key" is not numeric: $other'),
  };

  setUp(() {
    final dataSource = FakeDataSource(
      records: {
        'points': {
          'p1': row(const {
            'id': 'p1',
            'label': 'A',
            'x': 1.0,
            'y': 2.0,
            'size': 5.0,
            'open': 10.0,
            'high': 14.0,
            'low': 9.0,
            'close': 12.0,
            'day': 'Mon',
            'week': 'W1',
            'v': 3.0,
            'lat': 48.2,
            'lng': 16.37,
          }),
          'p2': row(const {
            'id': 'p2',
            'label': 'B',
            'x': 3.0,
            'y': 1.0,
            'size': 9.0,
            'open': 12.0,
            'high': 16.0,
            'low': 11.0,
            'close': 15.0,
            'day': 'Tue',
            'week': 'W1',
            'v': 7.0,
            'lat': 40.7,
            'lng': -74.0,
          }),
        },
      },
    );
    registerBeakDependencies(
      config: const BeakPanelConfig(
        title: 'Demo',
        apiBaseUrl: 'http://localhost',
        resources: [
          BeakResource(model: _PointModel(), icon: BeakIconToken(OiIcons.file)),
        ],
      ),
      dataSource: dataSource,
    );
  });

  Future<void> pump(WidgetTester tester, BeakBlock block) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakBlockHost(block: block),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('bubble block maps rows to OiBubbleChart', (tester) async {
    await pump(
      tester,
      BeakBubbleChartBlock(
        title: 'Scatter',
        query: const BeakQuerySpec(table: 'points'),
        map: (records) => [
          for (final r in records)
            BeakBubblePoint(
              x: number(r, 'x'),
              y: number(r, 'y'),
              size: number(r, 'size'),
              label: r['label']?.raw?.toString(),
            ),
        ],
      ),
    );

    final chart = tester.widget<OiBubbleChart>(find.byType(OiBubbleChart));
    expect(chart.data.series.single.points, hasLength(2));
    tester.takeException();
  });

  testWidgets('candlestick block maps rows to OiCandlestickChart', (
    tester,
  ) async {
    await pump(
      tester,
      BeakCandlestickChartBlock(
        title: 'Price',
        query: const BeakQuerySpec(table: 'points'),
        map: (records) => [
          for (final (i, r) in records.indexed)
            BeakCandle(
              x: i.toDouble(),
              open: number(r, 'open'),
              high: number(r, 'high'),
              low: number(r, 'low'),
              close: number(r, 'close'),
            ),
        ],
      ),
    );

    final chart = tester.widget<OiCandlestickChart<BeakCandle>>(
      find.byType(OiCandlestickChart<BeakCandle>),
    );
    expect(chart.series.single.data, hasLength(2));
    tester.takeException();
  });

  testWidgets('heatmap block resolves string keys to indexed cells', (
    tester,
  ) async {
    await pump(
      tester,
      BeakHeatmapChartBlock(
        title: 'Activity',
        query: const BeakQuerySpec(table: 'points'),
        map: (records) => [
          for (final r in records)
            BeakMatrixCell(
              row: r['day']?.raw?.toString() ?? '',
              column: r['week']?.raw?.toString() ?? '',
              value: number(r, 'v'),
            ),
        ],
      ),
    );

    final heatmap = tester.widget<OiHeatmap>(find.byType(OiHeatmap));
    expect(heatmap.rowLabels, ['Mon', 'Tue']);
    expect(heatmap.columnLabels, ['W1']);
    expect(heatmap.cells, hasLength(2));
    tester.takeException();
  });

  testWidgets('tile map block pins rows with coordinates', (tester) async {
    await pump(
      tester,
      const BeakTileMapBlock(
        title: 'Offices',
        query: BeakQuerySpec(table: 'points'),
        latitudeField: BeakDecimalColumn(key: 'lat', label: 'Lat'),
        longitudeField: BeakDecimalColumn(key: 'lng', label: 'Lng'),
        labelField: BeakStringColumn(key: 'label', label: 'Label'),
      ),
    );

    final map = tester.widget<OiTileMap>(find.byType(OiTileMap));
    expect(map.markers, hasLength(2));
    expect(map.markers.first.latitude, 48.2);
    tester.takeException();
  });
}
