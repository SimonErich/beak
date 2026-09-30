import 'package:beak/migrations.dart';
import 'package:foodio_adminpanel/migrations/add_order_address_override.dart';
import 'package:test/test.dart';

void main() {
  test(
    'address intent migration preserves legacy rows and is idempotent',
    () async {
      final adapter = adapterFromUrl(Uri.parse('sqlite::memory:'));
      await adapter.connect();
      addTearDown(adapter.disconnect);
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(
          table: 'orders',
          columns: [
            SchemaColumn(name: 'id', type: ColumnType.string),
            SchemaColumn(name: 'street', type: ColumnType.string),
          ],
        ),
      );
      await adapter.insert(
        const InsertDescriptor(
          table: 'orders',
          values: {'id': 'existing', 'street': 'Original address'},
        ),
      );
      const migration = AddOrderAddressOverride();
      await migration.up(adapter);
      await migration.up(adapter);
      final row = await adapter.selectOne(
        QueryDescriptor(
          table: 'orders',
          where: const Field<String>('id').eq('existing'),
        ),
      );
      expect(row!['street'], 'Original address');
      expect(row['address_override'], anyOf(false, 0));
      await migration.down(adapter);
      await migration.down(adapter);
      expect(
        (await adapter.introspectSchema())['orders'],
        isNot(contains('address_override')),
      );
    },
  );
}
