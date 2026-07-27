---
title: Multi-step forms
description: How to break a long create/edit form into validated wizard steps with BeakFormStep and a resource's formSteps.
---

# Multi-step forms

After this page you can turn a long form into a paced wizard: a handful of explained steps, each entering its own columns, with per-step validation that gates the advance and the final step submitting.

Some entities are too big for one scroll. A calendar event has a name, a schedule, a place, and organizing details. Rather than one wall of fields, you describe the form as a list of `BeakFormStep`s and hand them to a resource as `formSteps`. Beak renders the create and edit routes as an `OiWizard`, one page per step. The form is still generated from the model; you are only grouping and pacing its fields.

## A step

`BeakFormStep` is an immutable value: a titled group of the model's columns with optional supporting copy and an indicator icon. Like a form section, listing a column here both selects and orders it; columns in no step carry no field.

```dart title="packages/beak_frontend/lib/src/form/beak_form_step.dart"
@immutable
final class BeakFormStep {
  const BeakFormStep({
    required this.title,
    required this.columns,
    this.subtitle,
    this.description,
    this.icon,
  });

  /// The step label shown in the indicator.
  final String title;

  /// The model columns entered on this step, in order.
  final List<BeakColumn> columns;

  /// Supporting copy under the step title in the indicator.
  final String? subtitle;

  /// A longer explanation rendered at the top of the step body.
  final String? description;

  /// The step's indicator icon.
  final IconData? icon;
}
```

The fields, in one table:

| Field | What it does |
| --- | --- |
| `title` | The step label in the stepper indicator. Also the section title inside the form. |
| `columns` | The model columns entered on this step, in order. Columns in no step get no field. |
| `subtitle` | Supporting copy under the title in the indicator. |
| `description` | A longer explanation rendered as an info banner at the top of the step body. |
| `icon` | The step's indicator icon (an `OiIcons` value). |

## A wizard, step by step

The showcase app breaks its "new event" flow into four steps: free text, then the schedule with an all-day switch, then place and links, then category, organizer, and color. This is the whole definition, wired onto the Calendar Events resource in the superdashboard (port 8180):

```dart title="examples/superdashboard/lib/panel/forms/calendar_event_form.dart"
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
```

## Wiring it onto a resource

Set `formSteps` on the resource. The generated create and edit pages pass it straight to the form, and `formSteps` takes precedence over a `formLayout`.

```dart title="examples/superdashboard/lib/panel/resources.dart"
BeakResource(
  model: CalendarEventModel(),
  icon: BeakIconToken(OiIcons.calendar),
  section: 'Projects',
  detail: calendarEventDetail,
  formSteps: calendarEventFormSteps,
  // ...view modes
),
```

That is the entire opt-in. The same resource keeps a custom `detail` for its show page; `formSteps` only changes the shape of the create and edit form.

!!! note "What just happened"
    - You described the form as a list of steps, not a widget tree.
    - Beak read the resource's `formSteps` and rendered an `OiWizard` with one page per step.
    - Each step's `columns` became the same typed fields a flat form would build, just paced.

## Per-step validation

The wizard validates one step at a time. When the user asks to advance, the step's gate checks whether every field on that step currently passes its rules. If it does, the wizard moves on; if it does not, a warning banner appears and only that step's fields paint their specific errors. Later steps stay pristine, so a user is never scolded for fields they have not reached.

```dart title="packages/beak_frontend/lib/src/form/beak_data_form.dart"
OiWizardStep(
  title: step.title,
  subtitle: step.subtitle,
  icon: step.icon,
  validate: (_) {
    final bool ok = _isStepValid(controller, step);
    blockedStep.value = ok ? null : step.title;
    if (!ok) {
      // The user asked to advance: now (and only now) run the real
      // validators on this step's fields so they paint their
      // specific errors. Later steps stay pristine.
      for (final column in step.columns) {
        if (controller.hasFieldFor(column)) {
          unawaited(
            controller.validate(field: controller.slotOf(column)),
          );
        }
      }
    }
    return ok;
  },
  // ...builder
),
```

The gate itself is a silent read of the typed rules, so a pristine form never shows errors the user has not earned:

```dart title="packages/beak_frontend/lib/src/form/beak_data_form.dart"
bool _isStepValid(BeakFormController controller, BeakFormStep step) {
  var valid = true;
  for (final column in step.columns) {
    if (!controller.passesRules(column)) {
      valid = false;
    }
  }
  return valid;
}
```

`passesRules` evaluates a column's rules directly, without running the autoforms error pipeline, so checking a step never reveals error text on an untouched field. Hidden and unregistered fields pass vacuously. The rule-to-message mirroring is identical to a flat form: see [Forms](forms.md#rules-mirror-the-server-message-for-message).

The final step submits through the shared controller, exactly as a flat form's submit button does:

```dart title="packages/beak_frontend/lib/src/form/beak_data_form.dart"
return OiWizard(
  onComplete: (_) => controller.submit(),
  steps: [
    // ...
  ],
);
```

!!! question "What this skipped"
    - The flat form and its field mapping: [Forms](forms.md).
    - A layout that structures the form like the show page instead of stepping it: [Detail views and dual-mode blocks](detail-and-dual-mode.md).
    - What each column's rules actually check: [Validation rules](../models/validation-rules.md).

## Continue reading

- [Forms](forms.md) the flat form this page paces, and how columns become fields.
- [Detail views and dual-mode blocks](detail-and-dual-mode.md) an alternative structure that mirrors the show page.
- [Resources](resources.md) where `formSteps` is declared.
- [Validation rules](../models/validation-rules.md) the rules each step gate reads.
