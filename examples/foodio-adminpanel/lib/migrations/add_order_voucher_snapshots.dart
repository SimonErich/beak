import 'package:beak/migrations.dart';

/// Adds voucher snapshots to an existing demo without replacing its records.
final class AddOrderVoucherSnapshots extends Migration {
  /// Supports both already seeded databases and fresh model-derived tables.
  const AddOrderVoucherSnapshots();

  @override
  String get name => '20260927_200000_add_order_voucher_snapshots';

  @override
  Future<void> up(DatabaseAdapter adapter) async {
    final existing = (await adapter.introspectSchema())['orders']!;
    const columns = [
      SchemaColumn(
        name: 'voucher_rate_basis_points',
        type: ColumnType.integer,
        defaultValue: 0,
      ),
      SchemaColumn(
        name: 'voucher_maximum_discount_cents',
        type: ColumnType.integer,
        nullable: true,
      ),
      SchemaColumn(
        name: 'voucher_food_only',
        type: ColumnType.boolean,
        defaultValue: true,
      ),
    ];
    for (final column in columns.where(
      (column) => !existing.contains(column.name),
    )) {
      await adapter.executeSchema(
        SchemaDescriptor.alterTable(
          table: 'orders',
          alterations: [SchemaAddColumn(column)],
        ),
      );
    }
  }

  @override
  Future<void> down(DatabaseAdapter adapter) async {
    final existing = (await adapter.introspectSchema())['orders'] ?? [];
    for (final key in [
      'voucher_rate_basis_points',
      'voucher_maximum_discount_cents',
      'voucher_food_only',
    ]) {
      if (existing.contains(key)) {
        await adapter.executeSchema(
          SchemaDescriptor.alterTable(
            table: 'orders',
            alterations: [SchemaDropColumn(key)],
          ),
        );
      }
    }
  }
}
