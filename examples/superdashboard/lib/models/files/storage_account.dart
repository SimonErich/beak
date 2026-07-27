import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'storage_account.beak.dart';

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

/// The storage-accounts resource — connected cloud drives.
@Resource()
final class StorageAccount extends BeakSchema {
  /// The provider.
  @Column(filterable: true, defaultValue: StorageProvider.googleDrive)
  @Badges({
    StorageProvider.googleDrive: BeakColor.success,
    StorageProvider.dropbox: BeakColor.primary,
    StorageProvider.oneDrive: BeakColor.info,
    StorageProvider.box: BeakColor.warning,
  })
  late final StorageProvider? provider;

  /// Display label.
  @Display()
  @Column(rules: [BeakMaxLength(60)])
  late final String label;

  /// Bytes used.
  @Column(label: 'Used', min: 0, sortable: true)
  late final int? usedBytes;

  /// Total capacity in bytes.
  @Column(label: 'Total', min: 0, sortable: true)
  late final int? totalBytes;

  /// Accent color.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakHexColor? color;

  /// Icon name.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final String? icon;

  /// Whether the account is currently connected.
  @Column(filterable: true)
  late final bool? connected;
}
