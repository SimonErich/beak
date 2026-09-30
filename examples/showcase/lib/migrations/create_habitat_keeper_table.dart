import 'package:beak/migrations.dart';

import '../resources/habitats/models/habitat.dart';

/// Creates the habitat_keeper pivot joining habitats and its
/// keepers.
final class CreateHabitatKeeperTable extends Migration {
  /// Creates the migration.
  const CreateHabitatKeeperTable();

  @override
  String get name => '20260929_055003_create_habitat_keeper_table';

  @override
  Future<void> upSchema(Schema schema) => BeakBlueprint.createPivot(
    schema,
    HabitatRelations.keepers,
    ownerTable: 'habitats',
  );

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('habitat_keeper', ifExists: true);
}
