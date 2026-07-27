import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';

/// The notification show page: a headline strip of the title, severity, and
/// read state, then a two-column body splitting the message text from its
/// display icon.
const BeakBlock notificationDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Notification',
      child: BeakFieldGroupBlock([
        NotificationColumns.title,
        NotificationColumns.level,
        NotificationColumns.isRead,
        NotificationColumns.createdAt,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 8),
          title: 'Message',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(NotificationColumns.title),
              BeakFieldBlock(NotificationColumns.body),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Display',
          child: BeakFieldGroupBlock([
            NotificationColumns.icon,
            NotificationColumns.level,
          ], columnCount: 1),
        ),
      ],
    ),
  ],
);
