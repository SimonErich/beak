import 'package:beak_backend/beak_backend.dart';
import 'package:reference_admin_models/reference_admin_models.dart';
import 'package:worm/worm.dart';

/// Creates the categories lookup table.
final class CreateCategoriesTable extends Migration {
  /// Creates the migration.
  const CreateCategoriesTable();

  @override
  String get name => '20260701_000100_create_categories_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('categories', (table) {
      table.idUuid();
      table.string('name', length: 120);
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('categories', ifExists: true);
}

/// Creates the tags lookup table.
final class CreateTagsTable extends Migration {
  /// Creates the migration.
  const CreateTagsTable();

  @override
  String get name => '20260701_000200_create_tags_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('tags', (table) {
      table.idUuid();
      table.string('name', length: 60);
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('tags', ifExists: true);
}

/// Creates the users table.
final class CreateUsersTable extends Migration {
  /// Creates the migration.
  const CreateUsersTable();

  @override
  String get name => '20260701_000300_create_users_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('users', (table) {
      table.idUuid();
      table.string('name', length: 120);
      table.string('email');
      table.boolean('active').withDefault(true);
      table.unique(['email']);
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('users', ifExists: true);
}

/// Creates the products table (soft-deleting, timestamped).
final class CreateProductsTable extends Migration {
  /// Creates the migration.
  const CreateProductsTable();

  @override
  String get name => '20260701_000400_create_products_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('products', (table) {
      // Columns, nullability, soft deletes and the category foreign key are
      // all derived from ProductModel, so this migration cannot drift from it.
      BeakBlueprint.defineColumns(
        table,
        const ProductModel(),
        // Stock has no model-level default to derive from; state it here.
        columnDefaults: {ProductColumns.stock.key: 0},
      );
      // No table.timestamps() here: ProductColumns declares created_at and
      // updated_at, so defineColumns already emitted them.
      table.index(['status']);
      BeakBlueprint.defineForeignKeys(table, const ProductModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('products', ifExists: true);
}

/// Creates the product↔tag pivot table.
final class CreateProductTagTable extends Migration {
  /// Creates the migration.
  const CreateProductTagTable();

  @override
  String get name => '20260701_000500_create_product_tag_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Pure join data: no surrogate key — the pair is the identity, and pivot
    // inserts ship only the two foreign keys. Both sides come from the
    // relationship declaration.
    await BeakBlueprint.createPivot(
      schema,
      ProductRelations.tags,
      ownerTable: const ProductModel().table,
    );
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('product_tag', ifExists: true);
}

/// Creates the orders table.
final class CreateOrdersTable extends Migration {
  /// Creates the migration.
  const CreateOrdersTable();

  @override
  String get name => '20260701_000600_create_orders_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('orders', (table) {
      table.idUuid();
      table.string('reference', length: 40);
      table.decimal('total');
      table.dateTime('placed_at').makeNullable();
      table.uuid('user_id').makeNullable();
      table.unique(['reference']);
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('orders', ifExists: true);
}

/// Creates the order-items table.
final class CreateOrderItemsTable extends Migration {
  /// Creates the migration.
  const CreateOrderItemsTable();

  @override
  String get name => '20260701_000700_create_order_items_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('order_items', (table) {
      table.idUuid();
      table.string('label', length: 160);
      table.integer('quantity').withDefault(1);
      table.decimal('unit_price');
      table.uuid('order_id');
      table.uuid('product_id').makeNullable();
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
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('order_items', ifExists: true);
}

/// Every reference migration, in dependency order.
const List<Migration> referenceMigrations = [
  CreateCategoriesTable(),
  CreateTagsTable(),
  CreateUsersTable(),
  CreateProductsTable(),
  CreateProductTagTable(),
  CreateOrdersTable(),
  CreateOrderItemsTable(),
];
