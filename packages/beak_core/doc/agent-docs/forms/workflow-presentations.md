# Workflow presentations

> Compose headers, record templates, summaries, metrics, progress, timelines and inline commands around a form, all reading the one draft.

After this page you can build the chrome of a real workflow around a form: a summary that follows the basket, a budget bar, a progress trail, a note timeline, an inline command. You will also know what these nodes cannot do.

Every one of them is a `BeakFormNode` that reads the same draft as the inputs. There is no second controller, no query owner of its own and no save handler. That is a hard constraint, and it is why a summary in the aside always agrees with the step you are typing in.

Foodio's order screens are the reference for all of it. The order wizard and the order detail page are built from these nodes.

## At a glance

| Node | Shows | Typical place |
| --- | --- | --- |
| `BeakFormHeader` | Workflow title, guarded close, Save as draft | `header` of a wizard |
| `BeakFormTemplate` | A record's identity from a `BeakRecordTemplate` | Anywhere |
| `BeakFormPlaceholder` | Neutral block for content that waits on another choice | Where a template will appear |
| `BeakFormSummary` | Label and value rows, totals | `aside`, `asideFooter` |
| `BeakFormMetrics` | A strip of figures | `header` of a detail page |
| `BeakFormCapacity` | A used-of-total bar with a warning threshold | Next to totals |
| `BeakFormNotice` | A message that appears when a condition holds | Anywhere |
| `BeakFormProgress` | Milestones along an enum field | Detail page body |
| `BeakFormTimeline` | A to-many history relation, or a message thread | `aside` of a detail page |
| `BeakFormLinks` | Call, mail and web actions from typed values | Beside an identity |
| `BeakFormActions`, `BeakFormActionInput` | Model commands, and a command's arguments inline | Cards and asides |
| `BeakFormLock` | A disabled control with the reason | Where an action is unavailable |
| `BeakModeLayout` | One tree for read, another for edit | Any region |
| `BeakFormWidget` | Any widget, with the draft | The escape hatch |

