import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the mail-folders resource.
abstract final class MailFolderColumns {
  /// Folder key, e.g. `inbox`.
  static const key = BeakStringColumn(
    key: 'key',
    label: 'Key',
    rules: [BeakRequired(), BeakMaxLength(30)],
  );

  /// Display label.
  static const label = BeakStringColumn(
    key: 'label',
    label: 'Label',
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Icon name.
  static const icon = BeakStringColumn(
    key: 'icon',
    label: 'Icon',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Folder accent color.
  static const color = BeakColorColumn(
    key: 'color',
    label: 'Color',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Unread message count (recomputed by the seeder).
  static const unreadCount = BeakIntColumn(
    key: 'unread_count',
    label: 'Unread',
    min: 0,
    sortable: true,
  );

  /// Sidebar ordering.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    key,
    label,
    icon,
    color,
    unreadCount,
    sortIndex,
  ];
}

/// Typed relationships of the mail-folders resource.
abstract final class MailFolderRelations {
  /// Emails in this folder.
  static const emails = BeakHasMany(
    key: 'emails',
    label: 'Emails',
    relatedTable: 'emails',
    displayColumnKey: 'subject',
    foreignKey: 'folder_id',
  );
}

/// The mail-folders resource — the inbox sidebar.
final class MailFolderModel extends BeakModel {
  /// Creates the mail-folders model.
  const MailFolderModel();

  @override
  String get table => 'mail_folders';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => MailFolderColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    MailFolderRelations.emails,
  ];
}
