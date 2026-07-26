import 'package:beak_backend/beak_backend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:worm/worm.dart';

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
      (table) => BeakBlueprint.defineColumns(table, const CategoryModel()),
    );
    await schema.create(
      'tags',
      (table) => BeakBlueprint.defineColumns(table, const TagModel()),
    );
    await schema.create('products', (table) {
      BeakBlueprint.defineColumns(table, const ProductModel());
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
      (table) => BeakBlueprint.definePivot(
        table,
        leftColumn: 'product_id',
        leftTable: 'products',
        rightColumn: 'tag_id',
        rightTable: 'tags',
      ),
    );
    await schema.create('orders', (table) {
      BeakBlueprint.defineColumns(table, const OrderModel());
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
      BeakBlueprint.defineColumns(table, const OrderItemModel());
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
      BeakBlueprint.defineColumns(table, const TransactionModel());
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
    await schema.create('product_variants', (table) {
      BeakBlueprint.defineColumns(table, const ProductVariantModel());
      table.foreign(
        column: 'product_id',
        references: 'id',
        onTable: 'products',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create('product_images', (table) {
      BeakBlueprint.defineColumns(table, const ProductImageModel());
      table.foreign(
        column: 'product_id',
        references: 'id',
        onTable: 'products',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create('product_reviews', (table) {
      BeakBlueprint.defineColumns(table, const ProductReviewModel());
      table.index(['rating']);
      table.foreign(
        column: 'product_id',
        references: 'id',
        onTable: 'products',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create('price_rules', (table) {
      BeakBlueprint.defineColumns(table, const PriceRuleModel());
      table.foreign(
        column: 'product_id',
        references: 'id',
        onTable: 'products',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create('order_events', (table) {
      BeakBlueprint.defineColumns(table, const OrderEventModel());
      table.index(['kind']);
      table.foreign(
        column: 'order_id',
        references: 'id',
        onTable: 'orders',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create('order_comments', (table) {
      BeakBlueprint.defineColumns(table, const OrderCommentModel());
      table.foreign(
        column: 'order_id',
        references: 'id',
        onTable: 'orders',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'author_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'order_comments',
      'order_events',
      'product_reviews',
      'price_rules',
      'product_images',
      'product_variants',
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
