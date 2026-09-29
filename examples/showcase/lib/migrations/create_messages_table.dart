import 'package:beak/migrations.dart';

import '../resources/messages/models/message.dart';

/// Creates the messages table.
///
/// Derived from MessageModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateMessagesTable extends Migration {
  /// Creates the migration.
  const CreateMessagesTable();

  @override
  String get name => '20260929_054957_create_messages_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('messages', (table) {
      BeakBlueprint.defineColumns(table, const MessageModel());
      BeakBlueprint.defineForeignKeys(table, const MessageModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('messages', ifExists: true);
}
