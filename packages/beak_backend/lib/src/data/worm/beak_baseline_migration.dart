import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import 'beak_blueprint.dart';

/// Raised when a migration that cannot be undone is asked to go back.
///
/// Not a [BeakException]: a migration runs from the command line, never
/// behind an HTTP handler, so nothing maps it to a response.
final class BeakIrreversibleMigrationException implements Exception {
  /// Creates the failure for the migration named [migration].
  const BeakIrreversibleMigrationException(this.migration);

  /// The name of the migration that cannot be rolled back.
  final String migration;

  @override
  String toString() =>
      'BeakIrreversibleMigrationException: migration $migration cannot be '
      'rolled back. It adopted tables Beak did not create, and dropping them '
      'would destroy data Beak has no business removing.';
}

/// The migration that brings a database Beak did not create under Beak.
///
/// `beak introspect` writes one beside the schema classes it reads. It lists
/// every [models] table, in foreign-key order, and every many-to-many
/// [pivots] table, and it does one of two things depending on where it runs:
///
/// - **On the database the classes were read from** every table is already
///   there, so it changes nothing. It is recorded as applied, which is the
///   point: from then on the schema classes are the source of truth and
///   `beak migrate` moves that database forward like any other.
/// - **On an empty database** (a teammate's laptop, CI, a staging copy) it
///   builds all of it from the models, so the project does not depend on a
///   dump.
///
/// It creates only what is absent. A table the database already has is never
/// altered: how it differs from the model is a decision for `beak doctor` and
/// `beak make:migration --from-drift`, not something to fix silently on the
/// way in.
///
/// ```dart
/// final class AdoptExistingSchema extends BeakBaselineMigration {
///   const AdoptExistingSchema();
///
///   @override
///   String get name => '20260928_101500_adopt_existing_schema';
///
///   @override
///   List<BeakModel> get models => const [CategoryModel(), ProductModel()];
///
///   @override
///   List<BeakBelongsToMany> get pivots => const [ProductRelations.tags];
/// }
/// ```
abstract base class BeakBaselineMigration extends Migration {
  /// Const constructor for subclasses.
  const BeakBaselineMigration();

  /// The models whose tables the database is expected to have, in
  /// foreign-key order: a table comes after every table it references.
  ///
  /// A foreign key to a table that does not exist yet at that point is left
  /// out, which is what a reference cycle in the source database forces.
  List<BeakModel> get models;

  /// The many-to-many relations whose pivot tables are expected, each
  /// declared by one of the [models].
  List<BeakBelongsToMany> get pivots => const [];

  @override
  Future<void> upSchema(Schema schema) async {
    final known = <String>{...(await schema.adapter.introspectSchema()).keys};
    for (final model in models) {
      if (known.contains(model.table)) {
        continue;
      }
      await schema.create(model.table, (table) {
        BeakBlueprint.defineColumns(table, model);
        BeakBlueprint.defineForeignKeys(table, model, existingTables: known);
      });
      known.add(model.table);
    }
    for (final pivot in pivots) {
      if (known.contains(pivot.pivotTable)) {
        continue;
      }
      await BeakBlueprint.createPivot(
        schema,
        pivot,
        ownerTable: _ownerOf(pivot).table,
      );
      known.add(pivot.pivotTable);
    }
  }

  /// Always throws [BeakIrreversibleMigrationException]: the tables this
  /// migration adopts were not created by it, so it has nothing of its own to
  /// take back.
  @override
  Future<void> downSchema(Schema schema) async =>
      throw BeakIrreversibleMigrationException(name);

  /// The model, among [models], that declares [pivot].
  ///
  /// A pivot's foreign key on the owning side points at the owner's table,
  /// and the relation itself does not say which table that is.
  BeakModel _ownerOf(BeakBelongsToMany pivot) {
    for (final model in models) {
      if (model.relationships.contains(pivot)) {
        return model;
      }
    }
    throw BeakConfigurationException(
      'The pivot ${pivot.pivotTable} in $name is not declared by any of its '
      'models, so the table it joins from is unknown. List the model that '
      'declares ${pivot.key} in `models`.',
    );
  }
}
