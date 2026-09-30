# Multi-step forms

> Present one form draft as validated steps with BeakWizardScreen, reuse sections between a wizard and a detail page, and link a review back to its step.

After this page you can turn a form into a wizard, choose between the compact and the rail layout, and let a review step send people back to the step they want to fix.

A wizard is not a second form. It is the same draft, the same validation and the same save, shown one step at a time. Moving between steps keeps every value and every staged related row, so you never merge partial results at the end.

## At a glance

The shop's order wizard is a `BeakWizardScreen` with steps that come from shared sections:

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
/// A staged order draft presented in four validated steps.
final class OrderFormWizardScreen extends BeakWizardScreen {
  /// Fetching, relationship state, validation and saving are automatic.
  OrderFormWizardScreen()
    : super(
        steps: orderSteps(),
        drafts: shopDrafts('order'),
        reviewBeforeSave: true,
      );
}

/// Shared structure for both the wizard and tabbed order detail view.
List<BeakWizardStep> orderSteps() => orderSections().steps;
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
| Clicking the next step in the rail | The same as Continue. `goToStep` with a target further ahead validates every step in between and stops at the first invalid one |
| Back | Never validates. Values, staged rows and errors are kept |
| Finish | Validates all steps, then saves. If a step fails validation, the wizard opens the first step with an error and keeps the draft |
| Edit link in a review | Jumps back to the step. It does not validate, because it only goes backwards |

The rail lets you click any earlier step and the next one, not further ahead. Navigation is refused while a save is running, while its result is unknown, and while an unfinished stored draft waits to be resumed or discarded.

`session.goToStep(index)` is the single operation behind all of these, and `state.stepIndex` is readable from any condition. A summary can hide itself on the review step with `visibleIf: (state) => state.stepIndex != 4`.

## Writing a step

A `BeakWizardStep` is a layout with a title and some optional text. Foodio's dishes step uses most of it:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_dishes_step.dart"
/// Menu selection and allergy confirmation step.
BeakWizardStep dishesStep() => BeakWizardStep(
  title: 'Dishes',
  heading: 'Choose dishes',
  introductionBuilder: (state, format) =>
      'From the menu plan ${state.asOrder.profile?.menuPlan?.name ?? 'for this profile'} for ${format.date((state.asOrder.deliveryDate ?? const FoodioClock().today).toDateTime(), pattern: 'EEE d MMM')}.',
  dependencies: [OrderModel.profile.menuPlan.name, OrderModel.deliveryDate],
  spacingInPixels: 24,
  continueLabel: 'Continue to payment',
  description: 'From the menu plan',
  completedDescription: (state, format) {
    final portions = state
        .rows(OrderModel.items)
        .fold<int>(0, (sum, row) => sum + (row.asOrderItem.quantity ?? 0));
    return '$portions dishes · ${format.format(money(orderTotals(state).subtotalCents), BeakValueFormat.currency)}';
  },
  footerHint:
      'Prices include VAT. You can change the order until 10:30 on the delivery day.',
  children: [
    orderItems(catalog: true),
    OrderModel.allergyAcknowledged.inputToggle(
      label: 'Allergen notes reviewed with the customer',
      visibleIf: (state) => state.asOrder.strictAllergy == true,
    ),

    OrderModel.customerNote.inputText(
      label: 'Note for the kitchen',
      visibleIf: (state) => (state.asOrder.customerNote?.isNotEmpty ?? false),
    ),
  ],
);
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
/// Five stages over one draft; the final action saves the complete order graph.
BeakWizardScreen orderWizard() => BeakWizardScreen(
  roles: const {BeakScreenRole.create},
  fullScreen: true,
  navigation: BeakWizardNavigation.rail,
  navigationDescription:
      "Places an order on a customer's behalf, for example during a phone call.",
  header: const BeakFormHeader(title: 'New order'),
  submitAction: OrderActions.place,
  submitLabel: 'Place order',
  drafts: const BeakFormDrafts(
    store: BeakBrowserDraftStore(),
    key: 'foodio-order',
    context: 'foodio-demo:marie-novak',
    schemaVersion: 1,
  ),
  aside: BeakFormLayout(children: [orderSummary(), orderReviewAside()]),
  asideFooter: orderSummaryFooter(),
  steps: [
    customerAndProfileStep(),
    deliveryStep(),
    dishesStep(),
    paymentAndVouchersStep(),
    orderReviewStep(),
  ],
);
```

- `fullScreen: true` gives the wizard the whole protected route and no panel shell. Authentication and the unsaved-changes guard stay.
- `header`, `aside`, `asideFooter` and `footer` are ordinary form nodes over the same draft. A `BeakFormSummary` in the aside reads the same values as the inputs in the steps. [Workflow presentations](workflow-presentations.md) covers what to put there.
- `submitAction` names a `BeakModelAction`. The last step's primary button runs it with the whole graph, collecting its arguments in a dialog if it declares an input model, and `submitLabel` names the button. Without `submitAction` the last step saves, and the button reads Finish. The command is left out of the secondary toolbar.
- On a narrow screen the rail becomes a step selector and the aside opens in a sheet. The rail layout needs a bounded height, which a routed page or a dialog provides.

## A review that sends you back

A review step shows the answers again and links each block to its step. `BeakReviewSection` renders its children read-only and adds an Edit link that calls `goToStep(stepIndex)`:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/order_review_step.dart"
BeakReviewSection(
  title: 'Customer & profile',
  stepIndex: 0,
  padding: const EdgeInsets.symmetric(vertical: 12),
  contentPadding: const EdgeInsets.only(top: 2),
  dividerSpacingInPixels: 0,
  titleStyle: _reviewHeading,
  children: [
    BeakFormTemplate(
      template: BeakRecordTemplate(
        title: BeakValueBinding.field(
          OrderModel.customer.name,
          strong: true,
        ),
        textGapInPixels: 0,
        titleMetadata: [
          BeakValueBinding.field(
            OrderModel.customer.email,
            textStyle: _reviewText,
          ),
        ],
        inlineSubtitle: true,
        subtitle: [
          BeakValueBinding.field(
            OrderModel.profile.name,
            textStyle: _reviewText,
          ),
          BeakValueBinding.field(
            OrderModel.profile.role,
            textStyle: _reviewText,
          ),
        ],
      ),
    ),
  ],
),
```

`stepIndex` is zero-based. Omit it for a block with no link. The review reads the draft, so an answer changed in step 1 is already changed here. The dishes block in Foodio's review is not a copy of the table, it is the same `tableForm` again with `readOnly: true`, which is allowed because only one placement of a field may be editable.

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Same draft | Every step edits the one session. Nothing is saved between steps, and abandoning the wizard follows the form's `drafts` policy |
| Not all parameters | `BeakWizardScreen` forwards 26 of the 29 parameters of `BeakFormScreen`. `layout` (the steps are the layout), `recordHeader` and `editingLabel` (both belong to the single-page heading) are missing. Write `BeakFormScreen(steps: [...])` when you need one. A test fails when a `BeakFormScreen` parameter is neither forwarded nor on that list |
| No page frame | A screen with steps has no generated page frame with a record heading, so record actions such as a print button do not appear. `showBack`, `pagePadding` and `pageGapInPixels` still shape the page chrome, except with `fullScreen: true`, which has no page chrome at all |
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

```bash
cd examples/foodio-adminpanel
flutter test test/order_wizard_presentation_test.dart
```

Each ends with `All tests passed!`. To try it, run the shop (API on port 8080), open Orders and press Create: the first Continue is blocked until a customer is chosen.

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
