import 'package:beak/migrations.dart';

import '../models/notification.dart';

/// Creates the notifications table.
///
/// Derived from NotificationModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateNotificationsTable extends Migration {
  /// Creates the migration.
  const CreateNotificationsTable();

  @override
  String get name => '20260927_071052_create_notifications_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('notifications', (table) {
      BeakBlueprint.defineColumns(table, const NotificationModel());
      BeakBlueprint.defineForeignKeys(table, const NotificationModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('notifications', ifExists: true);
}
