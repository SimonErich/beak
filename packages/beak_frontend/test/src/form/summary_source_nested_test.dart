import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _lines = BeakToManyField(
  model: _Parent(),
  relation: _Parent.lines,
  target: _Line(),
);
const _extras = BeakToManyField(
  model: _Line(),
  relation: _Line.extras,
  target: _Extra(),
);
const _price = BeakScalarField<int>(model: _Line(), column: _Line.price);
const _extraPrice = BeakScalarField<int>(model: _Extra(), column: _Extra.price);

void main() {
  testWidgets('hidden form nodes reserve no spacing and return reactively', (
    tester,
  ) async {
    late BeakFormSession session;
    const toggle = BeakScalarField<String>(
      model: NoteModel(),
      column: BeakStringColumn(key: 'title', label: 'Title'),
    );
    BeakFormWidget block(String text, {BeakVisibility? visibleIf}) =>
        BeakFormWidget(
          visibleIf: visibleIf,
          builder: (_, _) => SizedBox(height: 20, child: Text(text)),
        );
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const NoteModel(),
          dataSource: FakeDataSource(),
          onSession: (value) => session = value,
          layout: BeakFormLayout(
            children: [
              toggle.inputText(),
              block('Before'),
              block(
                'Conditional',
                visibleIf: (state) => state.read(toggle) == 'show',
              ),
              block('After'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('After')).dy -
          tester.getTopLeft(find.text('Before')).dy,
      36,
    );
    session.root.set(toggle, 'show');
    await tester.pumpAndSettle();
    expect(find.text('Conditional'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('After')).dy -
          tester.getTopLeft(find.text('Before')).dy,
      72,
    );
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['summary', 'editor', 'nestedEditor']) {
    final editable = mode != 'summary';
    test('summary nested rows retain loaded extras with $mode', () async {
      final summary = BeakFormSummary(
        source: _lines,
        lines: [
          BeakSummaryLine(
            label: 'Total',
            dependencies: [_price, _extras],
            value: (state) =>
                (state.read(_price) ?? 0) +
                state
                    .rows(_extras)
                    .fold<int>(
                      0,
                      (total, extra) => total + (extra.read(_extraPrice) ?? 0),
                    ),
          ),
        ],
      );
      final source = FakeDataSource(
        models: const [_Parent(), _Line(), _Extra()],
        records: {
          'summary_orders': {
            'o1': BeakRecord.fromRow({'id': 'o1'}),
          },
          'summary_lines': {
            'l1': BeakRecord.fromRow({
              'id': 'l1',
              'order_id': 'o1',
              'price': 100,
            }),
          },
          'summary_extras': {
            'e1': BeakRecord.fromRow({
              'id': 'e1',
              'line_id': 'l1',
              'price': 25,
            }),
          },
        },
      );
      final session = BeakFormSession(
        model: const _Parent(),
        dataSource: source,
        recordId: 'o1',
        layout: BeakFormLayout(
          children: [
            BeakFormSummary(
              source: _lines,
              lines: [
                BeakSummaryLine(
                  label: 'Base',
                  dependencies: [_price],
                  value: (state) => state.read(_price),
                ),
              ],
            ),
            summary,
            if (editable)
              _lines.tableForm(
                children: [
                  _price.inputNumber(),
                  if (mode == 'nestedEditor')
                    _extras.tableForm(children: [_extraPrice.inputNumber()]),
                ],
              ),
          ],
        ),
      );
      addTearDown(session.dispose);
      await session.load();
      final child = session.root.rows(_lines).single;
      expect(child.snapshot.relations['extras']?.length, 1);
      expect(summary.lines.single.value(BeakFormReader(child)), 125);
      if (mode == 'nestedEditor') {
        child.rows(_extras).single.set(_extraPrice, 50);
        expect(summary.lines.single.value(BeakFormReader(child)), 150);
      }
      expect((await session.save())?.complete, isTrue);
      expect(source.createCalls, isEmpty);
      expect(source.deleteCalls, isEmpty);
      expect(
        source.updateCalls.where((call) => call.$1 == 'summary_extras').length,
        mode == 'nestedEditor' ? 1 : 0,
      );
      if (!editable) expect(source.updateCalls, isEmpty);
    });
  }

  test(
    'repeated summaries do not duplicate new rows when a draft resumes',
    () async {
      final drafts = BeakFormDrafts(
        store: BeakMemoryDraftStore(),
        key: 'summary',
        context: 'test',
        debounce: const Duration(hours: 1),
      );
      final summary = BeakFormSummary(
        source: _lines,
        lines: [
          BeakSummaryLine(
            label: 'Price',
            dependencies: [_price, _extras],
            value: (state) => state.read(_price),
          ),
        ],
      );
      final source = FakeDataSource(
        models: const [_Parent(), _Line(), _Extra()],
        records: {
          'summary_orders': {
            'o1': BeakRecord.fromRow({'id': 'o1'}),
          },
        },
      );
      BeakFormSession make() => BeakFormSession(
        model: const _Parent(),
        dataSource: source,
        recordId: 'o1',
        drafts: drafts,
        layout: BeakFormLayout(
          children: [
            summary,
            summary,
            _lines.tableForm(
              children: [
                _price.inputNumber(),
                _extras.tableForm(children: [_extraPrice.inputNumber()]),
              ],
            ),
          ],
        ),
      );
      final first = make();
      addTearDown(first.dispose);
      await first.load();
      final line = first.root.addRow(
        _lines,
        values: BeakRecord.fromRow({'price': 100}),
      );
      line.addRow(_extras, values: BeakRecord.fromRow({'price': 25}));
      expect(await first.persistDraft(), isTrue);
      final resumed = make();
      addTearDown(resumed.dispose);
      await resumed.load();
      resumed.resumeDraft();
      expect(resumed.root.rows(_lines).length, 1);
      expect(resumed.root.rows(_lines).single.rows(_extras).length, 1);
      expect((await resumed.save())?.complete, isTrue);
      expect(
        source.createCalls.where((call) => call.$1 == 'summary_lines').length,
        1,
      );
      expect(
        source.createCalls.where((call) => call.$1 == 'summary_extras').length,
        1,
      );
    },
  );

  for (final denyParent in [true, false]) {
    testWidgets(
      'summary respects ${denyParent ? 'source' : 'row'} read capabilities',
      (tester) async {
        var evaluations = 0;
        await tester.pumpWidget(
          OiApp(
            theme: OiThemeData.light(),
            home: BeakConfiguredForm(
              model: const _Parent(),
              dataSource: _RestrictedSource(denyParent),
              recordId: 'o1',
              mode: BeakFormMode.read,
              layout: BeakFormLayout(
                children: [
                  BeakFormSummary(
                    source: _lines,
                    lines: [
                      BeakSummaryLine(
                        label: 'Secret amount',
                        dependencies: [_price],
                        labelBuilder: (state, _) {
                          evaluations++;
                          return 'Secret amount';
                        },
                        value: (state) {
                          evaluations++;
                          return state.read(_price);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(evaluations, 0);
        expect(find.text('Secret amount'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final class _RestrictedSource extends FakeDataSource
    implements BeakCapabilityDataSource {
  _RestrictedSource(this.denyParent)
    : super(
        models: const [_Parent(), _Line(), _Extra()],
        records: {
          'summary_orders': {
            'o1': BeakRecord.fromRow({'id': 'o1'}),
          },
          'summary_lines': {
            'l1': BeakRecord.fromRow({
              'id': 'l1',
              'order_id': 'o1',
              'price': 100,
            }),
          },
        },
      );
  final bool denyParent;
  @override
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async =>
      (denyParent ? table == 'summary_orders' : table == 'summary_lines')
      ? const BeakAccessCapabilities(readableFields: {'id'})
      : const BeakAccessCapabilities();
}

final class _Parent extends BeakModel {
  const _Parent();
  static const lines = BeakHasMany(
    key: 'lines',
    label: 'Lines',
    relatedTable: 'summary_lines',
    foreignKey: 'order_id',
    displayColumnKey: 'id',
    owned: true,
  );
  @override
  String get table => 'summary_orders';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
  ];
  @override
  List<BeakRelationship> get relationships => const [lines];
  @override
  List<BeakModel> get relatedModels => const [_Line()];
}

final class _Line extends BeakModel {
  const _Line();
  static const price = BeakIntColumn(key: 'price', label: 'Price');
  static const extras = BeakHasMany(
    key: 'extras',
    label: 'Extras',
    relatedTable: 'summary_extras',
    foreignKey: 'line_id',
    displayColumnKey: 'id',
    owned: true,
  );
  @override
  String get table => 'summary_lines';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'order_id', label: 'Order'),
    price,
  ];
  @override
  List<BeakRelationship> get relationships => const [extras];
  @override
  List<BeakModel> get relatedModels => const [_Extra()];
}

final class _Extra extends BeakModel {
  const _Extra();
  static const price = BeakIntColumn(key: 'price', label: 'Price');
  @override
  String get table => 'summary_extras';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'line_id', label: 'Line'),
    price,
  ];
}
