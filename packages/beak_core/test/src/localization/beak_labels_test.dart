import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

enum _Status { open, closed }

const _email = BeakStringColumn(
  key: 'email',
  label: 'Email',
  translations: {'de': 'E-Mail', 'en': 'Email address'},
  hints: {'de': 'Adresse der Bestätigung'},
);

const _status = BeakEnumColumn<_Status>(
  key: 'status',
  label: 'Status',
  values: _Status.values,
  valueTranslations: {
    'de': {_Status.open: 'Offen'},
  },
  labels: {_Status.closed: 'Closed for good'},
);

const _items = BeakHasMany(
  key: 'items',
  label: 'Items',
  translations: {'de': 'Positionen'},
  relatedTable: 'order_items',
  displayColumnKey: 'name',
  foreignKey: 'orderId',
);

const _cancel = BeakModelAction(
  name: 'cancel',
  label: 'Cancel',
  description: 'Stops the order.',
);

final class _OrderModel extends BeakModel {
  const _OrderModel();

  @override
  String get table => 'placed_orders';

  @override
  String get displayColumnKey => 'email';

  @override
  List<BeakColumn> get columns => const [_email, _status];

  @override
  BeakModelLabels get labels => const BeakModelLabels(
    one: {'de': 'Bestellung', 'en': 'Order'},
    other: {'de': 'Bestellungen', 'en': 'Orders'},
    actions: {
      'cancel': {'de': 'Stornieren'},
    },
    actionDescriptions: {
      'cancel': {'de': 'Die Bestellung wird storniert.'},
    },
  );
}

final class _PlainModel extends BeakModel {
  const _PlainModel();

  @override
  String get table => 'tax_rates';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [];
}

void main() {
  tearDown(() => BeakLabels.language = null);

  group('BeakLabels.pick', () {
    test('returns the entry of the current language', () {
      BeakLabels.language = 'de';
      expect(BeakLabels.pick(const {'de': 'Ja'}, 'Yes'), 'Ja');
    });

    test('falls back without a language or an entry', () {
      expect(BeakLabels.pick(const {'de': 'Ja'}, 'Yes'), 'Yes');
      BeakLabels.language = 'fr';
      expect(BeakLabels.pick(const {'de': 'Ja'}, 'Yes'), 'Yes');
    });
  });

  group('columns', () {
    test('label and hint follow the language', () {
      expect(_email.label, 'Email');
      expect(_email.hint, isNull);
      BeakLabels.language = 'de';
      expect(_email.label, 'E-Mail');
      expect(_email.hint, 'Adresse der Bestätigung');
      BeakLabels.language = 'en';
      expect(_email.label, 'Email address');
      expect(_email.hint, isNull);
    });

    test('enum values: translations, then labels, then the name', () {
      BeakLabels.language = 'de';
      expect(_status.labelFor(_Status.open), 'Offen');
      expect(_status.labelFor(_Status.closed), 'Closed for good');
      BeakLabels.language = 'en';
      expect(_status.labelFor(_Status.open), 'open');
    });
  });

  test('relationship label follows the language', () {
    expect(_items.label, 'Items');
    BeakLabels.language = 'de';
    expect(_items.label, 'Positionen');
  });

  group('model labels', () {
    test('singular, plural and command labels follow the language', () {
      const model = _OrderModel();
      BeakLabels.language = 'de';
      expect(model.singularLabel, 'Bestellung');
      expect(model.pluralLabel, 'Bestellungen');
      expect(model.actionLabelOf(_cancel), 'Stornieren');
      expect(
        model.actionDescriptionOf(_cancel),
        'Die Bestellung wird storniert.',
      );
      BeakLabels.language = 'en';
      expect(model.pluralLabel, 'Orders');
      expect(model.actionLabelOf(_cancel), 'Cancel');
      expect(model.actionDescriptionOf(_cancel), 'Stops the order.');
    });

    test('a model without labels is named after its table', () {
      const model = _PlainModel();
      expect(model.singularLabel, 'Tax Rates');
      expect(model.pluralLabel, 'Tax Rates');
    });
  });
}
