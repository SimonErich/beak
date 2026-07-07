import 'package:beak_superdashboard/models/models.dart';
import 'package:worm/worm.dart';

import 'model_schema.dart';

/// Creates the People domain: users (the identity spine) and everything that
/// hangs off them.
final class CreatePeopleTables extends Migration {
  /// Creates the migration.
  const CreatePeopleTables();

  @override
  String get name => '20260707_000100_create_people_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('users', (table) {
      defineModelColumns(table, const UserModel());
      table.unique(['email']);
      table.index(['status']);
      table.index(['role']);
    });
    await schema.create(
      'skills',
      (table) => defineModelColumns(table, const SkillModel()),
    );
    await schema.create('team_members', (table) {
      defineModelColumns(table, const TeamMemberModel());
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create('activities', (table) {
      defineModelColumns(table, const ActivityModel());
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'parent_id',
        references: 'id',
        onTable: 'activities',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create('user_attachments', (table) {
      defineModelColumns(table, const UserAttachmentModel());
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create(
      'user_skill',
      (table) => definePivotTable(
        table,
        leftColumn: 'user_id',
        leftTable: 'users',
        rightColumn: 'skill_id',
        rightTable: 'skills',
      ),
    );
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'user_skill',
      'user_attachments',
      'activities',
      'team_members',
      'skills',
      'users',
    ]) {
      await schema.drop(table, ifExists: true);
    }
  }
}
