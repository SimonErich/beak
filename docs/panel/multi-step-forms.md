---
title: Multi-step forms
description: How to break a long create/edit form into validated wizard steps with BeakFormStep and a resource's formSteps.
---

# Multi-step forms

After this page you can turn a long form into a paced wizard: a handful of
explained steps, each entering its own columns, with per-step validation that
gates the advance and a final step that submits.

Some entities are too big for one scroll. An order has a customer, a reference
and a status, money and a date, and delivery notes. Rather than one wall of
fields, you describe the form as a list of `BeakFormStep`s and hand them to the
resource as `formSteps`. Beak renders the create and edit routes as an
`OiWizard`, one page per step. The fields still come from the schema class; you
are only grouping and pacing them.

## A step

`BeakFormStep` is an immutable value: a titled group of the model's columns with
optional supporting copy and an indicator icon. Like a form section, listing a
column here both selects and orders it; columns in no step carry no field.

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

The columns are the `static const` constants `beak prepare` generated from the
schema class, so `OrderColumns.reference` is a compile-time reference to a real
column and a renamed field breaks the build instead of the wizard.

## A wizard, step by step

The store breaks its "new order" flow into four steps: who is buying, then the
reference and status, then the money, then anything the courier needs. This is
the whole thing, and bar its imports it is the whole file:

```dart title="examples/store/lib/resources/orders.dart"
/// The orders resource: a wizard instead of one long form.
///
/// A create form with nine inputs is a wall; four explained steps is a
/// conversation. Each step validates before the next unlocks, and every form
/// column appears in exactly one of them.
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  formSteps: const [
    BeakFormStep(
      title: 'Customer',
      subtitle: 'Who is buying',
      icon: OiIcons.user,
      description:
          'Pick the customer this order belongs to. Their past orders appear '
          'on their own page once this one is saved.',
      columns: [OrderColumns.customerId],
    ),
    BeakFormStep(
      title: 'Order',
      subtitle: 'Reference & status',
      icon: OiIcons.receipt,
      description:
          'The reference is what the customer quotes when they write in, so '
          'it has to be unique. Status drives the badge on the list.',
      columns: [OrderColumns.reference, OrderColumns.status],
    ),
    BeakFormStep(
      title: 'Money',
      subtitle: 'Total & date',
      icon: OiIcons.creditCard,
      description:
          'The total is the amount actually charged, including shipping — '
          'the lines below it are what was bought.',
      columns: [OrderColumns.total, OrderColumns.placedAt],
    ),
    BeakFormStep(
      title: 'Delivery',
      subtitle: 'Anything the courier needs',
      icon: OiIcons.truck,
      description: 'Optional. Gate codes, delivery windows, doorbell names.',
      columns: [OrderColumns.notes],
    ),
  ],
);
```

!!! note "What just happened"
    - You described the form as a list of steps, not a widget tree.
    - Beak read the resource's `formSteps` and rendered an `OiWizard` with one
      page per step.
    - Each step's `columns` became the same typed fields a flat form would
      build, only paced.
    - Everything else about the orders resource (its model, label, icon,
      section, filters and show page) stayed generated.

## Wiring it onto a resource

There is no `BeakResource` to edit. `formSteps` lives in
`lib/resources/<table>.dart`, the file that takes the generated resource and
returns a changed copy. Create it with the CLI:

```bash
beak eject resource orders
```

That writes `lib/resources/orders.dart` with a `beakResource` function returning
`generated` unchanged. Add `formSteps` to the `copyWith` and run `beak prepare`;
the generator notices the file and routes the orders resource through it:

```dart title="examples/store/lib/beak/panel.g.dart"
resource_orders.beakResource(
  BeakResource(
    model: const OrderModel(),
    icon: BeakIconToken(OiIcons.receipt),
    section: 'Sales',
  ),
),
```

The generated create and edit pages pass the steps straight to the form, and
`formSteps` takes precedence over a `formLayout`. A resource can combine the
wizard with a custom show page and extra view modes in the same call, as the
superdashboard's calendar events do:

```dart title="examples/superdashboard/lib/resources/calendar_events.dart"
--8<-- "examples/superdashboard/lib/resources/calendar_events.dart:beakResource"
```

Its four steps live in a file of their own, which is worth doing once the list
grows past a screenful:

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
  // ...schedule, place, organize
];
```

## Per-step validation

The wizard validates one step at a time. When the user asks to advance, the
step's gate checks whether every field on that step currently passes its rules.
If it does, the wizard moves on; if it does not, a warning banner appears and
only that step's fields paint their specific errors. Later steps stay pristine,
so a user is never scolded for fields they have not reached.

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
      // specific errors — later steps stay pristine.
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

The gate itself is a silent read of the typed rules, so a pristine form never
shows errors the user has not earned:

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

`passesRules` evaluates a column's rules directly, without running the autoforms
error pipeline, so checking a step never reveals error text on an untouched
field. Hidden and unregistered fields pass vacuously. Those rules are the ones
the schema class declared: `rules: [BeakMaxLength(40)]` on a field, plus the
`BeakRequired()` a non-nullable type implies. The rule-to-message mirroring is
identical to a flat form: see
[Forms](forms.md#rules-mirror-the-server-message-for-message).

The final step submits through the shared controller, exactly as a flat form's
submit button does:

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
    - A layout that structures the form like the show page instead of stepping
      it: [Detail views and dual-mode blocks](detail-and-dual-mode.md).
    - What each column's rules actually check:
      [Validation rules](../models/validation-rules.md).

## Continue reading

- [Forms](forms.md) the flat form this page paces, and how columns become fields.
- [Detail views and dual-mode blocks](detail-and-dual-mode.md) an alternative structure that mirrors the show page.
- [Resources](resources.md) the file `formSteps` is declared in, and everything else it can change.
- [Escape hatches](../models/escape-hatches.md) the four ways to take over from a generated default, narrowest first.
- [Validation rules](../models/validation-rules.md) the rules each step gate reads.
