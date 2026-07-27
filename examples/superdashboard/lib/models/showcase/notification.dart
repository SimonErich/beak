import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'notification.beak.dart';

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

/// The notifications resource — seeded notification-center content.
@Resource()
final class Notification extends BeakSchema {
  /// Notification title.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(120)])
  late final String title;

  /// Notification body.
  @Column(rules: [BeakMaxLength(255)])
  late final String? body;

  /// Severity.
  @Column(filterable: true, defaultValue: NotificationLevel.info)
  @Badges({
    NotificationLevel.info: BeakColor.info,
    NotificationLevel.success: BeakColor.success,
    NotificationLevel.warning: BeakColor.warning,
    NotificationLevel.error: BeakColor.error,
  })
  late final NotificationLevel? level;

  /// Icon name.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final String? icon;

  /// Whether the notification has been read.
  @Column(label: 'Read', filterable: true)
  late final bool? isRead;

  /// When the notification fired.
  @Column(label: 'When', format: BeakDateFormat.relative, sortable: true)
  late final DateTime? createdAt;
}
