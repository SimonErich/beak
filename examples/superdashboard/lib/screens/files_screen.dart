import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';
import 'package:beak/ui.dart';

/// The file manager — a three-pane layout composed from Beak blocks: the
/// folder tree on the left, the files themselves in the middle on a real
/// [BeakFileManagerBlock], and connected cloud-storage accounts on the
/// right. All from seeded data.
///
/// `files` stores only files — folders are their own table, and the left
/// pane — so the manager's folder flag is left unbound.
BeakScreen buildFilesScreen() => const BeakScreen(
  path: '/files',
  title: 'File Manager',
  icon: BeakIconToken(OiIcons.folder),
  section: 'Apps',
  framed: false,
  body: BeakThreePaneBlock(
    label: 'File manager',
    leftWidthInPixels: 260,
    rightWidthInPixels: 320,
    left: BeakTableBlock(
      title: 'Folders',
      model: FileFolderModel(),
      heightInPixels: 640,
    ),
    middle: BeakFileManagerBlock(
      label: 'Files',
      model: ManagedFileModel(),
      nameField: ManagedFileColumns.name,
      sizeField: ManagedFileColumns.size,
      modifiedField: ManagedFileColumns.modifiedAt,
    ),
    right: BeakTableBlock(
      title: 'Storage',
      model: StorageAccountModel(),
      heightInPixels: 640,
    ),
  ),
);
