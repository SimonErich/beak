import 'package:beak_backend/beak_backend.dart';
import 'package:superdashboard/models/models.dart';
import 'package:worm/worm.dart';

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
      BeakBlueprint.defineColumns(table, const UserModel());
      table.unique(['email']);
      table.index(['status']);
      table.index(['role']);
    });
    await schema.create(
      'skills',
      (table) => BeakBlueprint.defineColumns(table, const SkillModel()),
    );
    await schema.create('team_members', (table) {
      BeakBlueprint.defineColumns(table, const TeamMemberModel());
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create('activities', (table) {
      BeakBlueprint.defineColumns(table, const ActivityModel());
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
      BeakBlueprint.defineColumns(table, const UserAttachmentModel());
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create(
      'user_skill',
      (table) => BeakBlueprint.definePivot(
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
