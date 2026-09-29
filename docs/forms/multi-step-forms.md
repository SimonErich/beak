---
title: Multi-step forms
description: Present one form draft as validated steps with BeakWizardScreen, reuse sections between a wizard and a detail page, and link a review back to its step.
type: guide
audience: [beginner, expert]
status: stable
---

# Multi-step forms

After this page you can turn a form into a wizard, choose between the compact and the rail layout, and let a review step send people back to the step they want to fix.

A wizard is not a second form. It is the same draft, the same validation and the same save, shown one step at a time. Moving between steps keeps every value and every staged related row, so you never merge partial results at the end.

## At a glance

The shop's order wizard is a `BeakWizardScreen` with steps that come from shared sections:

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart:orderWizardScreen"
```

The constructor has three parameters and no controller:

- `steps` are `BeakWizardStep` nodes. `orderSteps()` takes them from `orderSections().steps`, so the same sections can also become tabs, see [Form screens](form-screens.md#one-set-of-sections-three-presentations).
- `drafts` lets someone leave and resume, see [Drafts, review and conflicts](drafts-and-review.md).
- `reviewBeforeSave` shows the "Review changes" dialog before the save is sent.

Register it in the resource's `screens:` list. It serves `create` and `edit` unless you give `roles`, so the same wizard also edits an existing order.

## What Continue, Back and Finish do

| Action | Behavior |
| --- | --- |
| Continue | Validates the current step and every step before it. On success the wizard advances and marks the step done. Errors in later steps stay hidden until you reach them |
| Clicking a later step in the rail | The same as Continue, for every step in between. The first invalid step is shown and the jump stops there |
| Back | Never validates. Values, staged rows and errors are kept |
| Finish | Validates all steps, then saves. If a step fails validation, the wizard opens the first step with an error and keeps the draft |
| Edit link in a review | Jumps back to the step. It does not validate, because it only goes backwards |

The rail lets you click any earlier step and the next one, not further ahead. Navigation is refused while a save is running, while its result is unknown, and while an unfinished stored draft waits to be resumed or discarded.

`session.goToStep(index)` is the single operation behind all of these, and `state.stepIndex` is readable from any condition. A summary can hide itself on the review step with `visibleIf: (state) => state.stepIndex != 4`.

## Writing a step

A `BeakWizardStep` is a layout with a title and some optional text. Foodio's dishes step uses most of it:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_dishes_step.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_dishes_step.dart:dishesStep"
```

| Parameter | Inline navigation | Rail navigation |
| --- | --- | --- |
| `title` | The title beside a `2 / 4` counter | The step's name in the rail |
| `description` | Under that line | Under the name in the rail |
| `heading`, `introduction` | Not shown | The pinned header above the inputs. They fall back to `title` and `description` |
| `introductionBuilder` | Not shown | Live introduction text from the draft |
| `continueLabel` | Replaces "Next" | Replaces "Continue" |
| `completedDescription` | Not shown | Replaces the rail description once the step is done, so the rail summarizes the answers |
| `footerHint`, `footerHintBuilder` | Not shown | Text between Back and Continue. Without one the rail says `Step 2 of 5` |
| `dependencies` | Loads fields the builders read | The same |

`introductionBuilder`, `footerHintBuilder` and `completedDescription` receive the live draft and the panel's formatting policy, so a date or an amount in the text follows the panel's locale and currency. List the related fields they read in `dependencies`, or the session loads them only after the first edit. Simple scalar values of the record are always there.

These callbacks produce text. They do not change validation or navigation.

## Compact or rail

`navigation` picks the chrome. Both are the same wizard.

| Value | You get |
| --- | --- |
| `BeakWizardNavigation.inline` (default) | The current step title above the inputs, and Previous and Next buttons |
| `BeakWizardNavigation.rail` | A step rail with completed summaries, a pinned step header, pinned actions, and room for an `aside` |

