import 'package:beak_backend/beak_backend.dart';
import 'package:superdashboard/models/models.dart';
import 'package:worm/worm.dart';

/// Creates the Kanban domain: boards, columns, cards, labels, and their
/// pivots.
final class CreateKanbanTables extends Migration {
  /// Creates the migration.
  const CreateKanbanTables();

  @override
  String get name => '20260707_000900_create_kanban_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('boards', (table) {
      BeakBlueprint.defineColumns(table, const BoardModel());
      table.foreign(
        column: 'owner_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create('board_columns', (table) {
      BeakBlueprint.defineColumns(table, const BoardColumnModel());
      table.index(['board_id']);
      table.foreign(
        column: 'board_id',
        references: 'id',
        onTable: 'boards',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create(
      'card_labels',
      (table) => BeakBlueprint.defineColumns(table, const CardLabelModel()),
    );
    await schema.create('cards', (table) {
      BeakBlueprint.defineColumns(table, const CardModel());
      table.index(['column_id']);
      table.foreign(
        column: 'column_id',
        references: 'id',
        onTable: 'board_columns',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create(
      'card_card_label',
      (table) => BeakBlueprint.definePivot(
        table,
        leftColumn: 'card_id',
        leftTable: 'cards',
        rightColumn: 'card_label_id',
        rightTable: 'card_labels',
      ),
    );
    await schema.create(
      'card_user',
      (table) => BeakBlueprint.definePivot(
        table,
        leftColumn: 'card_id',
        leftTable: 'cards',
        rightColumn: 'user_id',
        rightTable: 'users',
      ),
    );
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'card_user',
      'card_card_label',
      'cards',
      'card_labels',
      'board_columns',
      'boards',
    ]) {
      await schema.drop(table, ifExists: true);
    }
  }
}
