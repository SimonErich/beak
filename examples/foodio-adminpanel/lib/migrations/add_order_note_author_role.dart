import 'package:beak/migrations.dart';

/// Preserves historical role context without replacing existing note records.
final class AddOrderNoteAuthorRole extends Migration {
  /// Fresh model-derived tables already contain this nullable snapshot column.
  const AddOrderNoteAuthorRole();

  @override
  String get name => '20260928_120000_add_order_note_author_role';

  @override
  Future<void> up(DatabaseAdapter adapter) async {
    if ((await adapter.introspectSchema())['order_notes']!.contains(
      'author_role',
    )) {
      return;
    }
    await adapter.executeSchema(
      const SchemaDescriptor.alterTable(
        table: 'order_notes',
        alterations: [
          SchemaAddColumn(
            SchemaColumn(
              name: 'author_role',
              type: ColumnType.string,
              nullable: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> down(DatabaseAdapter adapter) async {
    if (!(await adapter.introspectSchema())['order_notes']!.contains(
      'author_role',
    )) {
      return;
    }
    await adapter.executeSchema(
      const SchemaDescriptor.alterTable(
        table: 'order_notes',
        alterations: [SchemaDropColumn('author_role')],
      ),
    );
  }
}
