import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

enum _Status { draft, confirmed }

const _name = BeakStringColumn(key: 'name', label: 'Name');
const _id = BeakIntColumn(key: 'id', label: 'Id');
const _customer = BeakBelongsTo(
  key: 'customer',
  label: 'Customer',
  relatedTable: 'customers',
  displayColumnKey: 'name',
  foreignKey: 'customer_id',
);

const _group = BeakBelongsTo(
  key: 'group',
  label: 'Group',
  relatedTable: 'groups',
  displayColumnKey: 'name',
  foreignKey: 'group_id',
);

final class _Model extends BeakModel {
  const _Model(this.table);
  @override
  final String table;
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [_id, _name];
}

void main() {
  test('a root scalar field yields the sort for its own storage key', () {
    const field = BeakScalarField<String>(
      model: _Model('orders'),
      column: _name,
    );
    expect(field.ascending(), const BeakSort('name'));
    expect(field.descending(), const BeakSort('name', descending: true));
  });

  test('a field reached through a relationship cannot be sorted', () {
    const field = BeakScalarField<String>(
      model: _Model('orders'),
      column: _name,
      path: [_customer],
    );
    expect(field.ascending, throwsA(isA<BeakConfigurationException>()));
    expect(field.descending, throwsA(isA<BeakConfigurationException>()));
  });

  test('a to-one field loads its related record along its whole path', () {
    const direct = BeakToOneField(
      model: _Model('orders'),
      relation: _customer,
      target: _Model('customers'),
    );
    expect(direct.relationLoad, const BeakRelationLoad('customer'));
    const nested = BeakToOneField(
      model: _Model('orders'),
      relation: _customer,
      target: _Model('customers'),
      path: [_group],
    );
    expect(
      nested.relationLoad,
      const BeakRelationLoad('group', nested: [BeakRelationLoad('customer')]),
    );
  });

  test('typed enum predicates use wire names for equality and inequality', () {
    const field = BeakScalarField<_Status>(
      model: _Model('orders'),
      column: BeakEnumColumn<_Status>(
        key: 'status',
        label: 'Status',
        values: _Status.values,
      ),
    );
    expect(
      field.eq(_Status.confirmed),
      const BeakFieldFilter.forKey(
        'status',
        BeakOperator.eq,
        BeakStringValue('confirmed'),
      ),
    );
    expect(
      field.notEq(_Status.draft),
      const BeakFieldFilter.forKey(
        'status',
        BeakOperator.neq,
        BeakStringValue('draft'),
      ),
    );
    expect(
      field.eq(null),
      const BeakFieldFilter.forKey(
        'status',
        BeakOperator.isNull,
        BeakNullValue(),
      ),
    );
    expect(
      field.notEq(null),
      const BeakFieldFilter.forKey(
        'status',
        BeakOperator.isNotNull,
        BeakNullValue(),
      ),
    );
    expect(
      BeakFilter.fromJson(field.eq(_Status.confirmed).toJson()),
      field.eq(_Status.confirmed),
    );
  });

  test(
    'collection search paths stay rooted and reject foreign target fields',
    () {
      const children = BeakToManyField(
        model: _Model('orders'),
        target: _Model('customers'),
        relation: BeakHasMany(
          key: 'customers',
          label: 'Customers',
          relatedTable: 'customers',
          displayColumnKey: 'name',
          foreignKey: 'order_id',
        ),
      );
      const name = BeakScalarField<String>(
        model: _Model('customers'),
        column: _name,
      );
      final field = children.search(name);
      expect(field.model.table, 'orders');
      expect(field.qualifiedKey, 'customers.name');
      expect(field.column, _name);
      expect(
        () => children.search(
          const BeakScalarField<String>(model: _Model('other'), column: _name),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'option includes merge nested typed paths and retain query constraints',
    () {
      const customer = BeakToOneField(
        model: _Model('orders'),
        relation: _customer,
        target: _Model('customers'),
      );
      const address = BeakToOneField(
        model: _Model('orders'),
        path: [_customer],
        relation: BeakBelongsTo(
          key: 'address',
          label: 'Address',
          relatedTable: 'addresses',
          displayColumnKey: 'name',
          foreignKey: 'address_id',
        ),
        target: _Model('addresses'),
      );
      final filter = const BeakScalarField<String>(
        model: _Model('orders'),
        column: _name,
      ).eq('Open');
      final original = BeakOptionQuery(
        model: const _Model('orders'),
        query: BeakQuerySpec(
          table: 'orders',
          filter: filter,
          sorts: const [BeakSort('name')],
          relationLoads: [BeakRelationLoad('customer', filter: filter)],
          pagination: const BeakPagination(perPage: 8),
        ),
      );
      final included = original.including([customer, address, address]);
      expect(included.query.filter, filter);
      expect(included.query.sorts, original.query.sorts);
      expect(included.query.pagination.perPage, 8);
      expect(included.query.relationLoads, hasLength(1));
      expect(included.query.relationLoads.single.filter, filter);
      expect(
        included.query.relationLoads.single.nested.single.relationKey,
        'address',
      );
      expect(
        () => original.including([
          const BeakToOneField(
            model: _Model('wrong'),
            relation: _customer,
            target: _Model('customers'),
          ),
        ]),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test('typed relationship scopes group predicates on one related record', () {
    const customer = BeakToOneField(
      model: _Model('orders'),
      relation: _customer,
      target: _Model('customers'),
    );
    const orders = BeakToManyField(
      model: _Model('orders'),
      path: [_customer],
      relation: BeakHasMany(
        key: 'orders',
        label: 'Orders',
        relatedTable: 'orders',
        displayColumnKey: 'name',
        foreignKey: 'customer_id',
      ),
      target: _Model('orders'),
    );
    const name = BeakScalarField<String>(
      model: _Model('orders'),
      column: _name,
    );
    final child = BeakAndFilter([name.eq('Express'), name.contains('press')]);
    expect(customer.matches(child), BeakRelationFilter('customer', child));
    expect(
      orders.any(child),
      BeakRelationFilter('customer', BeakRelationFilter('orders', child)),
    );
  });

  test('typed nested references read eager data and preserve query paths', () {
    const field = BeakScalarField<String>(
      model: _Model('orders'),
      column: _name,
      path: [_customer],
    );
    final record = BeakRecord(
      values: const {},
      relations: {
        'customer': [
          BeakRecord.fromRow({'name': 'Ada'}),
        ],
      },
    );
    final String? name = field.readFrom(record);
    expect(name, 'Ada');
    expect(field.readFrom(BeakRecord.fromRow({})), isNull);
    expect(field.eq('Ada').toJson(), {
      'type': 'field',
      'column': 'customer.name',
      'operator': 'eq',
      'value': const BeakStringValue('Ada').toJson(),
    });
  });

  test('scalar predicates retain types, operators and null semantics', () {
    const name = BeakScalarField<String>(
      model: _Model('customers'),
      column: _name,
    );
    const id = BeakScalarField<int>(model: _Model('customers'), column: _id);
    expect(name.label, 'Name');
    expect(name.eq(null).toJson()['operator'], 'isNull');
    expect(name.notEq(null).toJson()['operator'], 'isNotNull');
    expect(name.notEq('Ada').toJson()['operator'], 'neq');
    expect(name.contains('ad').toJson()['operator'], 'contains');
    expect(id.gt(1).toJson()['operator'], 'gt');
    expect(id.gte(1).toJson()['operator'], 'gte');
    expect(id.lt(1).toJson()['operator'], 'lt');
    expect(id.lte(1).toJson()['operator'], 'lte');
    const invalid = BeakScalarField<int>(
      model: _Model('customers'),
      column: _name,
    );
    expect(
      () => invalid.readFrom(BeakRecord.fromRow({'name': 'Ada'})),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  test(
    'relationship descriptors read loaded values and build picker queries',
    () {
      const customer = BeakToOneField(
        model: _Model('orders'),
        relation: _customer,
        target: _Model('customers'),
      );
      const ordersRelation = BeakHasMany(
        key: 'orders',
        label: 'Orders',
        relatedTable: 'orders',
        displayColumnKey: 'name',
        foreignKey: 'customer_id',
      );
      const orders = BeakToManyField(
        model: _Model('customers'),
        relation: ordersRelation,
        target: _Model('orders'),
      );
      final ada = BeakRecord.fromRow({'id': 3, 'name': 'Ada'});
      final order = BeakRecord(
        values: const {},
        relations: {
          'customer': [ada],
        },
      );
      expect(customer.label, 'Customer');
      expect(customer.readFrom(order), ada);
      expect(customer.readFrom(BeakRecord.fromRow({})), isNull);
      expect(
        customer.eq(ada).toJson()['value'],
        const BeakIntValue(3).toJson(),
      );
      expect(customer.eq(null).toJson()['operator'], 'isNull');
      expect(customer.equalsId(3).toJson()['column'], 'customer_id');
      final options = customer.options(
        search: 'ad',
        filter: const BeakScalarField<int>(
          model: _Model('customers'),
          column: _id,
        ).gte(1),
      );
      expect(options.model.table, 'customers');
      expect(options.query.search?.term, 'ad');
      expect(options.query.search?.columnKeys, ['name']);
      expect(options.query.filter, isNotNull);
      expect(orders.label, 'Orders');
      expect(
        orders.readFrom(
          BeakRecord(
            values: const {},
            relations: {
              'orders': [order],
            },
          ),
        ),
        [order],
      );
      expect(orders.readFrom(ada), isNull);
      const invalidPath = BeakScalarField<String>(
        model: _Model('customers'),
        column: _name,
        path: [ordersRelation],
      );
      expect(
        () => invalidPath.readFrom(ada),
        throwsA(isA<BeakConfigurationException>()),
      );
      const inverse = BeakToOneField(
        model: _Model('customers'),
        relation: BeakHasOne(
          key: 'profile',
          label: 'Profile',
          relatedTable: 'profiles',
          displayColumnKey: 'name',
          foreignKey: 'customer_id',
        ),
        target: _Model('profiles'),
      );
      expect(
        () => inverse.equalsId(3),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'handwritten models retain conventional policies and transport defaults',
    () {
      const model = _Model('customers');
      expect(model.dataSource, isNull);
      expect(model.createModel, isNull);
      expect(model.editModel, isNull);
      expect(model.relatedModels, isEmpty);
      expect(model.permissions, isA<BeakPermissions>());
      expect(model.capabilities, containsAll(BeakOperation.values));
    },
  );
}
