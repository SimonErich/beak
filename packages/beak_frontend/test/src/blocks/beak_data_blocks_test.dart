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

  group('BeakKpiBlock', () {
    testWidgets('fetches value and prior period into an OiKpiCard', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakKpiBlock(
          title: 'Revenue',
          value: BeakAggregateSpec.count(table: 'notes'),
          previous: BeakAggregateSpec.count(table: 'notes_prior'),
          format: BeakKpiFormat.currency,
        ),
      );

      expect(find.byType(OiKpiCard), findsOneWidget);
      final card = tester.widget<OiKpiCard>(find.byType(OiKpiCard));
      expect(card.metric.value, 200);
      expect(card.metric.previousValue, 160);
      expect(card.showDelta, isTrue);
    });

    testWidgets('hides the delta without a prior period', (tester) async {
      await pump(
        tester,
        const BeakKpiBlock(
          title: 'Orders',
          value: BeakAggregateSpec.count(table: 'notes'),
        ),
      );

      final card = tester.widget<OiKpiCard>(find.byType(OiKpiCard));
      expect(card.showDelta, isFalse);
    });
  });

  group('BeakChartBlock', () {
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
  });

  group('BeakMetricBlock', () {
    testWidgets('renders the aggregate through a stat card', (tester) async {
      await pump(
        tester,
        const BeakMetricBlock(
          label: 'Notes',
          aggregate: BeakAggregateSpec.count(table: 'notes'),
        ),
      );

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
    });
  });

  group('BeakTableBlock', () {
    testWidgets('binds the model into a bounded data table', (tester) async {
      await pump(
        tester,
        const BeakTableBlock(title: 'All notes', model: NoteModel()),
      );

      final table = tester.widget<BeakDataTable>(find.byType(BeakDataTable));
      expect(table.model.table, 'notes');
      expect(find.text('All notes'), findsWidgets);
      expect(find.text('Alpha'), findsWidgets);
    });
  });
}
