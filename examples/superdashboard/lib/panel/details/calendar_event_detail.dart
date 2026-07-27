import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

/// The calendar-event show page: a headline strip of the title and schedule,
/// a two-column body splitting the write-up from the organizing details, and
/// a card listing the invited guests.
const BeakBlock calendarEventDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Calendar event',
      child: BeakFieldGroupBlock([
        CalendarEventColumns.title,
        CalendarEventColumns.startAt,
        CalendarEventColumns.endAt,
        CalendarEventColumns.allDay,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 8),
          title: 'Details',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(CalendarEventColumns.description),
              BeakFieldGroupBlock([
                CalendarEventColumns.location,
                CalendarEventColumns.url,
              ]),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Organization',
          child: BeakFieldGroupBlock([
            CalendarEventColumns.categoryId,
            CalendarEventColumns.organizerId,
            CalendarEventColumns.color,
          ], columnCount: 2),
        ),
      ],
    ),
    BeakCardBlock(
      title: 'Guests',
      child: BeakRelationBlock(CalendarEventRelations.guests),
    ),
  ],
);
