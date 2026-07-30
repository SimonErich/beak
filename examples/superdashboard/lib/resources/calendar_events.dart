import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

import '../panel/details/details.dart';
import '../panel/forms/calendar_event_form.dart';

/// The calendar events resource, with the parts Beak cannot derive.
///
/// Its model, label, icon and section still come from the schema class and
/// `beak.yaml`; this adds what a person decided.
// --8<-- [start:beakResource]
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: calendarEventDetail,
  formSteps: calendarEventFormSteps,
  viewModes: [
    const BeakTableView(),
    const BeakCalendarView(
      titleField: CalendarEventColumns.title,
      startField: CalendarEventColumns.startAt,
      endField: CalendarEventColumns.endAt,
      allDayField: CalendarEventColumns.allDay,
    ),
  ],
);

// --8<-- [end:beakResource]
