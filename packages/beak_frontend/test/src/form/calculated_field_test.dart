import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

final class _OrderModel extends BeakModel {
  const _OrderModel();

  @override
  String get table => 'orders';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [_id, _total, _deliveryDate, _note];
}

const _id = BeakStringColumn(key: 'id', label: 'Id');
const _total = BeakIntColumn(
  key: 'totalInCents',
  label: 'Total',
  translations: {'de': 'Gesamtbetrag'},
  semantic: BeakSemantic.money(currency: 'EUR'),
);
const _deliveryDate = BeakDateTimeColumn(
  key: 'deliveryDate',
  label: 'Delivery date',
  format: BeakDateFormat.dateOnly,
);
const _note = BeakStringColumn(key: 'note', label: 'Note');

BeakScalarField<Object> _field(BeakColumn column) =>
    BeakScalarField<Object>(model: const _OrderModel(), column: column);

Future<BeakFormReader> _reader(BeakFormNode node) async {
  final session = BeakFormSession(
    model: const _OrderModel(),
    dataSource: FakeDataSource(
      models: const [_OrderModel()],
      records: {
        'orders': {
          'o1': BeakRecord.fromRow({'id': 'o1', 'totalInCents': 1599}),
        },
      },
    ),
    recordId: 'o1',
    layout: BeakFormLayout(children: [node]),
  );
  addTearDown(session.dispose);
  await session.load();
  return BeakFormReader(session.root);
}

void main() {
  tearDown(() => BeakLabels.language = null);

  test('an integer money field reads as a currency amount', () async {
    final node = BeakCalculated.field(_field(_total));
    final reader = await _reader(node);

    expect(node.format, BeakValueFormat.currency);
    expect('${node.value(reader)}', '15.99');
    expect(node.dependencies.single.key, 'totalInCents');
  });

  test('the label follows the field and the panel language', () async {
    final node = BeakCalculated.field(_field(_total));
    final reader = await _reader(node);

    expect(node.labelBuilder!(reader), 'Total');
    BeakLabels.language = 'de';
    expect(node.labelBuilder!(reader), 'Gesamtbetrag');
  });

  test('dates and text pick their own format; a given label wins', () {
    expect(
      BeakCalculated.field(_field(_deliveryDate)).format,
      BeakValueFormat.date,
    );
    final note = BeakCalculated.field(_field(_note), label: 'Remark');
    expect(note.format, BeakValueFormat.text);
    expect(note.label, 'Remark');
    expect(note.labelBuilder, isNull);
  });
}