The rail is what Foodio's order wizard uses. It runs full screen, adds a summary column beside the steps, pins the totals below it, and places the order through a named model command instead of a plain save:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/order_wizard_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/order_wizard_screen.dart:orderWizard"
```

- `fullScreen: true` gives the wizard the whole protected route and no panel shell. Authentication and the unsaved-changes guard stay.
- `header`, `aside`, `asideFooter` and `footer` are ordinary form nodes over the same draft. A `BeakFormSummary` in the aside reads the same values as the inputs in the steps. [Workflow presentations](workflow-presentations.md) covers what to put there.
- `submitAction` names a `BeakModelAction`. The last step's primary button runs it with the whole graph, collecting its arguments in a dialog if it declares an input model, and `submitLabel` names the button. Without `submitAction` the last step saves, and the button reads Finish. The command is left out of the secondary toolbar.
- On a narrow screen the rail becomes a step selector and the aside opens in a sheet. The rail layout needs a bounded height, which a routed page or a dialog provides.

## A review that sends you back

A review step shows the answers again and links each block to its step. `BeakReviewSection` renders its children read-only and adds an Edit link that calls `goToStep(stepIndex)`:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/order_review_step.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/order_review_step.dart:reviewCustomerSection"
```

`stepIndex` is zero-based. Omit it for a block with no link. The review reads the draft, so an answer changed in step 1 is already changed here. The dishes block in Foodio's review is not a copy of the table, it is the same `tableForm` again with `readOnly: true`, which is allowed because only one placement of a field may be editable.

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Same draft | Every step edits the one session. Nothing is saved between steps, and abandoning the wizard follows the form's `drafts` policy |
| Not all parameters | `BeakWizardScreen` forwards 22 of the 29 parameters of `BeakFormScreen`. `layout`, `asideFraction`, `submitIcon`, `outlinedCancel`, `showActionsWhileEditing`, `editingLabel` and `showChangeBar` are missing. Write `BeakFormScreen(steps: [...])` when you need one |
| No page frame | A screen with steps has no generated page frame. `showBack`, `pagePadding` and `pageGapInPixels` have no effect, `recordHeader` is not placed, and record actions such as a print button do not appear |
| Hidden steps stay | `visibleIf` on a step hides its contents. The step itself stays in the navigation as an empty page. Put the condition on the content |
| Cancel | On a routed page the first step has a Cancel button that leaves through the unsaved-changes dialog. Later steps have Back |
| Steps and roles | A wizard defaults to `create` and `edit`. Add `read` only if you also give the show page a layout |
| Server rules | The server validates the graph again on save. A step check that only lives in `validators:` is a usability rule, not an integrity rule |

## Verify it

The wizard runtime has package tests, and the shop's order test drives the real wizard against an in-process API:

```bash
cd packages/beak_frontend
flutter test test/src/form/beak_wizard_form_test.dart test/src/form/wizard_navigation_details_test.dart
```

```bash
cd examples/clean_beak_config
flutter test test/order_form_test.dart
```

Both end with `All tests passed!`. To try it, run the shop (API on port 8080), open Orders and press Create: the first Continue is blocked until a customer is chosen.

## Reference

| Symbol | Where it is documented |
| --- | --- |
| `BeakWizardScreen`, `BeakWizardNavigation` | [Screens and form layouts](../reference/screens-and-layouts.md#beakwizardscreen) |
| `BeakWizardStep`, `BeakReviewSection`, `BeakFormSections` | [Screens and form layouts](../reference/screens-and-layouts.md#beakwizardstep) |
| `BeakFormReader.stepIndex`, `BeakFormSession.goToStep` | [Screens and form layouts](../reference/screens-and-layouts.md#beakformreader) |
| A shorter walkthrough | [A multi-step form](../recipes/a-multi-step-form.md) |

## Continue reading

- [Workflow presentations](workflow-presentations.md) headers, summaries, record templates and catalogs around the steps.
- [Related records in forms](related-records.md) the table editors and pickers a step usually contains.
- [Drafts, review and conflicts](drafts-and-review.md) resuming a wizard and recovering an interrupted save.
- [Actions](../panel/actions.md) the named commands a wizard can submit through.
