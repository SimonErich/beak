import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

abstract final class _ProductColumns {
  static const id = BeakStringColumn(key: 'id', label: 'Id');
  static const name = BeakStringColumn(key: 'name', label: 'Name');
  static const price = BeakDecimalColumn(key: 'price', label: 'Price');
  static const List<BeakColumn> values = [id, name, price];
}

final class _ProductModel extends BeakModel {
  const _ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => _ProductColumns.values;
}

void main() {
  const model = _ProductModel();
  final published = BeakFieldFilter(
    column: _ProductColumns.name,
    operator: BeakOperator.eq,
    value: const BeakStringValue('x'),
  );

  group('BeakTableRef', () {
    test('carries the physical name across the wire', () {
      expect(const BeakTableRef.raw('products').name, 'products');
      expect(const BeakTableRef.raw('products').toString(), 'products');
    });

    test('compares by value, so a registry can key a map on it', () {
      expect(
        const BeakTableRef.raw('products'),
        const BeakTableRef.raw('products'),
      );
      expect(
        const BeakTableRef.raw('products').hashCode,
        const BeakTableRef.raw('products').hashCode,
      );
      expect(
        const BeakTableRef.raw('products'),
        isNot(const BeakTableRef.raw('users')),
      );
      expect(const BeakTableRef.raw('products'), isNot('products'));
    });
  });

  group('BeakModel.ref', () {
    test('derives from the model, so it cannot disagree with it', () {
      expect(model.ref, const BeakTableRef.raw('products'));
      expect(model.ref.name, model.table);
    });
  });

  group('BeakModel.query', () {
    test('targets the model table with no string written', () {
      expect(model.query().table, 'products');
    });

    test('forwards every BeakQuerySpec parameter', () {
      final spec = model.query(
        filter: published,
        sorts: [BeakSort(_ProductColumns.price.key, descending: true)],
        search: const BeakSearch('lamp', ['name']),
        relationLoads: const [BeakRelationLoad('category')],
        pagination: const BeakPagination(page: 2, perPage: 10),
        withTrashed: true,
      );
      expect(spec.filter, published);
      expect(spec.sorts.single.columnKey, 'price');
      expect(spec.sorts.single.descending, isTrue);
      expect(spec.search?.term, 'lamp');
      expect(spec.relationLoads.single.relationKey, 'category');
      expect(spec.pagination.page, 2);
      expect(spec.pagination.perPage, 10);
      expect(spec.withTrashed, isTrue);
    });

    test('serializes identically to a hand-written spec', () {
      // The whole point: typed authoring, byte-identical wire format.
      expect(
        model.query().toJson(),
        const BeakQuerySpec(table: 'products').toJson(),
      );
    });

    test('composes with the copy-builders', () {
      final spec = model
          .query()
          .orderBy(_ProductColumns.price, descending: true)
          .paginate(perPage: 5);
      expect(spec.table, 'products');
      expect(spec.sorts.single.columnKey, 'price');
      expect(spec.pagination.perPage, 5);
    });
  });

  group('BeakModel aggregates', () {
    test('count targets the model table', () {
      final spec = model.count();
      expect(spec.table, 'products');
      expect(spec.function, BeakAggregateFunction.count);
      expect(spec.columnKey, isNull);
    });

    test('count forwards filter and withTrashed', () {
      final spec = model.count(filter: published, withTrashed: true);
      expect(spec.filter, published);
      expect(spec.withTrashed, isTrue);
    });

    test('sum names the column without a key string', () {
      final spec = model.sum(_ProductColumns.price);
      expect(spec.table, 'products');
      expect(spec.function, BeakAggregateFunction.sum);
      expect(spec.columnKey, 'price');
    });

    test('sum forwards filter and withTrashed', () {
      final spec = model.sum(
        _ProductColumns.price,
        filter: published,
        withTrashed: true,
      );
      expect(spec.filter, published);
      expect(spec.withTrashed, isTrue);
    });

    test('avg names the column without a key string', () {
      final spec = model.avg(_ProductColumns.price);
      expect(spec.function, BeakAggregateFunction.avg);
      expect(spec.columnKey, 'price');
    });

    test('avg forwards filter and withTrashed', () {
      final spec = model.avg(
        _ProductColumns.price,
        filter: published,
        withTrashed: true,
      );
      expect(spec.filter, published);
      expect(spec.withTrashed, isTrue);
    });

    test('serialize identically to the hand-written constructors', () {
      expect(
        model.count().toJson(),
        const BeakAggregateSpec.count(table: 'products').toJson(),
      );
      expect(
        model.sum(_ProductColumns.price).toJson(),
        BeakAggregateSpec.sum(
          table: 'products',
          column: _ProductColumns.price,
        ).toJson(),
      );
    });
  });
}
