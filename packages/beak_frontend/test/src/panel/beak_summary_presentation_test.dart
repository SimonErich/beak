import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';
import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: NoteModel(),
  column: BeakStringColumn(key: 'title', label: 'Title'),
);

const ready = BeakSummaryMeasure.count('ready');
const waiting = BeakSummaryMeasure.count('waiting');

void main() {
  testWidgets(
    'conditional donut and accessible table share one authoritative result',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _SummarySource();
      await tester.pumpWidget(
        BeakPanel(
          dataSource: source,
          theme: OiThemeData.light().copyWith(
            components: const OiComponentThemes(
              chart: OiChartThemeData(
                legend: OiChartLegendTheme(
                  labelStyle: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                  labelColor: Color(0xFF884422),
                ),
              ),
            ),
          ),
          resources: [
            BeakResource(
              model: const NoteModel(),
              screens: [
                BeakTableScreen(
                  definition: BeakListDefinition(
                    header: BeakSummaryBlock(
                      title: 'Population',
                      showTableToggle: true,
                      query: const NoteModel().summary(
                        measures: [ready, waiting],
                      ),
                      values: const [
                        BeakSummaryValue(measure: ready, label: 'Ready'),
                        BeakSummaryValue(measure: waiting, label: 'Waiting'),
                      ],
                      centerLabel: 'records',
                      presentation: BeakSummaryPresentation.donut,
                    ),
                    columns: [BeakTableColumn.field(_title)],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes');
      await tester.pumpAndSettle();
      final chart = tester.widget<OiDonutChart>(find.byType(OiDonutChart));
      expect(chart.segments.map((s) => s.value), [4, 2]);
      expect(find.text('6'), findsOneWidget);
      final legendLabel = tester.widget<Text>(find.text('Ready'));
      expect(legendLabel.style?.fontSize, 17);
      expect(legendLabel.style?.fontWeight, FontWeight.w500);
      expect(legendLabel.style?.color, const Color(0xFF884422));
      final calls = source.calls;
      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Table view'));
      await tester.pumpAndSettle();
      expect(find.byType(OiDonutChart), findsNothing);
      expect(find.text('Ready: 4'), findsOneWidget);
      expect(find.text('Waiting: 2'), findsOneWidget);
      expect(source.calls, calls);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('capacity compares the used and total measures by object', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        dataSource: _SummarySource(values: const {'booked': 3, 'capacity': 10}),
        resources: [
          BeakResource(
            model: const NoteModel(),
            screens: [
              BeakTableScreen(
                definition: BeakListDefinition(
                  header: BeakSummaryBlock(
                    title: 'Slots',
                    presentation: BeakSummaryPresentation.capacity,
                    scope: BeakSummaryScope.standalone,
                    query: const NoteModel().summary(
                      groupBy: _title,
                      measures: [_booked, _capacity],
                    ),
                    values: const [
                      BeakSummaryValue(measure: _booked, label: 'Booked'),
                      BeakSummaryValue(measure: _capacity, label: 'Capacity'),
                    ],
                    capacity: const BeakSummaryCapacity(
                      used: _booked,
                      total: _capacity,
                    ),
                  ),
                  columns: [BeakTableColumn.field(_title)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OiAppShell))).go('/notes');
    await tester.pumpAndSettle();
    final indicator = tester.widget<OiCapacityIndicator>(
      find.byType(OiCapacityIndicator),
    );
    expect(indicator.value, 3);
    expect(indicator.max, 10);
    expect(tester.takeException(), isNull);
  });
}

const _booked = BeakSummaryMeasure.count('booked');
const _capacity = BeakSummaryMeasure.count('capacity');

final class _SummarySource extends FakeDataSource
    implements BeakSummaryDataSource {
  _SummarySource({this.values = const {'ready': 4, 'waiting': 2}})
    : super(
        records: {
          'notes': {
            'a': BeakRecord.fromRow({'id': 'a', 'title': 'One page'}),
          },
        },
      );
  final Map<String, num> values;
  int calls = 0;
  @override
  Future<BeakSummaryResult> summary(BeakSummarySpec spec) async {
    calls++;
    return BeakSummaryResult(
      rows: [BeakSummaryRow(group: const BeakStringValue('a'), values: values)],
    );
  }
}
