import 'package:beak/migrations.dart';

import '../models/app_setting.dart';

/// Creates the app_settings table.
///
/// Derived from AppSettingModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateAppSettingsTable extends Migration {
  /// Creates the migration.
  const CreateAppSettingsTable();

  @override
  String get name => '20260927_071034_create_app_settings_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('app_settings', (table) {
      BeakBlueprint.defineColumns(table, const AppSettingModel());
      BeakBlueprint.defineForeignKeys(table, const AppSettingModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('app_settings', ifExists: true);
}
