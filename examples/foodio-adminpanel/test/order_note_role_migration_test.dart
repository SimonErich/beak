import 'package:beak/migrations.dart';
import 'package:foodio_adminpanel/migrations/add_order_note_author_role.dart';
import 'package:test/test.dart';

void main() {
  for (final fresh in [false, true]) {
    test(
      'author role migration preserves ${fresh ? 'fresh' : 'legacy'} notes and is idempotent',
      () async {
        final adapter = adapterFromUrl(Uri.parse('sqlite::memory:'));
        await adapter.connect();
        addTearDown(adapter.disconnect);
        await adapter.executeSchema(
          SchemaDescriptor.createTable(
            table: 'order_notes',
            columns: [
              const SchemaColumn(name: 'id', type: ColumnType.string),
              const SchemaColumn(name: 'body', type: ColumnType.string),
              if (fresh)
                const SchemaColumn(
                  name: 'author_role',
                  type: ColumnType.string,
                  nullable: true,
                ),
            ],
          ),
        );
        await adapter.insert(
          InsertDescriptor(
            table: 'order_notes',
            values: {
              'id': 'existing',
              'body': 'Keep this note',
              if (fresh) 'author_role': 'Head chef',
            },
          ),
        );
        const migration = AddOrderNoteAuthorRole();
        await migration.up(adapter);
        await migration.up(adapter);
        final row = await adapter.selectOne(
          QueryDescriptor(
            table: 'order_notes',
            where: const Field<String>('id').eq('existing'),
          ),
        );
        expect(row!['body'], 'Keep this note');
        expect(row['author_role'], fresh ? 'Head chef' : null);
        await migration.down(adapter);
        await migration.down(adapter);
        expect(
          (await adapter.introspectSchema())['order_notes'],
          isNot(contains('author_role')),
        );
        expect(
          (await adapter.selectOne(
            const QueryDescriptor(table: 'order_notes'),
          ))!['body'],
          'Keep this note',
        );
      },
    );
  }
}
