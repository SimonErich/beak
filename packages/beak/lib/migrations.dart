/// The schema DSL a migration and a seeder are written with: worm's
/// `Migration`, `Schema` and `BlueprintTable`, plus Beak's `BeakBlueprint`,
/// which derives a table from a model rather than restating it.
///
/// ```dart
/// import 'package:beak/migrations.dart';
///
/// final class CreateProductsTable extends Migration {
///   @override
///   Future<void> upSchema(Schema schema) =>
///       schema.create('products', (table) {
///         BeakBlueprint.defineColumns(table, const ProductModel());
///       });
/// }
/// ```
library;

export 'package:worm/worm.dart';

export 'server.dart';
