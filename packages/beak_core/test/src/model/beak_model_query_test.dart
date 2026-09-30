import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

abstract final class _ProductColumns {
  static const id = BeakStringColumn(key: 'id', label: 'Id');
  static const name = BeakStringColumn(key: 'name', label: 'Name');
  static const price = BeakDecimalColumn(key: 'price', label: 'Price');
  static const cost = BeakIntColumn(
    key: 'cost',
    label: 'Cost',
    semantic: BeakSemantic.money(currency: 'EUR'),
  );
  static const List<BeakColumn> values = [id, name, price, cost];
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

final class _OtherModel extends BeakModel {
  const _OtherModel();

  @override
  String get table => 'others';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => _ProductColumns.values;
}

void main() {
  const model = _ProductModel();
  const price = BeakScalarField<double>(
    model: model,
    column: _ProductColumns.price,
  );
  const published = BeakFieldFilter(
    column: _ProductColumns.name,
    operator: BeakOperator.eq,
    value: BeakStringValue('x'),
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
          .orderBy(price, descending: true)
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
      final spec = model.sum(price);
      expect(spec.table, 'products');
      expect(spec.function, BeakAggregateFunction.sum);
      expect(spec.columnKey, 'price');
    });

    test('sum forwards filter and withTrashed', () {
      final spec = model.sum(price, filter: published, withTrashed: true);
      expect(spec.filter, published);
      expect(spec.withTrashed, isTrue);
    });

    test('avg names the column without a key string', () {
      final spec = model.avg(price);
      expect(spec.function, BeakAggregateFunction.avg);
      expect(spec.columnKey, 'price');
    });

    test('avg forwards filter and withTrashed', () {
      final spec = model.avg(price, filter: published, withTrashed: true);
      expect(spec.filter, published);
      expect(spec.withTrashed, isTrue);
    });

    test('sum and avg accept only the model\'s own fields', () {
      const foreign = BeakScalarField<double>(
        model: _OtherModel(),
        column: _ProductColumns.price,
      );
      const related = BeakScalarField<double>(
        model: model,
        column: _ProductColumns.price,
        path: [
          BeakBelongsTo(
            key: 'category',
            label: 'Category',
            relatedTable: 'categories',
            displayColumnKey: 'name',
            foreignKey: 'category_id',
          ),
        ],
      );
      for (final field in [foreign, related]) {
        expect(
          () => model.sum(field),
          throwsA(isA<BeakConfigurationException>()),
        );
        expect(
          () => model.avg(field),
          throwsA(isA<BeakConfigurationException>()),
        );
        expect(
          () => model.summary(
            groupBy: field,
            measures: [const BeakSummaryMeasure.count('n')],
          ),
          throwsA(isA<BeakConfigurationException>()),
        );
      }
    });

    group('exact decimals', () {
      const cost = BeakScalarField<BeakDecimal>(
        model: model,
        column: _ProductColumns.cost,
      );

      test('sumDecimal and avgDecimal name the money column', () {
        final sum = model.sumDecimal(cost, filter: published);
        expect(sum.function, BeakAggregateFunction.sum);
        expect(sum.columnKey, 'cost');
        expect(sum.filter, published);
        final avg = model.avgDecimal(cost, withTrashed: true);
        expect(avg.function, BeakAggregateFunction.avg);
        expect(avg.columnKey, 'cost');
        expect(avg.withTrashed, isTrue);
      });

      test('put the same request on the wire as the numeric builders', () {
        const numeric = BeakScalarField<int>(
          model: model,
          column: _ProductColumns.cost,
        );
        expect(model.sumDecimal(cost).toJson(), model.sum(numeric).toJson());
        expect(model.avgDecimal(cost).toJson(), model.avg(numeric).toJson());
      });

      test('accept only the model\'s own exact-decimal fields', () {
        const foreign = BeakScalarField<BeakDecimal>(
          model: _OtherModel(),
          column: _ProductColumns.cost,
        );
        const notDecimal = BeakScalarField<BeakDecimal>(
          model: model,
          column: _ProductColumns.name,
        );
        for (final field in [foreign, notDecimal]) {
          expect(
            () => model.sumDecimal(field),
            throwsA(isA<BeakConfigurationException>()),
          );
          expect(
            () => model.avgDecimal(field),
            throwsA(isA<BeakConfigurationException>()),
          );
        }
      });
    });

    test('serialize identically to the hand-written constructors', () {
      expect(
        model.count().toJson(),
        const BeakAggregateSpec.count(table: 'products').toJson(),
      );
      expect(
        model.sum(price).toJson(),
        const BeakAggregateSpec.sum(
          table: 'products',
          column: _ProductColumns.price,
        ).toJson(),
      );
    });
  });
}
