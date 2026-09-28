import 'package:beak/migrations.dart';

import '../models/staff_member.dart';

/// Creates the staff_members table.
///
/// Derived from StaffMemberModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateStaffMembersTable extends Migration {
  /// Creates the migration.
  const CreateStaffMembersTable();

  @override
  String get name => '20260927_071036_create_staff_members_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('staff_members', (table) {
      BeakBlueprint.defineColumns(table, const StaffMemberModel());
      BeakBlueprint.defineForeignKeys(table, const StaffMemberModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('staff_members', ifExists: true);
}
