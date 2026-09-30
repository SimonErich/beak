import 'package:beak/migrations.dart';

import '../resources/tasks/models/task.dart';

/// Creates the tasks table.
///
/// Derived from TaskModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateTasksTable extends Migration {
  /// Creates the migration.
  const CreateTasksTable();

  @override
  String get name => '20260929_055002_create_tasks_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('tasks', (table) {
      BeakBlueprint.defineColumns(table, const TaskModel());
      BeakBlueprint.defineForeignKeys(table, const TaskModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('tasks', ifExists: true);
}
