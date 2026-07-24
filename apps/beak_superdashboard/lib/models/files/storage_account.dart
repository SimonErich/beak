import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// A connected cloud-storage provider.
enum StorageProvider {
  /// Google Drive.
  googleDrive,

  /// Dropbox.
  dropbox,

  /// Microsoft OneDrive.
  oneDrive,

  /// Box.
  box,
}

/// Typed columns of the storage-accounts resource — the file manager's
/// external-storage widgets.
abstract final class StorageAccountColumns {
  /// The provider.
  static const provider = BeakEnumColumn<StorageProvider>(
    key: 'provider',
    label: 'Provider',
    values: StorageProvider.values,
    defaultValue: StorageProvider.googleDrive,
    filterable: true,
    badgeColors: {
      StorageProvider.googleDrive: BeakColor.success,
      StorageProvider.dropbox: BeakColor.primary,
      StorageProvider.oneDrive: BeakColor.info,
      StorageProvider.box: BeakColor.warning,
    },
  );

  /// Display label.
  static const label = BeakStringColumn(
    key: 'label',
    label: 'Label',
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// Bytes used.
  static const usedBytes = BeakIntColumn(
    key: 'used_bytes',
    label: 'Used',
    min: 0,
    sortable: true,
  );

  /// Total capacity in bytes.
  static const totalBytes = BeakIntColumn(
    key: 'total_bytes',
    label: 'Total',
    min: 0,
    sortable: true,
  );

  /// Accent color.
  static const color = BeakColorColumn(
    key: 'color',
    label: 'Color',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Icon name.
  static const icon = BeakStringColumn(
    key: 'icon',
    label: 'Icon',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Whether the account is currently connected.
  static const connected = BeakBoolColumn(
    key: 'connected',
    label: 'Connected',
    filterable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    provider,
    label,
    usedBytes,
    totalBytes,
    color,
    icon,
    connected,
  ];
}

/// The storage-accounts resource — connected cloud drives.
final class StorageAccountModel extends BeakModel {
  /// Creates the storage-accounts model.
  const StorageAccountModel();

  @override
  String get table => 'storage_accounts';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => StorageAccountColumns.values;

  @override
  List<BeakRelationship> get relationships => const [];
}
