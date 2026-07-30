import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import 'worm_data_source.dart';

/// Derives a worm schema from a [BeakModel]'s typed columns and relationships.
///
/// A migration that spells its columns out by hand is a second declaration of
/// the schema, and second declarations drift. Every helper here reads the
/// model instead, so a migration cannot disagree with the model it migrates —
/// column parity holds by construction rather than by review.
///
/// ```dart
/// final class CreateProductsTable extends Migration {
///   const CreateProductsTable();
///
///   @override
///   String get name => '20260726_120000_create_products_table';
///
///   @override
///   Future<void> upSchema(Schema schema) async {
///     await schema.create('products', (table) {
///       BeakBlueprint.defineColumns(table, const ProductModel());
///       BeakBlueprint.defineForeignKeys(table, const ProductModel());
///       table.index(['status']);
///     });
///     await BeakBlueprint.createPivot(schema, ProductRelations.tags);
///   }
///
///   @override
///   Future<void> downSchema(Schema schema) async =>
///       schema.drop('products', ifExists: true);
/// }
/// ```
///
/// Migrations stay explicit and hand-registered — nothing here runs on its
/// own. What is derived is the *content* of a migration, not the decision to
/// apply one.
abstract final class BeakBlueprint {
  /// Default length of a `varchar` column when the model does not bound it.
  static const int defaultStringLength = 255;

  /// Length of the `varchar` backing enum and colour columns.
  static const int tokenLength = 40;

  /// Length of the `varchar` holding an upload's storage key.
  static const int storageKeyLength = 512;

  /// Adds every column of [model] to [table].
  ///
  /// - `id` becomes the UUID primary key.
  /// - A column backing a belongs-to relationship becomes a nullable `uuid`
  ///   foreign-key column; [defineForeignKeys] adds the constraint.
  /// - A column carrying [BeakRequired] is `NOT NULL`; the rest are nullable,
  ///   which is the same rule the form validator and the API enforce.
  /// - Booleans default to `false` rather than being nullable.
  /// - An enum column declaring a [BeakEnumColumn.defaultValue] gets that
  ///   value as its schema default, so the model's default and the column's
  ///   are never two separate decisions.
  /// - Integer columns named in [bigIntColumns] use `bigInteger`, for values
  ///   above the 32-bit range (byte counts, for instance).
  ///
  /// [columnDefaults] supplies defaults the model has no way to express —
  /// keyed by column key, applied instead of making the column nullable.
  ///
  /// `softDeletes()` is appended for a model that soft-deletes, and owns the
  /// marker column: a model that also declares `deleted_at` among its columns
  /// has it emitted once, not twice.
  ///
  /// Every column the model declares is emitted, timestamps included. If
  /// `created_at`/`updated_at` are among them, do **not** also call
  /// `table.timestamps()` — the table would declare them twice and the
  /// database would reject the `CREATE TABLE`. Call `timestamps()` only for a
  /// model that does not declare them.
  static void defineColumns(
    BlueprintTable table,
    BeakModel model, {
    Set<String> bigIntColumns = const {},
    Map<String, Object?> columnDefaults = const {},
  }) {
    final foreignKeys = <String>{
      for (final relation in model.relationships)
        if (relation is BeakBelongsTo) relation.foreignKey,
    };

    for (final column in model.columns) {
      if (column.key == model.primaryKey.key) {
        table.idUuid();
        continue;
      }
      // `softDeletes()` below owns the marker column. A model that declares
      // it — every generated model of a soft-deleting resource does — would
      // otherwise name it twice and the database would reject the table.
      if (model.softDeletes &&
          column.key == WormDataSource.softDeleteColumnKey) {
        continue;
      }
      defineColumn(
        table,
        column,
        isForeignKey: foreignKeys.contains(column.key),
        bigIntColumns: bigIntColumns,
        columnDefaults: columnDefaults,
      );
    }

    // Every belongs-to foreign key, without being asked. The panel joins on
    // them to render a list page, so an unindexed one is a sequential scan
    // per row on the most common query a Beak app makes.
    for (final key in foreignKeys) {
      table.index(<String>[key]);
    }

    if (model.softDeletes) {
      table.softDeletes();
    }
  }

