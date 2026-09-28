import 'package:beak/migrations.dart';

import '../models/message_delivery.dart';

/// Creates the message_deliveries table.
///
/// Derived from MessageDeliveryModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateMessageDeliveriesTable extends Migration {
  /// Creates the migration.
  const CreateMessageDeliveriesTable();

  @override
  String get name => '20260927_072334_create_message_deliveries_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('message_deliveries', (table) {
      BeakBlueprint.defineColumns(table, const MessageDeliveryModel());
      BeakBlueprint.defineForeignKeys(table, const MessageDeliveryModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('message_deliveries', ifExists: true);
}
