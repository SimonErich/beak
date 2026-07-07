import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// The severity of a notification.
enum NotificationLevel {
  /// Informational.
  info,

  /// Success confirmation.
  success,

  /// Warning.
  warning,

  /// Error.
  error,
}

/// Typed columns of the notifications resource — the notification center and
/// toast demos, seeded rather than hardcoded.
abstract final class NotificationColumns {
  /// Notification title.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// Notification body.
  static const body = BeakStringColumn(
    key: 'body',
    label: 'Body',
    rules: [BeakMaxLength(255)],
  );

  /// Severity.
  static const level = BeakEnumColumn<NotificationLevel>(
    key: 'level',
    label: 'Level',
    values: NotificationLevel.values,
    defaultValue: NotificationLevel.info,
    filterable: true,
    badgeColors: {
      NotificationLevel.info: BeakColor.info,
      NotificationLevel.success: BeakColor.success,
      NotificationLevel.warning: BeakColor.warning,
      NotificationLevel.error: BeakColor.error,
    },
  );

  /// Icon name.
  static const icon = BeakStringColumn(
    key: 'icon',
    label: 'Icon',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Whether the notification has been read.
  static const isRead = BeakBoolColumn(
    key: 'is_read',
    label: 'Read',
    filterable: true,
  );

  /// When the notification fired.
  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'When',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    title,
    body,
    level,
    icon,
    isRead,
    createdAt,
  ];
}

/// The notifications resource — seeded notification-center content.
final class NotificationModel extends BeakModel {
  /// Creates the notifications model.
  const NotificationModel();

  @override
  String get table => 'notifications';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => NotificationColumns.values;

  @override
  List<BeakRelationship> get relationships => const [];
}
