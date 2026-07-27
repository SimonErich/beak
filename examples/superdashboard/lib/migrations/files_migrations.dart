import 'package:beak_backend/beak_backend.dart';
import 'package:superdashboard/models/models.dart';
import 'package:worm/worm.dart';

/// Creates the Files domain: the folder tree, files, cloud accounts, and
/// shares.
final class CreateFilesTables extends Migration {
  /// Creates the migration.
  const CreateFilesTables();

  @override
  String get name => '20260707_000700_create_files_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('file_folders', (table) {
      BeakBlueprint.defineColumns(table, const FileFolderModel());
      table.foreign(
        column: 'parent_id',
        references: 'id',
        onTable: 'file_folders',
        onDelete: OnDelete.setNull,
      );
      table.foreign(
        column: 'owner_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create('files', (table) {
      BeakBlueprint.defineColumns(
        table,
        const ManagedFileModel(),
        bigIntColumns: {'size'},
      );
      table.index(['folder_id']);
      table.foreign(
        column: 'folder_id',
        references: 'id',
        onTable: 'file_folders',
        onDelete: OnDelete.setNull,
      );
      table.foreign(
        column: 'owner_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create(
      'storage_accounts',
      (table) => BeakBlueprint.defineColumns(
        table,
        const StorageAccountModel(),
        bigIntColumns: {'used_bytes', 'total_bytes'},
      ),
    );
    await schema.create('file_shares', (table) {
      BeakBlueprint.defineColumns(table, const FileShareModel());
      table.foreign(
        column: 'file_id',
        references: 'id',
        onTable: 'files',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'shared_with_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.cascade,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'file_shares',
      'storage_accounts',
      'files',
      'file_folders',
    ]) {
      await schema.drop(table, ifExists: true);
    }
  }
}
