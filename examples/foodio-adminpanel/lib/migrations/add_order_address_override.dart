import 'package:beak/migrations.dart';

/// Enables explicit per-shipment addresses without modifying saved locations.
final class AddOrderAddressOverride extends Migration {
  /// Supports both populated demos and fresh model-derived tables.
  const AddOrderAddressOverride();

  @override
  String get name => '20260927_210000_add_order_address_override';

  @override
  Future<void> up(DatabaseAdapter adapter) async {
    if ((await adapter.introspectSchema())['orders']!.contains(
      'address_override',
    )) {
      return;
    }
    await adapter.executeSchema(
      const SchemaDescriptor.alterTable(
        table: 'orders',
        alterations: [
          SchemaAddColumn(
            SchemaColumn(
              name: 'address_override',
              type: ColumnType.boolean,
              defaultValue: false,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> down(DatabaseAdapter adapter) async {
    if (!(await adapter.introspectSchema())['orders']!.contains(
      'address_override',
    )) {
      return;
    }
    await adapter.executeSchema(
      const SchemaDescriptor.alterTable(
        table: 'orders',
        alterations: [SchemaDropColumn('address_override')],
      ),
    );
  }
}
