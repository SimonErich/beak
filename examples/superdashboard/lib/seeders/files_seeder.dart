import 'package:superdashboard/models/models.dart';

import 'seed_context.dart';
import 'seed_ids.dart';

/// One cloud-storage account definition.
typedef _Account = ({
  StorageProvider provider,
  String label,
  int used,
  int total,
  String color,
  String icon,
});

/// Seeds the Files domain: cloud accounts, a folder tree, files, and shares.
final class FilesSeeder {
  /// Creates the seeder.
  const FilesSeeder();

  static const int _gb = 1024 * 1024 * 1024;

  static const List<_Account> _accounts = [
    (
      provider: StorageProvider.googleDrive,
      label: 'Google Drive',
      used: 11 * _gb,
      total: 15 * _gb,
      color: '#22c55e',
      icon: 'google-drive',
    ),
    (
      provider: StorageProvider.dropbox,
      label: 'Dropbox',
      used: 14 * _gb,
      total: 20 * _gb,
      color: '#0ea5e9',
      icon: 'dropbox',
    ),
    (
      provider: StorageProvider.oneDrive,
      label: 'OneDrive',
      used: 6 * _gb,
      total: 10 * _gb,
      color: '#6366f1',
      icon: 'onedrive',
    ),
  ];

  static const List<String> _rootFolders = [
    'Analytics',
    'Design',
    'Development',
    'Project A',
    'Admin',
  ];

  static const List<({String ext, AttachmentKind kind})> _fileKinds = [
    (ext: 'png', kind: AttachmentKind.image),
    (ext: 'pdf', kind: AttachmentKind.pdf),
    (ext: 'mp4', kind: AttachmentKind.video),
    (ext: 'xlsx', kind: AttachmentKind.spreadsheet),
    (ext: 'zip', kind: AttachmentKind.archive),
    (ext: 'dart', kind: AttachmentKind.code),
  ];

  /// Seeds all Files-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    await ctx.insertMany('storage_accounts', [
      for (var index = 0; index < _accounts.length; index++)
        {
          'id': ctx.uuid(),
          'provider': _accounts[index].provider.name,
          'label': _accounts[index].label,
          'used_bytes': _accounts[index].used,
          'total_bytes': _accounts[index].total,
          'color': _accounts[index].color,
          'icon': _accounts[index].icon,
          'connected': true,
        },
    ]);

    final folderRows = <Map<String, Object?>>[];
    final fileRows = <Map<String, Object?>>[];
    final shareRows = <Map<String, Object?>>[];
    final allFolderIds = <String>[];

    void seedFilesFor(String folderId) {
      final count = ctx.between(3, 7);
      for (var index = 0; index < count; index++) {
        final id = ctx.uuid();
        final kind = ctx.pick(_fileKinds);
        fileRows.add({
          'id': id,
          'name': '${ctx.faker.word()}-${ctx.between(1, 99)}.${kind.ext}',
          'kind': kind.kind.name,
          'extension': kind.ext,
          'size': ctx.between(40_000, 240_000_000),
          'folder_id': folderId,
          'owner_id': ctx.pick(SeedIds.heroUsers),
          'file': 'files/store/$id',
          'starred': ctx.chance(0.2),
          'modified_at': ctx.daysAgo(60),
        });
        if (ctx.chance(0.25)) {
          shareRows.add({
            'id': ctx.uuid(),
            'file_id': id,
            'shared_with_id': ctx.pick(SeedIds.heroUsers),
            'permission': ctx.pick(SharePermission.values).name,
            'shared_at': ctx.daysAgo(30),
          });
        }
      }
    }

    for (final name in _rootFolders) {
      final rootId = ctx.uuid();
      allFolderIds.add(rootId);
      folderRows.add({
        'id': rootId,
        'name': name,
        'parent_id': null,
        'owner_id': ctx.pick(SeedIds.heroUsers),
        'color': ctx.faker.hexColor(),
        'created_at': ctx.daysAgo(300),
        'updated_at': ctx.daysAgo(20),
      });
      seedFilesFor(rootId);
      // One or two nested sub-folders per root (a real tree).
      final childCount = ctx.between(1, 2);
      for (var index = 0; index < childCount; index++) {
        final childId = ctx.uuid();
        allFolderIds.add(childId);
        folderRows.add({
          'id': childId,
          'name': '${ctx.faker.word()} ${ctx.between(1, 9)}',
          'parent_id': rootId,
          'owner_id': ctx.pick(SeedIds.heroUsers),
          'color': ctx.faker.hexColor(),
          'created_at': ctx.daysAgo(200),
          'updated_at': ctx.daysAgo(15),
        });
        seedFilesFor(childId);
      }
    }

    await ctx.insertMany('file_folders', folderRows);
    await ctx.insertMany('files', fileRows);
    await ctx.insertMany('file_shares', shareRows);
  }
}
