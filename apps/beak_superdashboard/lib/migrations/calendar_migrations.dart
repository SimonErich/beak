import 'package:beak_superdashboard/models/models.dart';
import 'package:worm/worm.dart';

import 'model_schema.dart';

/// Creates the Calendar domain: categories, events, and guest memberships.
final class CreateCalendarTables extends Migration {
  /// Creates the migration.
  const CreateCalendarTables();

  @override
  String get name => '20260707_000600_create_calendar_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create(
      'event_categories',
      (table) => defineModelColumns(table, const EventCategoryModel()),
    );
    await schema.create('calendar_events', (table) {
      defineModelColumns(table, const CalendarEventModel());
      table.index(['start_at']);
      table.foreign(
        column: 'category_id',
        references: 'id',
        onTable: 'event_categories',
        onDelete: OnDelete.setNull,
      );
      table.foreign(
        column: 'organizer_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create(
      'event_user',
      (table) => definePivotTable(
        table,
        leftColumn: 'event_id',
        leftTable: 'calendar_events',
        rightColumn: 'user_id',
        rightTable: 'users',
      ),
    );
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'event_user',
      'calendar_events',
      'event_categories',
    ]) {
      await schema.drop(table, ifExists: true);
    }
  }
}
