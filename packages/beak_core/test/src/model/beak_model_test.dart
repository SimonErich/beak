import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// Columns of the sample product model, namespaced per Beak convention.
abstract final class _ProductColumns {
  static const BeakIntColumn id = BeakIntColumn(key: 'id', label: 'ID');
  static const BeakStringColumn name = BeakStringColumn(
    key: 'name',
    label: 'Name',
  );
  static const BeakDecimalColumn price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
  );
  static const List<BeakColumn> values = [id, name, price];
}

const BeakBelongsTo _category = BeakBelongsTo(
  key: 'category',
  label: 'Category',
  relatedTable: 'categories',
  displayColumnKey: 'name',
  foreignKey: 'category_id',
);

const BeakBelongsToMany _tags = BeakBelongsToMany(
  key: 'tags',
  label: 'Tags',
  relatedTable: 'tags',
  displayColumnKey: 'name',
  pivotTable: 'product_tag',
  foreignPivotKey: 'product_id',
  relatedPivotKey: 'tag_id',
);

/// The metadata Beak's docs use as the canonical example.
final class _ProductModel extends BeakModel {
  const _ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => _ProductColumns.values;

  @override
  List<BeakRelationship> get relationships => const [_category, _tags];

  @override
  bool get softDeletes => true;
}

/// A model without an `id` column and without a `primaryKey` override.
final class _KeylessModel extends BeakModel {
  const _KeylessModel();

  @override
  String get table => 'keyless';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [_ProductColumns.name];
}

/// A model overriding [BeakModel.primaryKey] with a non-`id` column.
final class _CustomKeyModel extends BeakModel {
  const _CustomKeyModel();

  @override
  String get table => 'custom_keys';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [_ProductColumns.name];

  @override
  BeakColumn get primaryKey => _ProductColumns.name;
}

void main() {
  const model = _ProductModel();

  test('exposes its declared metadata', () {
    expect(model.table, 'products');
    expect(model.displayColumnKey, 'name');
    expect(model.columns, _ProductColumns.values);
    expect(model.relationships, const [_category, _tags]);
    expect(model.softDeletes, isTrue);
  });

  test('defaults to no relationships and hard deletes', () {
    const keyless = _KeylessModel();
    expect(keyless.relationships, isEmpty);
    expect(keyless.softDeletes, isFalse);
  });

  test('columnByKey returns the first matching column, else null', () {
    expect(model.columnByKey('price'), same(_ProductColumns.price));
    expect(model.columnByKey('missing'), isNull);
  });

  test('relationshipByKey returns the first matching relationship, else '
      'null', () {
    expect(model.relationshipByKey('tags'), same(_tags));
    expect(model.relationshipByKey('missing'), isNull);
  });

  test('primaryKey resolves the id column by default', () {
    expect(model.primaryKey, same(_ProductColumns.id));
  });

  test('primaryKey throws BeakConfigurationException when no id column '
      'exists', () {
    expect(
      () => const _KeylessModel().primaryKey,
      throwsA(
        isA<BeakConfigurationException>().having(
          (exception) => exception.message,
          'message',
          contains('keyless'),
        ),
      ),
    );
  });

  test('primaryKey can be overridden with a non-id column', () {
    expect(const _CustomKeyModel().primaryKey, same(_ProductColumns.name));
  });
}