  /// Declares one [column] on [table], the same way [defineColumns] would.
  ///
  /// Split out so a migration that adds a single column derives its DDL from
  /// the same mapping the create migration used. A generated `alter` that
  /// spelled the column out itself would be a second answer to "what SQL
  /// does this Beak column become", free to drift from this one.
  ///
  /// [isForeignKey] is what the caller knows and the column does not: a
  /// belongs-to key is a nullable uuid whatever its declared kind says.
  static void defineColumn(
    BlueprintTable table,
    BeakColumn column, {
    bool isForeignKey = false,
    Set<String> bigIntColumns = const {},
    Map<String, Object?> columnDefaults = const {},
  }) {
    if (isForeignKey) {
      table.uuid(column.key).makeNullable();
      return;
    }
    final definition = switch (column) {
      BeakStringColumn(:final maxLength) => table.string(
        column.key,
        length: maxLength ?? defaultStringLength,
      ),
      BeakEnumColumn() ||
      BeakColorColumn() => table.string(column.key, length: tokenLength),
      BeakImageColumn() ||
      BeakFileColumn() => table.string(column.key, length: storageKeyLength),
      BeakTextColumn() ||
      BeakRichTextColumn() ||
      BeakCustomColumn() => table.text(column.key),
      BeakIntColumn() =>
        bigIntColumns.contains(column.key)
            ? table.bigInteger(column.key)
            : table.integer(column.key),
      BeakDecimalColumn(:final totalDigits, :final precision) => table.decimal(
        column.key,
        precision: totalDigits,
        scale: precision,
      ),
      BeakBoolColumn() => table.boolean(column.key),
      BeakDateTimeColumn() => table.dateTime(column.key),
      BeakJsonColumn() => table.json(column.key),
    };
    final Object? declaredDefault = columnDefaults.containsKey(column.key)
        ? columnDefaults[column.key]
        : _modelDefaultOf(column);
    if (declaredDefault != null) {
      definition.withDefault(declaredDefault);
    } else if (!column.rules.any((rule) => rule is BeakRequired)) {
      definition.makeNullable();
    }
    if (column.unique) {
      definition.makeUnique();
    } else if (column.indexed) {
      table.index(<String>[column.key]);
    }
  }

  /// Adds the foreign-key constraint implied by each belongs-to relationship
  /// of [model], honouring the relationship's [BeakOnDelete].
  ///
  /// Skips relationships whose target table is not in [existingTables] when
  /// that set is supplied — migrations run in order, and a constraint cannot
  /// reference a table that does not exist yet.
  static void defineForeignKeys(
    BlueprintTable table,
    BeakModel model, {
    Set<String>? existingTables,
  }) {
    for (final relation in model.relationships) {
      if (relation is! BeakBelongsTo) {
        continue;
      }
      if (existingTables != null &&
          !existingTables.contains(relation.relatedTable)) {
        continue;
      }
      table.foreign(
        column: relation.foreignKey,
        references: 'id',
        onTable: relation.relatedTable,
        onDelete: wormOnDelete(relation.onDelete),
      );
    }
  }

  /// Creates the keyless pivot table backing [relation], with a unique pair
  /// and cascading foreign keys — the shared shape of every many-to-many.
  ///
  /// [ownerTable] is the table declaring [relation]; the pivot's owner column
  /// points at it and its related column at [BeakRelationship.relatedTable].
  static Future<void> createPivot(
    Schema schema,
    BeakBelongsToMany relation, {
    required String ownerTable,
  }) => schema.create(relation.pivotTable, (table) {
    definePivot(
      table,
      leftColumn: relation.foreignPivotKey,
      leftTable: ownerTable,
      rightColumn: relation.relatedPivotKey,
      rightTable: relation.relatedTable,
    );
  });

  /// Defines a keyless pivot joining [leftColumn] to [leftTable] and
  /// [rightColumn] to [rightTable].
  ///
  /// Use it directly for a pivot Beak does not model as a relationship;
  /// [createPivot] is the usual entry point.
  static void definePivot(
    BlueprintTable table, {
    required String leftColumn,
    required String leftTable,
    required String rightColumn,
    required String rightTable,
  }) {
    table.uuid(leftColumn);
    table.uuid(rightColumn);
    table.unique([leftColumn, rightColumn]);
    // The composite unique already indexes left-to-right lookups, but not
    // right-to-left: without this, listing a tag's products is a full scan of
    // the pivot, and a many-to-many is traversed from both sides by
    // definition.
    table.index([rightColumn]);
    table.foreign(
      column: leftColumn,
      references: 'id',
      onTable: leftTable,
      onDelete: OnDelete.cascade,
    );
    table.foreign(
      column: rightColumn,
      references: 'id',
      onTable: rightTable,
      onDelete: OnDelete.cascade,
    );
  }
}

/// The schema default [column] declares in the model, or `null` when it
/// declares none.
///
/// Booleans always default to `false` — a nullable boolean is three-valued,
/// which no Beak form can express. An enum column contributes its
/// [BeakEnumColumn.defaultValue] by wire name, closing the drift surface
/// where a migration restated a default the model already knew.
Object? _modelDefaultOf(BeakColumn column) => switch (column) {
  BeakBoolColumn() => false,
  BeakEnumColumn(:final defaultValue) => defaultValue?.name,
  _ => null,
};

/// Translates Beak's ORM-neutral [BeakOnDelete] to worm's [OnDelete].
///
/// The two enums mirror each other by design; this is the one place the
/// mapping is written, so adding a value to either surfaces as a
/// non-exhaustive switch here rather than as a silent mismatch.
OnDelete wormOnDelete(BeakOnDelete onDelete) => switch (onDelete) {
  BeakOnDelete.cascade => OnDelete.cascade,
  BeakOnDelete.ormCascade => OnDelete.ormCascade,
  BeakOnDelete.restrict => OnDelete.restrict,
  BeakOnDelete.setNull => OnDelete.setNull,
  BeakOnDelete.setDefault => OnDelete.setDefault,
  BeakOnDelete.noAction => OnDelete.noAction,
};
