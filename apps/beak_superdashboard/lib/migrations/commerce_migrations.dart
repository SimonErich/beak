import 'package:beak_superdashboard/models/models.dart';
import 'package:worm/worm.dart';

import 'model_schema.dart';

/// Creates the Commerce domain: catalog, orders, and transactions.
final class CreateCommerceTables extends Migration {
  /// Creates the migration.
  const CreateCommerceTables();

  @override
  String get name => '20260707_000200_create_commerce_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create(
      'categories',
      (table) => defineModelColumns(table, const CategoryModel()),
    );
    await schema.create(
      'tags',
      (table) => defineModelColumns(table, const TagModel()),
    );
    await schema.create('products', (table) {
      defineModelColumns(table, const ProductModel());
      table.unique(['sku']);
      table.index(['status']);
      table.foreign(
        column: 'category_id',
        references: 'id',
        onTable: 'categories',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create(
      'product_tag',
      (table) => definePivotTable(
        table,
        leftColumn: 'product_id',
        leftTable: 'products',
        rightColumn: 'tag_id',
        rightTable: 'tags',
      ),
    );
    await schema.create('orders', (table) {
      defineModelColumns(table, const OrderModel());
      table.unique(['reference']);
      table.index(['status']);
      table.index(['source']);
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create('order_items', (table) {
      defineModelColumns(table, const OrderItemModel());
      table.foreign(
        column: 'order_id',
        references: 'id',
        onTable: 'orders',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'product_id',
        references: 'id',
        onTable: 'products',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create('transactions', (table) {
      defineModelColumns(table, const TransactionModel());
      table.index(['status']);
      table.index(['occurred_at']);
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
      table.foreign(
        column: 'order_id',
        references: 'id',
        onTable: 'orders',
        onDelete: OnDelete.setNull,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'transactions',
      'order_items',
      'orders',
      'product_tag',
      'products',
      'tags',
      'categories',
    ]) {
      await schema.drop(table, ifExists: true);
    }
  }
}