The regions they go into are the `header`, `aside`, `asideFooter` and `footer` parameters of `BeakFormScreen` (and of `BeakWizardScreen`), or directly inside `layout` or a step. Parameters of each node are in [Screens and form layouts](../reference/screens-and-layouts.md#presentation-nodes).

## One draft, many readers

Every callback in a presentation node receives a `BeakFormReader`. Four things matter:

- `state.read(OrderModel.deliveryDate)` returns a typed value and records the dependency, so the node repaints when that field changes.
- `state.asOrder.customer?.name` is the generated typed view of the same reader. Both spellings read the same thing.
- `state.rows(OrderModel.items)` returns readers over the current rows of a collection, staged additions and removals included.
- `state.draft.initialRecord` is the record as it was loaded. Comparing it with the draft gives "was 12:00" captions and price deltas without extra state.

One rule comes with them: a value from a related record is loaded only if some node declared it. Inputs and templates declare their fields automatically. A computed value in a summary, a metric or a notice lists the related fields it reads in `dependencies`. Forget one and the value is empty, not an error. A node whose declared dependencies include a field the account cannot read is not shown at all.

## The frame

Foodio's new-order wizard is a `BeakWizardScreen` with `header`, `aside` and `asideFooter`. [Multi-step forms](multi-step-forms.md#compact-or-rail) shows the constructor. What goes into the regions is below.

`BeakFormHeader(title: 'New order')` gives the wizard a close button that goes through the unsaved-changes dialog, and, when the screen has `drafts`, a Save as draft button and a "Draft saved 14:03" note. It never creates a record only to keep progress. `showDraftSavedAt: false` hides the note.

The aside is one layout that holds the summary. `asideFooter` pins the totals below it while the summary scrolls. On narrow screens the aside collapses into a sheet.

## Record templates

A `BeakRecordTemplate` is a typed description of how to show one record: a title, secondary lines, badges, an avatar or icon, detail rows, a footnote, a progress bar. The same template draws an option in a picker, a row in a table, a header on a detail page and a `BeakFormTemplate` in the aside. It reads values through `BeakValueBinding`.

| Binding | Use it for |
| --- | --- |
| `BeakValueBinding.field(OrderModel.customer.name)` | A generated field, including a related path. It formats like a table cell |
| `BeakValueBinding<String>.computed(dependencies: [...], compute: (row) => ...)` | A pure calculation. `dependencies` is required and lists every field `compute` reads |

Bindings carry presentation options: `strong`, `monospace`, `color`, `badge` with `tone`, `icon`, `maxLines`, `textStyle`, `visibleIf` and a `display` callback that formats with the panel's policy. `maxLines: null` wraps the full value. Every binding's dependencies join the template's field list, and that list becomes the eager load. A template therefore costs one query, not one per cell.

The detail page heading is a template:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart"
recordHeader: BeakRecordTemplate(
  icon: const BeakValueBinding<IconData>.computed(
    dependencies: [],
    compute: orderIcon,
  ),
  iconSizeInPixels: 56,
  identityGapInPixels: 16,
  copyableTitle: true,
  title: BeakValueBinding.field(
    OrderModel.reference,
    strong: true,
    monospace: true,
    textStyle: const TextStyle(
      fontSize: 30,
      height: 40 / 30,
      fontWeight: FontWeight.w500,
      letterSpacing: -.3,
    ),
  ),
  badges: [orderStatus()],
  subtitle: [
    BeakValueBinding.field(OrderModel.customer.name),
    BeakValueBinding.field(OrderModel.profile.name),
    BeakValueBinding<DateTime>.field(
      OrderModel.placedAt,
      display: (value, format) => value == null
          ? format.emptyValue
          : 'placed ${format.date(value) == format.date(const FoodioClock().now) ? 'today ${format.time(value)}' : format.dateTime(value)}',
    ),
    BeakValueBinding.field(OrderModel.source, label: 'via'),
  ],
),
```

`BeakFormTemplate(template: ...)` places a template anywhere in a layout. `BeakFormPlaceholder(label: ...)` is a neutral block for content that is not there yet, and with a `template` it previews the record that will fill the spot. The wizard's summary swaps a placeholder that reads "Delivery not set" for the delivery template as soon as a slot is chosen. Templates in pickers are covered in [Related records in forms](related-records.md).

## Totals: summaries, capacity and notices

`BeakFormSummary` is a list of `BeakSummaryLine`s. With `source: OrderModel.items` it repeats its lines once per live row, staged rows included, and each line's callbacks and dependencies are relative to the row model:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/order_summary_layout.dart"
BeakFormPlaceholder(
  label: 'No dishes yet',
  visibleIf: (state) => state.rows(OrderModel.items).isEmpty,
),
BeakFormSummary(
  source: OrderModel.items,
  gapInPixels: 8,
  visibleIf: (state) => state.rows(OrderModel.items).isNotEmpty,
  lines: [
    BeakSummaryLine(
      label: 'Dish',
      dependencies: [
        OrderItemModel.quantity,
        OrderItemModel.label,
        OrderItemModel.variantName,
        OrderItemModel.unitPriceCents,
        OrderItemModel.fields.options,
      ],
      labelBuilder: (state, _) =>
          '${state.asOrderItem.quantity ?? 0} × ${_basketLabel(state.asOrderItem.label)} · ${state.asOrderItem.variantName ?? ''}',
      value: (state) => money(
        (state.asOrderItem.quantity ?? 0) *
            ((state.asOrderItem.unitPriceCents ?? 0) +
                state
                    .rows(OrderItemModel.fields.options)
                    .fold<int>(
                      0,
                      (sum, option) =>
                          sum +
                          (option.asOrderItemOption.unitPriceCents ??
                              0),
                    )),
      ),
      format: BeakValueFormat.currency,
      valueStyle: gabelNumericBodyStyle,
    ),
  ],
),
```

A line has a `label` or `labelBuilder`, a `value`, a `format`, and options for `emphasized`, `dividerBefore`, `subtitle` and `valueLabel`. Return an exact `BeakDecimal` for money (Foodio's `money(cents)` helper builds one), and `BeakValueFormat.currency` formats it with the panel's locale and currency.

A capacity bar and a notice sit under the totals in Foodio's footer:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/order_summary_layout.dart"
BeakFormCapacity(
  label: 'Company budget this month',
  dependencies: [OrderModel.profile.budgets],
  visibleIf: (state) =>
      budgetFor(state) != null && state.rows(OrderModel.items).isNotEmpty,
  value: (state) => companyBudgetContribution(state) / 100,
  max: (state) => availableBudgetForOrder(state) / 100,
  format: BeakValueFormat.currency,
  showLabel: false,
  showValue: false,
  heightInPixels: 8,
  caption: (state, format) {
    final current = companyBudgetContribution(state);
    final available = availableBudgetForOrder(state);
    return 'Uses ${format.format(money(current), BeakValueFormat.currency)} of the ${format.format(money(available), BeakValueFormat.currency)} left this month';
  },
),
BeakFormNotice(
  title: 'Needs approval',
  titleBuilder: (state) =>
      'Needs approval by ${state.asOrder.profile?.approver?.name ?? 'the company approver'}',
  tone: BeakColor.warning,
  visibleIf: (state) =>
      state.stepIndex != 4 &&
      state.asOrder.profile?.kind == 'company' &&
      orderTotals(state).grossCents >
          (state.asOrder.profile?.approvalThresholdCents ?? 4000),
  dependencies: [OrderModel.profile.approver.name],
  message: (state) =>
      '€${BeakDecimal(orderTotals(state).grossCents, scale: 2)} is over the €${BeakDecimal(state.asOrder.profile?.approvalThresholdCents ?? 0, scale: 2)} rule.',
),
```

`BeakFormCapacity` turns `value / max` into a bar, with a warning treatment past `warningThreshold` (0.9 by default). `BeakFormNotice` is a message you gate with `visibleIf`, and `titleBuilder`, `message` and `caption` all read the draft.

None of these is validated or submitted. They display. A limit that must hold is a model rule, enforced by the server.

## Metrics and the saved baseline

`BeakFormMetrics` is a joined strip of figures. Each `BeakFormMetric` has a live `value`, a `subtitle` and a `flex`. Foodio's detail page uses the subtitle to compare with what was loaded:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart"
BeakFormMetric(
  valueStyle: gabelNumericMetricStyle,
  label: 'Total',
  value: (state) => money(orderTotals(state).grossCents),
  format: BeakValueFormat.currency,
  flex: 7,
  subtitle: (state, format) {
    final total = orderTotals(state);
    final before = OrderModel.grossCents.readFrom(
      state.draft.initialRecord,
    );
    final delta = total.grossCents - (before ?? total.grossCents);
    return '${delta == 0 ? '' : '${delta > 0 ? '+' : '−'}${format.currency(delta.abs() / 100)} · '}incl. ${format.currency(total.taxCents / 100)} VAT';
  },
),
BeakFormMetric(
  valueStyle: const TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
  ),
  label: 'Delivery',
  flex: 7,
  value: (state) =>
      '${state.asOrder.deliveryDate == const FoodioClock().today ? 'Today, ' : ''}${state.asOrder.slot?.name ?? '—'}',
  dependencies: [OrderModel.slot.name, OrderModel.deliveryDate],
  subtitle: (state, _) {
    final before = OrderModel.slot.name.readFrom(
      state.draft.initialRecord,
    );
    return before != null && before != state.asOrder.slot?.name
        ? 'was $before'
        : orderDeliveryMethod(state.asOrder.deliveryMethod);
  },
),
```

Change a quantity and the Total metric adds the difference and the VAT to its subtitle. Change the slot and the Delivery metric says `was` followed by the previous slot. After a save, `initialRecord` is rebased on the saved values, so the comparison starts over. Cells wrap on narrow screens, and `minColumnWidthInPixels` sets how narrow a cell may get before they do.

## Progress and history

`BeakFormProgress` walks an enum field through milestones. It reads the stored value and never writes it, so progress moves when a model command moves the record. A step without a `state` is a leading event (the order was placed) and counts as done as soon as the record is in any later state. Each step may carry a `details` template for the time and actor:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart"
BeakProgressStep(
  label: 'Placed',
  details: BeakRecordTemplate(
    textGapInPixels: 0,
    title: BeakValueBinding.field(
      OrderModel.placedAt.formatted(BeakValueFormat.time),
    ),
    subtitle: [
      BeakValueBinding<String>.computed(
        dependencies: [
          OrderModel.customer.name,
          OrderModel.createdBy,
        ],
        compute: (row) =>
            'by ${row.read(OrderModel.createdBy) == 'Customer' ? row.read(OrderModel.customer.name) : row.read(OrderModel.createdBy)}',
      ),
    ],
  ),
),
BeakProgressStep(
  state: OrderStatus.confirmed,
  label: 'Confirmed',
  details: BeakRecordTemplate(
    textGapInPixels: 0,
    title: BeakValueBinding<BeakRecord>.computed(
      dependencies: [OrderModel.activities],
      compute: (state) =>
          (state.read(OrderModel.activities) ??
                  const <BeakRecord>[])
              .where(
                (row) =>
                    row.asOrderActivity.kind ==
                    'confirmed',
              )
              .firstOrNull,
      display: (value, format) => value == null
          ? 'Awaiting confirmation'
          : '${format.time(value.asOrderActivity.occurredAt)} · ${value.asOrderActivity.actor.toLowerCase()}',
    ),
    subtitle: [
      BeakValueBinding<String>.computed(
        dependencies: [OrderModel.approvalStatus],
        compute: (row) =>
            row.read(OrderModel.approvalStatus) ==
                ApprovalStatus.pending
            ? 'Awaiting approval'
            : 'within budget',
      ),
    ],
  ),
),
```

Those are the first two of Foodio's five steps. The field must be an enum column, or the node throws a `BeakConfigurationException` when it builds. When the stored value is not one of the steps (a cancelled order, say), the node shows the field's normal badge instead of inventing progress.

`BeakFormTimeline` shows a to-many history as entries, or as message bubbles with `messages: true`. It requests the relationship itself. Foodio's notes card pairs it with an inline command form:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart"
BeakFormTimeline(
  field: OrderModel.notes,
  title: OrderNoteModel.author,
  description: OrderNoteModel.body,
  time: OrderNoteModel.occurredAt,
  messages: true,
  emphasizeMentions: true,
  messageIdentity: BeakRecordTemplate(
    title: BeakValueBinding.field(
      OrderNoteModel.author,
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
    ),
    avatar: true,
    avatarSize: OiAvatarSize.xs,
    inlineIdentity: true,
    avatarPalette: identityPalette,
    identityGapInPixels: 8,
    textGapInPixels: 0,
    inlineSubtitle: true,
    subtitle: [
      BeakValueBinding.field(
        OrderNoteModel.authorRole,
        visibleIf: (row) =>
            row.read(OrderNoteModel.authorRole) != null,
      ),
      BeakValueBinding<DateTime>.field(
        OrderNoteModel.occurredAt,
        display: (value, format) => value == null
            ? format.emptyValue
            : 'today ${format.time(value)}',
      ),
    ],
  ),
),
BeakFormActionInput(
  action: OrderActions.addNote,
  submitWithForm: OrderActions.amend,
  optionalWithForm: true,
  description: 'Only staff can see internal notes.',
  editDescription: 'Saved with your other changes',
  inlineFooter: true,
  footerMinHeightInPixels: 32,
  layout: BeakFormLayout(
    children: [
      OrderNoteInputModel.body.inputText(
        label: 'New internal note',
        placeholder:
            'Add an internal note — type @ to mention a colleague',
        maxLines: 2,
        showCounter: false,
      ),
    ],
  ),
),
```

`BeakFormActionInput` puts a model command's argument form next to the record. Its arguments live in the parent session, with its unsaved-change guard and its review entries, and are never written as record fields. With `submitWithForm` the note is sent together with the parent's Save, and `optionalWithForm: true` accepts an empty note. Both commands must use the same argument model or the session throws when it is created.

## Commands, links and locks

`BeakFormActions(actions: [...])` places existing model commands inside a card, with the same argument dialogs and availability rules as the toolbar. This block is illustrative and uses Foodio's command names:

```dart
BeakFormActions(actions: [OrderActions.startKitchen])
```

A command that you place, with `BeakFormActions` or `BeakFormActionInput`, leaves the automatic toolbar. A bare `BeakFormActions()` places every available command. When a command completes on a record with no unsaved edits, the session reloads it, so a note or an activity row the server added shows up without a callback.

`BeakFormLinks` turns typed values into contact actions. Only `http`, `https`, `mailto`, `tel` and `sms` open, a link whose value is empty is left out, and a failure shows an error toast:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_customer_section.dart"
BeakFormLinks(
  links: [
    BeakFormLink(
      label: 'Call',
      icon: OiIcons.phone,
      destination: BeakValueBinding<String>.computed(
        dependencies: [OrderModel.customer.phone],
        compute: (row) =>
            switch (row.read(OrderModel.customer.phone)) {
              final String phone when phone.trim().isNotEmpty =>
                Uri(scheme: 'tel', path: phone).toString(),
              _ => null,
            },
      ),
    ),
    BeakFormLink(
      label: 'Email',
      icon: OiIcons.mail,
      destination: BeakValueBinding<String>.computed(
        dependencies: [OrderModel.customer.email],
        compute: (row) =>
            switch (row.read(OrderModel.customer.email)) {
              final String email when email.trim().isNotEmpty =>
                Uri(scheme: 'mailto', path: email).toString(),
              _ => null,
            },
      ),
    ),
  ],
),
```

`BeakFormLock` shows a disabled control and says why. It registers no command, so it is honest UI and not a permission:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_customer_section.dart"
BeakFormLock(
  label: 'Change customer',
  description: 'Orders already in the kitchen keep their customer.',
  visibleIf: (state) => !orderIdentityEditable(state),
),
```

## Read and edit, side by side

`BeakModeLayout(read: ..., edit: ...)` chooses a subtree by mode. Both branches live in the same graph, so the fields of both are loaded. Foodio uses it for a notice whose wording changes while editing:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart"
BeakModeLayout(
  read: BeakFormLayout(children: [orderChangeNotice(editing: false)]),
  edit: BeakFormLayout(children: [orderChangeNotice(editing: true)]),
),
```

The same page swaps the add-a-dish action for a search-shaped one while editing, see [Related records in forms](related-records.md#the-add-button-somewhere-else).

The read and edit modes themselves belong to [Detail views](detail-views.md).

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Display only | `BeakCalculated`, summaries, metrics, capacity, notices, progress and timelines are never submitted or validated |
| Declared dependencies | A computed value must list the related fields it reads in `dependencies`. An undeclared related field reads as null |
| Hidden by permission | A node is not shown when the account cannot read a field it declares, or a field its template reads |
| Progress needs an enum | `BeakFormProgress.field` must be an enum column. `states` and `steps` are exclusive, which is an assert |
| Inline commands | Each `BeakFormActionInput` needs a command with an input model, names must be unique in the form, and `submitWithForm` must share the argument model. A violation throws when the session is created |
| Links | Only `http`, `https`, `mailto`, `tel` and `sms` open. Permissions are checked again when a link is activated, and a failure shows a toast |
| Locks are UI | `BeakFormLock` disables a control. The server decides whether the action is allowed |
| Root-only switch | `showChangeIndicators` is read from the root layout only |
| Escape hatch | `BeakFormWidget` receives the draft and a `BeakDraftScope`. Whatever it changes must go through the draft, or it is not saved. See [Form screens](form-screens.md#a-widget-of-your-own) |

## Verify it

The presentation nodes are covered by package tests, and Foodio has tests for its order screens:

```bash
cd packages/beak_frontend
flutter test test/src/form/presentation_workflow_test.dart test/src/form/workflow_milestones_test.dart test/src/form/inline_action_input_test.dart
```

```bash
cd examples/foodio-adminpanel
flutter test test/order_presentation_test.dart
```

Each ends with `All tests passed!`. To watch the nodes move, run Foodio (API on port 8081), open an order and change a quantity: the Total metric, the summary and the change bar all update before you press Save.

## Reference

| Symbol | Where it is documented |
| --- | --- |
| `BeakFormHeader`, `BeakFormTemplate`, `BeakFormPlaceholder`, `BeakFormNotice` | [Screens and form layouts](../reference/screens-and-layouts.md#presentation-nodes) |
| `BeakFormSummary`, `BeakSummaryLine`, `BeakFormMetrics`, `BeakFormMetric`, `BeakFormCapacity` | [Screens and form layouts](../reference/screens-and-layouts.md#beakformsummary-and-beaksummaryline) |
| `BeakFormProgress`, `BeakProgressStep`, `BeakFormTimeline` | [Screens and form layouts](../reference/screens-and-layouts.md#beakformprogress-and-beakprogressstep) |
| `BeakFormLinks`, `BeakFormActions`, `BeakFormActionInput`, `BeakFormLock`, `BeakModeLayout` | [Screens and form layouts](../reference/screens-and-layouts.md#beakformlinks-and-beakformlink) |
| `BeakRecordTemplate`, `BeakValueBinding` | `packages/beak_frontend/lib/src/presentation/beak_record_template.dart` |

## Continue reading

- [Detail views](detail-views.md) the read role that most of these nodes decorate.
- [Multi-step forms](multi-step-forms.md) the wizard these regions belong to.
- [Related records in forms](related-records.md) templates inside pickers and catalogs.
- [Printable record documents](record-documents.md) the same bindings, printed.
