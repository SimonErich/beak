import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'email.dart';

part 'mail_folder.beak.dart';

/// The mail-folders resource — the inbox sidebar.
@Resource()
final class MailFolder extends BeakSchema {
  /// Folder key, e.g. `inbox`.
  @Column(rules: [BeakMaxLength(30)])
  late final String key;

  /// Display label.
  @Display()
  @Column(rules: [BeakMaxLength(40)])
  late final String label;

  /// Icon name.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final String? icon;

  /// Folder accent color.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakHexColor? color;

  /// Unread message count (recomputed by the seeder).
  @Column(label: 'Unread', sortable: true, min: 0)
  late final int? unreadCount;

  /// Sidebar ordering.
  @Column(label: 'Order', sortable: true, min: 0)
  late final int? sortIndex;

  /// Emails in this folder.
  @HasMany(foreignKey: 'folder_id')
  late final List<Email> emails;
}
