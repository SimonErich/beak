import 'package:beak/migrations.dart';

import '../resources/vouchers/models/voucher.dart';

/// Creates the vouchers table.
///
/// Derived from VoucherModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateVouchersTable extends Migration {
  /// Creates the migration.
  const CreateVouchersTable();

  @override
  String get name => '20260926_213339_create_vouchers_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('vouchers', (table) {
      BeakBlueprint.defineColumns(table, const VoucherModel());
      BeakBlueprint.defineForeignKeys(table, const VoucherModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('vouchers', ifExists: true);
}
