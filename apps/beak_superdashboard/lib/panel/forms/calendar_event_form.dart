import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

/// A multi-step "new event" wizard over the calendar-event model: the long
/// create form broken into four explained steps, each grouping a different
/// kind of input — free text, date/time pickers with an all-day switch, place
/// and link fields, then category/organizer pickers and a color.
///
/// Wired onto the Calendar Events resource as `formSteps`, so its Create and
/// Edit routes render as an `OiWizard` with per-step validation.
const List<BeakFormStep> calendarEventFormSteps = [
  BeakFormStep(
    title: 'Details',
    subtitle: 'Name & description',
    icon: OiIcons.fileText,
    description:
        'Give the event a clear name and a short description so invitees know '
        'what it is about. The title is required.',
    columns: [CalendarEventColumns.title, CalendarEventColumns.description],
  ),
  BeakFormStep(
    title: 'Schedule',
    subtitle: 'When it runs',
    icon: OiIcons.calendarClock,
    description:
        'Pick the start and end times. Turn on “All day” for events that span '
        'whole days without a specific time. A start time is required.',
    columns: [
      CalendarEventColumns.startAt,
      CalendarEventColumns.endAt,
      CalendarEventColumns.allDay,
    ],
  ),
  BeakFormStep(
    title: 'Place',
    subtitle: 'Where & links',
    icon: OiIcons.mapPin,
    description:
        'Add a location and, if there is one, a link people can follow to '
        'join or read more about the event.',
    columns: [CalendarEventColumns.location, CalendarEventColumns.url],
  ),
  BeakFormStep(
    title: 'Organize',
    subtitle: 'Category, owner & color',
    icon: OiIcons.tag,
    description:
        'Assign a category and an organizer, then choose a color so the event '
        'stands out on the calendar grid.',
    columns: [
      CalendarEventColumns.categoryId,
      CalendarEventColumns.organizerId,
      CalendarEventColumns.color,
    ],
  ),
];
