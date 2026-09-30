/// The schema DSL a migration and a seeder are written with: worm's
/// `Migration`, `Schema` and `BlueprintTable`, plus Beak's `BeakBlueprint`,
/// which derives a table from a model rather than restating it.
///
/// ```dart
/// import 'package:beak/migrations.dart';
///
/// import '../models/product.dart';
///
/// final class CreateProductsTable extends Migration {
///   const CreateProductsTable();
///
///   @override
///   String get name => '20260101_000000_create_products_table';
///
///   @override
///   Future<void> upSchema(Schema schema) =>
///       schema.create(const ProductModel().table, (table) {
///         BeakBlueprint.defineColumns(table, const ProductModel());
///       });
///
///   @override
///   Future<void> downSchema(Schema schema) =>
///       schema.drop(const ProductModel().table, ifExists: true);
/// }
/// ```
library;

export 'package:worm/worm.dart';

export 'server.dart';
