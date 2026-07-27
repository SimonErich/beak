import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';
import 'package:beak/ui.dart';

/// The file manager — a three-pane layout composed from Beak blocks (obers
/// has no turnkey mailbox-style file manager that fits this two-table
/// schema): the folder tree on the left, files in the middle, and connected
/// cloud-storage accounts on the right. All from seeded data.
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
    middle: BeakTableBlock(
      title: 'Files',
      model: ManagedFileModel(),
      heightInPixels: 640,
    ),
    right: BeakTableBlock(
      title: 'Storage',
      model: StorageAccountModel(),
      heightInPixels: 640,
    ),
  ),
);
