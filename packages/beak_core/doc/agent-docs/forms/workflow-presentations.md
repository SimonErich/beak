# Workflow presentations

> Compose wizard regions, rich choices, catalog editors and read presentations over one managed draft.

A form's presentation can change without introducing another controller, query owner, or save handler. Every region, wizard step, relationship choice and collection editor observes the same `BeakFormSession`. Record permissions load with bounded parallel requests for related drafts; each row retains its own capabilities and reloads them when the form reloads.

## A complete workflow frame

```dart
BeakWizardScreen(
  fullScreen: true,
  navigation: BeakWizardNavigation.rail,
  submitAction: 'place',
  submitLabel: 'Place order',
  header: const BeakFormHeader(title: 'New order'),
  aside: orderSummary,
  steps: [customerStep, deliveryStep, itemsStep, paymentStep, reviewStep],
)
```

`BeakCard.padding` optionally adjusts the inset of an intentional surface; omitted, it follows the shared card theme. `BeakCard.headerGap` and `BeakCardBlock.headerGap` separate a header from its content (default 16); untitled cards add no header gap.

`header`, `aside`, `asideFooter` and `footer` accept ordinary `BeakFormNode` declarations. Their inputs, when present, are included in the same final validation and save. `BeakFormScreen` supports the same regions for read and edit screens. Use `BeakFormTemplate(template: ...)` to reuse a typed record identity presentation in a region.

`BeakFormHeader` provides a guarded close action and, when a draft store is configured, a local Save draft action. It never creates a remote record just to save progress. Generated routes supply the close destination automatically; embedded forms can supply `onClose`. The first wizard step also offers a guarded Cancel action. A stored-draft confirmation appears only after the store confirms its write; failed storage keeps the live edits and asks explicitly whether to discard them.

The header's default `showDraftSavedAt: true` displays `session.draftSavedAt` after a successful manual or automatic write. Resuming a saved draft restores its stored timestamp. A failed first write, an untouched form, or removal of a clean draft never claims that a draft was saved; `showDraftSavedAt: false` hides the status without changing persistence.

Use `asideFooter: orderTotals` to pin totals below the summary’s independent scroll region. On compact screens it becomes the summary sheet’s pinned footer. It shares validation, saving, related loads and live updates with every other form region.

The rail layout supplies card surfaces around the active step and summary, a readable connected step rail, and a pinned footer. A step's `heading` and `introduction` form its pinned content header; they default to its navigation `title` and `description`. Use `BeakSection` for groups within the scrolling body and `BeakCard` for intentional nested surfaces. Moving to another step resets the body's scroll position while retaining the same draft. In short frames the header scrolls with the body so it cannot prevent access to inputs. On compact screens, navigation becomes a step selector and the summary opens in a sheet. Moving forward validates preceding steps; moving backward preserves the entire draft. `fullScreen` removes the surrounding navigation shell while retaining authentication and the normal unsaved-change route guard.

`submitAction` names an action from `model.behavior.actions`. The final primary button executes it with the complete graph, using its argument form when declared. The configured primary command is omitted from the secondary toolbar. Other automatic wizard commands appear only on the final step. Without `submitAction`, final submission uses ordinary save. Availability and server capabilities still control every command. Set `BeakWizardStep.continueLabel` for contextual labels such as “Continue to delivery”; step validation and navigation remain automatic.

Each step can set `footerHint` for guidance between the Back and Continue actions. `completedDescription` replaces that step's rail instructions with a live summary after completion; it receives the shared draft reader and global formatting policy:

```dart
BeakWizardStep(
  title: 'Delivery',
  description: 'Choose a date and slot',
  heading: 'When and where should it arrive?',
  introduction: 'Choose a delivery date and a slot with available capacity.',
  completedDescription: (state, format) =>
      format.format(state.read(OrderModel.deliveryDate), BeakValueFormat.date),
  footerHint: 'Choose a slot with capacity for this delivery.',
  children: [OrderModel.deliveryDate.input()],
)
```

The summary follows edits when a user returns to the step. Returning null keeps its ordinary description; neither presentation callback changes validation or navigation.

## Review sections and step-aware content

Use `BeakReviewSection(title: 'Delivery', stepIndex: 1, children: [...])` to
present a review row. Its label and automatic Edit link sit beside the read
content on wide screens and stack above it on compact screens. Edit returns to
the given zero-based wizard step without replacing the draft. Omit `stepIndex`
for a review group with no navigation link. Read-only relationship collections
can project the same staged rows in review without introducing a second owner.

Conditions can use `state.stepIndex`, for example
`visibleIf: (state) => state.stepIndex == 4` on a review-only aside. Advanced
integrations may call `session.goToStep(index)`: the same operation used by the
rail, Continue, Back and review links. Forward jumps validate prerequisites and
show the first invalid step; backward navigation retains all pending changes.
The current step lives in the form session and does not require application
state management.

## Record milestones and identity typography

Record progress can display milestones and their typed metadata without extra
queries. `BeakFormProgress(field: Model.status, steps: [...])` accepts
`BeakProgressStep(state: Status.inProgress, label: 'In progress', details:
BeakRecordTemplate(...))`. A leading step without `state` represents an earlier
event such as placement. `initialState` optionally previews the first state when
the stored field is absent or null; it never writes that state into the draft
or replaces an unknown or alternate terminal value. Milestone dependencies load with the enclosing form;
unknown or alternate terminal states retain the model's ordinary badge rather
than falsely showing a normal progression. Use
`Model.startedAt.formatted(BeakValueFormat.time)` for a clock value in the panel's
configured display zone. This formatting leaves stored timestamps unchanged.

Record bindings also support `textStyle`, `icon`, `maxLines`, and `visibleIf`.
`maxLines: null` wraps the full value, including longer approval notes. A
`BeakRecordTemplate.icon` is a typed binding for category-specific identity
icons; its dependencies are loaded automatically just like title fields.

With `badge: true`, set `badgeDot: true` to retain the text label beside a status
marker. A binding's `icon` renders inside its badge using the same semantic tone;
it is not duplicated beside it. Both marker and icon remain decorative.

With `badge: true`, a computed list renders as individual badges, useful for tags
and allergen codes; an empty list renders no placeholder badge. Rich card
pickers place identity and metadata in the appropriate card regions using
`BeakRecordTemplatePart`, keeping radio controls aligned with the title.
Set a template's `inlineSubtitle` or `inlineBadges` to compose compact rows;
the containing view can override this placement for its context. Subtitle and
footnote metadata use the theme's caption typography, keeping compact record
identities consistent in tables, pickers and summaries. Record page headings use body-sized metadata; custom hosts can set `BeakRecordTemplateView.subtitleVariant` for their context. Set `BeakRecordTemplate.textGap` for the vertical spacing between identity lines, including compact milestone metadata. A binding's `textStyle`
still overrides individual values when needed.

Use `Model.sendConfirmation.inputCheckbox()` for a checkbox instead of the
default boolean toggle. Both share the field's value, rules, permissions, and
save lifecycle. Checkbox hints and validation messages remain visible beside
the control. `inputRadio` and `inputSelect` likewise accept `description`.

## Rich relationship choices

```dart
OrderModel.customer.inputSearch(
  template: BeakRecordTemplate.fields(
    title: CustomerModel.name,
    subtitle: [CustomerModel.email, CustomerModel.phone],
    avatar: true,
  ),
  validate: const [BeakRequired()],
)

OrderModel.profile.inputCards(
  template: profileIdentity,
  options: (state) => DeliveryProfileModel.options(
    filter: DeliveryProfileModel.customerId.eq(state.read(OrderModel.customerId)),
  ),
  disabledReason: (record, state) => record['active']?.raw == false
      ? 'This profile is inactive.'
      : null,
)
```

Compact relationship choices can declare `inputCards(compact: true, minCardWidth: 140)`.
Cards wrap at the available container width, keep disabled-option validation, and
show a trailing selection check. `BeakRecordTemplate.progress` accepts a typed
`BeakValueBinding<num>` fraction; its dependencies load with the template, its
value is clamped to 0–1, and the accessible progress bar uses Obers styling.
This supports capacity, quota and completion cards without an application widget.

`inputSearch`, `inputCards` and `inputCombobox` share relationship binding, asynchronous search, inferred `BeakExists`/`BeakFieldMatch` prerequisites, selection invalidation and validation. Cards use a responsive grid; inline search keeps full-width results. Card metadata and footnotes span the whole card below its selection/title row. Inline creation sits beside a card picker’s heading so it stays reachable above long option lists. A `BeakRecordTemplate` supplies identity, subtitle, badges and optional initials. Its typed fields automatically request the related data needed for display. Search includes searchable template fields, including related names such as `VariantModel.product.name`; optional `searchSources` overrides this inference with explicit typed paths. All three picker helpers accept `template`, and their read presentation reuses it. Choice inputs similarly display configured option labels in read mode. For scalar choices such as payment modes, `inputRadio(cards: true)` renders `BeakInputOption` labels, descriptions and optional icons as selectable cards over the same typed input binding.

When a model suggestion changes a foreign key, Beak loads its selected record and nested presentation dependencies automatically. Late results cannot replace a newer selection, and validation awaits the current binding.

`disabledReason` renders an explanation and prevents selection. It also participates in final form validation, including a value set through the session API. It is a presentation convenience: enforce authoritative business restrictions in model rules as well.

Use `exclusive: false`, an optional `createForm`, and `createLabel` to offer inline creation from any picker presentation. The dialog stages a related record and cancel restores its checkpoint. `BeakExists` matching rules also connect dependent creations: a new profile can refer to a customer created earlier in the same unsaved form. Beak retains a shared draft reference until the server assigns the ID, saves the customer once, and resolves both foreign keys. Local draft persistence and uncertain-save recovery preserve that link. Replacing the prerequisite requires selecting or creating a compatible dependent record; it never silently saves an orphan.

## Catalogs that stage owned rows

```dart
OrderModel.items.tableForm(
  children: [OrderItemModel.quantity.inputQuantity()],
  catalog: BeakRelationCatalog(
    presentation: BeakCatalogPresentation.rows,
    compactToolbar: true,
    columnLabels: (item: 'Dish', variant: 'Variant and price', quantity: 'Quantity'),
    selection: OrderItemModel.variant,
    template: variantIdentity,
    options: (state) => DishVariantModel.options(
      filter: DishVariantModel.active.eq(true),
    ),
    groupBy: DishVariantModel.dishId,
    variantLabel: DishVariantModel.name,
    price: DishVariantModel.price,
    quantity: OrderItemModel.quantity,
    maxOptions: 200,
    pageSize: 6,
    tabs: [
      const BeakCatalogFilter(label: 'All'),
      BeakCatalogFilter(label: 'Lunch', filter: DishVariantModel.dish.category.eq('lunch')),
    ],
    filters: [
      BeakCatalogFilter(label: 'Vegetarian', filter: DishVariantModel.dish.vegetarian.eq(true)),
    ],
  ),
  advancedForm: itemOptions,
  removeBehavior: BeakRemoveBehavior.deleteOwned,
)
```

`selection` is a to-one field on the collection's row model. Picking a catalog record creates an unsaved row and selects that relationship. Model defaults and behavior populate the remaining values. The catalog itself writes nothing remotely. For ordinary collection editors with an `advancedForm`, Add opens the complete declared row form immediately. Apply validates the row; cancel restores the collection checkpoint without leaving an empty staged item.

`tableForm(readOnly: true)` can repeat a collection in a later review step or summary. It reads the existing graph and introduces no second editable owner, duplicate validation or save operation. Use one editable collection definition and any number of read-only placements.

With `groupBy`, related catalog options appear in one product row with a variant selector. `quantity` binds increment/decrement controls to the staged collection; increasing an existing variant changes its row, and decreasing the last unit stages removal. `advancedForm` defaults to a checkpointed dialog: cancel restores its previous values. Set `advancedPresentation: BeakAdvancedPresentation.inline` to expand these same inputs inside the selected catalog or collection row. Collapsing preserves edits, validation reveals invalid inputs, and the parent form remains the save/cancel boundary. Add on an ordinary collection still opens the complete new-row dialog so cancelling never leaves an empty item. Per-record capabilities, form guards and `allowAdding`, `allowEdit`, `allowRemove` still apply.

For small extra-option lists, `BeakCatalogPresentation.checkboxes` stages one owned row per checked option and removes it when unchecked. Declare a finite `maxOptions`; this presentation has no grouped variants or quantity field. The typed `template` can include prices and allergen badges. Existing selected options remain visible even when they are no longer offered by the option query, allowing a permitted removal. Loading, read access, availability, graph validation and deferred saving use the normal catalog runtime.

`presentation: BeakCatalogPresentation.rows` uses compact separated rows: the typed identity and metadata sit beside the variant/price selector, quantity controls and an Options action. Prices use the panel formatting policy, including integer minor units. Narrow containers stack these controls; the same draft, variants, capabilities and configured advanced editor remain active. The default `cards` presentation remains available for richer product descriptions. Put allergen or dietary tags in the record template's inline subtitle with `badge: true`; metadata dependencies load automatically.

`compactToolbar: true` places up to five category segments beside search and uses
accessible filter chips for independent facets. Larger category sets retain
scrollable tabs; narrow layouts stack search and categories. Optional
`columnLabels` align with the item, variant and quantity controls. Quantity
steppers preserve the same per-record permissions and staged removal behavior.
The compact Options action remains beside the item's metadata and opens the
configured dialog or inline advanced form; it does not commit a separate save.

`quantity.inputQuantity()` places a compact integer stepper in an ordinary form
or relationship row. It follows the model's integer bounds and minimum/maximum
validation rules, keeps required unset values unset until edited, and uses the
same binding and validation pipeline as `inputNumber()`. Use
`showColumnHeadings: true` on compact relationship tables when their enclosing
card supplies the collection heading. Desktop rows omit duplicate field labels;
stacked mobile rows retain them, and controls keep accessible names.
Use `columnWidths: const [140, 90, 80]` to reserve usable widths for compact cells
in `children` order; omitted or null entries share remaining space. The identity
uses the remainder and narrow containers switch to the stacked layout.
For a size or variant picker that belongs below the record title, put it in
`identityChildren` instead of a separate column. It appears beside the record
metadata, keeps its accessible label, and is compiled into the same row form.
Set `identityControlHeight` to scope a compact input height to this metadata
area. Ordinary inputs keep the theme's height, and touch targets still grow to
meet the input modality's accessibility minimum. `rowMinHeight` specifies a
minimum total row height; longer content can grow. `minRowWidth` controls when
cells stack (default 560), subject to any fixed column widths. Review rows with
a single trailing amount can use a smaller threshold and an end-aligned
`BeakCalculated` cell to keep prices in a consistent column.

Inline advanced actions also use this metadata area, so a collapsed editor adds
no extra row. Use `advancedReadVisibleIf` to omit a read-only disclosure when
that row has no meaningful extras; the same advanced editor remains available
while editing. `showColumnHeadings: false` hides redundant headings without
adding labels inside desktop cells. A combobox's typed template title supplies its visible option label.
`BeakCalculated.subtitle` receives the draft and global formatting policy for
secondary values such as a unit price; `textAlign` aligns both value lines.

For finite catalogs, a `BeakCatalogFilter` may also declare `matches` and typed `dependencies`. This local presentation facet runs over the complete result before grouping and pagination, without another request or losing staged quantities. An explicit `maxOptions` is required, so filtering cannot silently omit server pages. For example, a “Without A · gluten” facet can inspect exact comma-separated allergen tokens with `DishVariantModel.dish.allergens.readFrom(record)`. Use normal server `filter` constraints for authorization, availability and large catalogs; local facets never replace those policies.

Catalog tabs are mutually exclusive typed query constraints; checkbox filters combine with the selected tab and the base query. Search, filter and page changes preserve staged rows. Changing search text immediately replaces old choices with a loading indicator, including during the debounce interval, so a pending search cannot add a result from the previous term. Group pagination is opt-in: `pageSize` requires a finite `maxOptions`, and Beak loads that bounded result before paging whole groups locally. If the result exceeds the bound, it asks the user to refine the query. A grouped result is never presented with only some of its variants. Scope large catalogs by menu, account or another parent selection before enabling grouped pagination.

Catalog refreshes follow their query and target data-source revision, so unrelated
local picker hydration does not refetch the menu. Actual query or source changes
still refresh it. The catalog owns selected variants and expanded advanced rows
outside the loading surface, preserving them through asynchronous refreshes.
The editable content also keeps a stable semantics group while validation status
changes, so browser focus remains inside the active editor.
Quantity actions announce the record title and variant to distinguish rows that
share a variant name such as “Regular”.

The basic catalog needs only `selection` and `template`; it shows searchable records with Add buttons. `rowTemplate` on `tableForm` adds a typed identity alongside ordinary row inputs and read-only output. Use `presentation: BeakRelationTablePresentation.rows` for compact separated rows, and `showHeading: false` when an enclosing card already supplies the heading. Narrow layouts stack the same cells; editing and removal still operate on the existing draft graph. Identity-only rows omit empty input grids. For dense review lists, set `rowPadding: const EdgeInsets.symmetric(vertical: 4)` and `showRowDividers: false`; default rows retain their 12-pixel vertical insets and separators. Explicit `options` queries and template dependencies are fetched through the form repository, with loading, empty, error and retry states.

`identityFlex` reserves proportional space for the row identity on desktop
(default 2, compared with 1 for each scalar cell). Increase it for longer product
names beside compact quantity and amount controls. Compact layouts keep stacking
the same cells without losing labels or changing their binding.

## Summaries, notices and history

```dart
BeakFormSummary(
  title: 'Totals',
  lines: [
    BeakSummaryLine(
      label: 'Total',
      value: (state) => state.read(OrderModel.total),
      format: BeakValueFormat.currency,
      emphasized: true,
    ),
  ],
)

BeakFormNotice(
  title: 'Dietary requirements',
  tone: BeakColor.warning,
  message: (state) => state.read(OrderModel.customerNote) ?? '',
  visibleIf: (state) => (state.read(OrderModel.customerNote) ?? '').isNotEmpty,
)

BeakFormCapacity(
  label: 'Monthly budget',
  value: (state) => state.read(OrderModel.budgetUsed),
  max: (state) => state.read(OrderModel.budgetLimit),
  format: BeakValueFormat.currency,
  warningText: 'Nearly all of the budget has been used.',
)
```

Set `BeakFormSummary(maxWidth: 360, alignment: AlignmentDirectional.centerEnd, gap: 8, ...)` for compact invoice totals. Summary values, notices and capacity calculations never become stored fields. Formatting uses the panel policy. Their optional `dependencies` list requests related values used only by the presentation and applies root capability guards. Declare those dependencies when the same relations are not already loaded by form inputs or model behavior.

Set `source: OrderModel.items` to repeat summary lines over the collection's live
child drafts. Each line's reader and dependencies are relative to the child
model. A standalone summary loads its saved rows automatically; a summary beside
an editor observes the same staged additions, edits and removals. It never grants
editing permission or adds a second save operation. Declare nested collection
dependencies when a calculation uses `state.rows(ItemModel.options)`.

`BeakSummaryLine.labelBuilder` and `subtitle` receive the reader and global
formatting policy. Use them for quantity labels, voucher codes and included-tax
explanations. `visibleIf` omits inapplicable rows, `dividerBefore` separates totals,
and `labelStyle`/`valueStyle` adjust emphasis while preserving the theme font.
The underlying Obers `OiKeyValue` supports trailing values and custom label
content, including wrapping labels in narrow summaries.

Capacity displays can hide duplicate visual headings with `showLabel: false`
and ratios with `showValue: false`; the accessible label and value remain.
`BeakFormCapacity.valueStyle` styles the ratio independently of `labelStyle`;
omitting it retains the existing label-style fallback. For example, a compact
budget can use a caption heading with a body-sized remaining amount.
`caption(state, formatting)` adds a live explanation below the track, such as
the budget reserved by the current order.

`BeakFormTimeline(field:, title:, time:, description:)` renders an authorized to-many history relation using typed fields on its row model. It requests the relationship automatically and uses the shared date/time formatting. `compact: true, columns: 2` presents activity as responsive text rows while the default retains individual entries. `BeakFormProgress<Status>(field:, states:)` displays an enum's model labels. A value outside the configured normal sequence displays its actual field value rather than inventing progress; transitions remain model actions.

`BeakFormActions(names: ['hold', 'cancel'])` places the existing authoritative commands inside a card or region. It uses the same argument dialogs, availability rules and save-recovery lifecycle as the automatic toolbar. Only the explicitly positioned names are omitted from the automatic toolbar; unnamed `BeakFormActions()` positions every available command. Standard resource pages put the remaining commands in the header’s More actions menu.

After a command completes on an existing clean draft, the session reloads its declared relationships and permissions. Server-created notes, activity and related changes appear immediately without page callbacks. Receipt recovery refreshes the same way without repeating the command. Unsubmitted edits prevent replacement, and a failed refresh retains the known relationship data and confirmed save receipt while exposing the read error.

For unique content, `BeakFormWidget` remains the escape hatch. Its `BeakDraftScope` exposes the current read/edit state and editability, and its supplied draft is the same one used by all configured fields.

## Joined metric strips

Use typed bindings for read-screen figures and live draft statistics:

```dart
BeakFormMetrics(metrics: [
  BeakFormMetric(
    label: 'Gross total',
    value: (state) => state.read(OrderModel.total),
    format: BeakValueFormat.currency,
    description: 'Including tax',
  ),
])
```

`BeakFormMetrics` loads declared dependencies, applies read capabilities, and observes the existing draft. Cells wrap on compact screens. Optional `BeakFormMetric.valueStyle` controls emphasis while retaining the theme font; values are bounded to two lines. Metric values use the same `BeakFormReader` and format policy as summary lines, including staged relationship rows.

Use `minColumnWidth` on the strip for compact review totals, and `flex` on a metric
to give longer profile or organization values more space. Cells in each responsive
row share a height, so dividers stay aligned when one value wraps.

## Sections and page frames

`BeakCard(children: ...)` adds a themed surface without a heading. Add `title` when useful. `BeakCard(collapsible: true, initiallyExpanded: false, ...)` keeps secondary details compact while retaining their draft state. Collapsed fields remain part of validation and save; validation automatically expands a card with errors. Hidden card content is excluded from keyboard and screen-reader navigation.

Add `presentation: BeakCardPresentation.plain` for a borderless disclosure with
an inline description. The shared Obers disclosure preserves mounted editor
state, supports keyboard toggling and respects reduced-motion preferences.
Relation cards stretch to equal heights within each responsive row.

`BeakSection(divider: true, descriptionStyle: ...)` separates related groups without introducing another card. `BeakFormPlaceholder(label: 'Select a customer', visibleIf: ...)` uses the UI kit's neutral hatch surface for content that needs a prior choice. It does not imply that a request is loading.

Sections expose `titleStyle`, semantic `titleColor`, `descriptionStyle`,
`headingGap` and `gap` for a consistent hierarchy without custom widgets.
`BeakFormNotice(plain: true)` presents a compact icon and wrapping message;
`inline: true` instead keeps a banner's title and message on one line. Inline
record subtitles omit empty values and do not add dot separators around badges.
Date shortcuts form one segmented control while arbitrary dates remain available
through the adjacent calendar picker.

Standard generated resource pages own the page heading and place the existing form Edit, Save and Cancel controls there. A custom host can use `BeakConfiguredForm.frameBuilder(context, session, mode, actions, child)` to arrange the same controls and configured body. The supplied mode follows in-place Edit/Cancel transitions. Place both supplied widgets once; this hook adds no second controller or save lifecycle. `recordHeader` is a typed record template whose dependencies load through that same session. Cancel restores the current persisted record after the ordinary unsaved-change guard.

Date and date/time inputs use the panel's locale and date pattern. Bundled date locale data initializes automatically. Instant editors display the configured local or fixed-offset wall clock and convert edits back to UTC; a browser's own timezone is not applied a second time. Calendar dates remain timezone-free.

## Continue reading

- [Forms](form-screens.md)
- [Multi-step forms](multi-step-forms.md)
- [Drafts and review](drafts-and-review.md)


### Inline command arguments and shared detail layouts

`BeakFormActionInput(name: 'addNote', layout: noteFields)` places a model action's
argument form beside the record. Its transient input model supplies validation;
Beak owns its controller, unsaved-change guard, review entries, optional durable
draft storage, submission, and receipt recovery. It does not create an input-model
resource or persist the argument fields on the record.

For an editor that submits an optional note with other changes, declare a separate
atomic model action, set `BeakFormScreen(submitAction: 'amend')`, and use
`BeakFormActionInput(name: 'addNote', submitWithForm: 'amend',
optionalWithForm: true, layout: noteFields)`. Both commands must share the argument
model's table and compatible fields. `optionalWithForm` permits completely empty
arguments only for the primary command; that command's server input model must
also accept them. Direct Add note still validates its required input. Failed or
uncertain saves retain the text; only a confirmed complete receipt clears submitted
arguments. The server remains responsible for the atomic domain operation.

A sole root `BeakTabs(acrossRegions: true, tabs: ...)` places its selector above the
main content and aside. The branches retain one draft, including their validation
and navigation state. `BeakFormScreen.asideWidth` sets the supporting column's
width; narrow layouts continue to use the shared sheet. `BeakModeLayout(read: ...,
edit: ...)` provides distinct presentations over the same loaded and validated
record without a second request/controller.

Metric cells accept `padding`, `gap`, and a reactive `subtitle(state, formatting)`;
use the provided panel formatter for currency and dates. Record templates expose
`iconSize`, `identityGap`, and `copyableTitle`. Timeline `messages: true` renders
compact author/time headings and neutral message bubbles. `BeakFormNotice(inline:
true)` keeps the title and message on one wrapping line through Obers' `inlineTitle`.


Generated form page headers can set `editLabel`, `prominentEdit`, `compactActions`,
and `showBack`. Compact actions retain the accessible “More actions” name and
appear after the primary control. `pagePadding` and `pageGap` set the outer frame;
plain layouts and tab contents accept `spacing`. All defaults retain the standard
panel presentation. Neutral notices can supply an explicit `icon`.

A dynamic scalar input label may declare typed `BeakInput.dependencies`. These
relations are loaded with the form and the input is hidden if its dependency is
not readable, before its label callback runs. For example:

```dart
OrderModel.sendConfirmation.inputCheckbox(
  dependencies: [OrderModel.customer.email],
  labelBuilder: (state) => 'Send confirmation to ${state.read(OrderModel.customer.email)}',
)
```

The dependency declaration changes loading and presentation permissions; the
checkbox remains bound to its ordinary boolean field and normal validation.

Relationship choices refresh when their own declared query changes or their source
reports a relevant mutation. An unrelated field's option dependency no longer
restarts other mounted pickers. This uses per-relation invalidation, not a result
cache: reopening/searching still fetches current choices, and changed eligibility
or source mutations still recheck selected records before accepting them.

### Detail pages without extra state

`BeakFormScreen.asideFraction` allocates the supporting column from the width
remaining after page padding and the column gap. A value of `1 / 3` produces a
2:1 page; compact screens still use the normal labelled summary sheet.

Cards accept `headerSubtitle` and `headerTrailing` typed bindings. Their related
fields load with the same record query, and supporting metadata remains visible
when a card is collapsed. `collapseLeading` places a compact disclosure before
the title. `BeakFormDivider` separates groups without introducing another card.
`BeakColumns` can specify `gap`, `padding`, and fixed `columnWidths`, with null
widths sharing remaining space and the whole group stacking on narrow screens.

`BeakCalculatedPresentation.detail` renders a caption, value and supporting
caption; `message` renders a labelled neutral note. `BeakValueBinding.display`
and `BeakCalculated.display` receive the panel's formatting policy for contextual
text. `BeakFormatPolicy.date` and `calendarDate` accept an optional pattern;
calendar dates still avoid timestamp timezone conversion.

`BeakRecordTemplate.inlineIdentity` keeps an author's name and secondary metadata
on one wrapping line. `badgeToken` renders small square codes; `itemTone` and
`itemTooltip` explain individual values without changing stored data. Normal
status badges retain their own geometry. `BeakFormTimeline(inlineTime: true)`
uses compact connected rows that fill each responsive column chronologically;
`actor` is an optional typed binding and `messageIdentity` supplies note authors.

`BeakFormProgress(planned: true)` displays a neutral numbered plan without
claiming that any persisted milestone has happened. Each step may provide a
`context` record template for an approver or responsible person.

`BeakFormLinks` provides compact contact or web actions using typed URI bindings.
Only HTTP(S), mail, phone and SMS schemes launch, permissions are rechecked when
activated, and failures use the panel's normal error presentation.

`BeakRelationAdd` positions a collection's add action independently of its rows.
It reuses the declared table's row form, capabilities, validation and checkpoint;
cancelling the modal removes the staged addition. Set the table's
`showAddAction: false` to suppress its default action. `rowGap`,
`identityControlWidth`, `columnAlignments` and `reserveActions` allow dense rows
to keep read and edit values aligned.

`showChangeBar` on a form screen pins actual unsaved graph changes and validation
issues beside managed Save/Discard actions. Discard resets command arguments as
well as ordinary fields and relationships. An active or unknown write cannot be
discarded. Inline command forms can use `inlineFooter` for compact guidance and
an action on one row; `editDescription` explains when their arguments save with
the parent. Text placements can override `placeholder` and `showCounter` while
retaining the model's limits and validation.

## Contextual wizard guidance and precise presentation

`BeakWizardScreen.navigationDescription` supplies supporting text below the step
rail. Each `BeakWizardStep` accepts `introductionBuilder` and `footerHintBuilder`
with the live form reader and global formatting policy. Declare their related
fields in `dependencies` so the session loads them even before the first edit.
Static `introduction` and `footerHint` remain the fallback. These callbacks only
produce presentation; they neither change validation nor create another draft.

`BeakSection.trailing` is a typed value binding for a short heading annotation,
such as a cutoff time. Its related dependencies load automatically. The heading
and annotation share available width and continue to wrap on narrow screens.

Record templates support `trailing` bindings for right-aligned metadata,
`avatarSize` and `avatarRadius` for person or organization identities,
`identityGap`, `textGap`, `detailsSpacing`, and `detailsGap` for deliberate
information density. All bindings, including trailing content, contribute to
automatic relation loading and retain their visibility rules. `progressHeight`
and `progressStriped` configure a normalized capacity display; progress values
remain clamped to the visible range without modifying stored values.

Relationship `inputSearch` can declare `createDescription` and `createIcon` for
its attached create row. `inputCards` supports `descriptionBuilder`,
`descriptionInline`, `createLabelBuilder`, `dependencies`, and `divider` for
contextual guidance and grouped selections. Creation still uses the declared
`createForm` and the existing staged relationship lifecycle.

Exact-code selectors accept `selectionSummary: BeakCalculated(...)` to display
an owner-draft calculation alongside the applied relationship, for example the
current voucher discount. It disappears when the relationship is removed and
is never written as another model field.

A catalog may declare `notice` between its filters and rows, `footer` after the
rows, and `groupOrder` for the owner's preferred group keys. Unknown groups
retain query order. `BeakCatalogFilter.filterBuilder` computes a facet's scope
from the owner draft; removing a facet removes only its own constraint, while
model eligibility and the base options query remain authoritative. Declare
owner fields in `catalog.dependencies`. A bounded catalog continues to filter
and paginate complete groups and keeps selected rows staged when a filter
hides them. `advancedLabel` is a target-record binding for the inline options
link and its visibility; its dependencies load with catalog records.
`controlHeight` adjusts catalog input density without replacing the UI kit's
interaction behavior.

Calendar `inputDate(shortcuts: ...)` declarations with up to four shortcuts use
one segmented date control plus its custom-date picker. Presets and the picker
share the same typed date, locale, validation, and enabled state. More shortcuts
retain the existing wrapping shortcut presentation. A selected custom date can
reopen the picker; a disabled preset cannot change the value.

Text `inputText(controlHeight: 88, maxLines: 3)` declares a minimum editor
height, excluding the label and supporting text. Larger text and content still
grow naturally. Hiding a redundant visible input label retains the model's
accessible name. Textarea hints and counters share a footer, and multiline
placeholders wrap inside the same line area as editable content.

`BeakFormPlaceholder(template: ..., label: ..., height: ...)` can show a live,
read-only preview before a record is saved. Its bindings load and obey read
permissions like an ordinary form template. Its label remains an accessible
explanation, and its minimum height grows for longer content instead of
clipping. A placeholder implies missing or future content, never pending
network activity.

### Editing annotations and committed baselines

Set `BeakFormScreen.editingLabel` to annotate an existing record while it is
being edited. The standard heading supplies this through the template view's
`titleTrailing` slot; the annotation follows read/edit transitions over the
same session. `BeakModeLayout` can also provide mode-specific notices.

Summary lines accept `valueCaption(state, formatting)` for short context beside
the amount. Metric subtitles and summary captions can compare the live draft
against `state.draft.initialRecord`, for example to show a price delta or the
previous delivery slot. A successful save rebases the committed values while
preserving locally held hidden fields omitted from a partial response; explicit
server null values still replace the local value.

The pinned change bar uses `session.reviewChangeCount`: a new relationship row
counts as one change. `reviewChanges` retains its individual fields for the full
review. `BeakFormTimeline(emphasizeMentions: true)` highlights conventional
`@Name` mentions in message bubbles without rewriting stored note text.

Use `inputRadio(cards: true, minCardWidth: 180)` to arrange description-bearing
choices in equal-width tiles that wrap when the available width shrinks. Optional
`cardPadding` adjusts their internal spacing through the standard radio tile. The
same typed values, validation, and option permissions govern both layouts.
Required relationship inputs omit the clear action, including placements with
`BeakRequired`, while optional inputs remain clearable.

`BeakFormLock(label: ..., description: ...)` explains a policy-protected action
through a disabled standard control. Relationship choices can retain their form
presentation with `enabledIf` even after a workflow stage locks them. Notice
`caption(state)` adds short trailing context, such as remaining cutoff time.
The standard change bar provides a rounded footer without a separate content
gap; page padding still controls its distance from the viewport edge.

## Preserving a recovery decision

When a session finds a stored draft, Resume and Discard resolve that decision before forward navigation or persistence. Editing the current draft does not overwrite the saved candidate. Manual save and submission remain guarded until that decision is resolved; the same rule applies to embedded sessions.

## Typed identity and summary details

`BeakRecordTemplate.titleMetadata` adds secondary typed values beside the main title, while `identityMinHeight` aligns rich card identities and `footnoteSpacing` controls the separator inset. Search templates accept a literal `highlightQuery`; the selected relation choice can override its avatar tone through the shared theme. Display callbacks are invoked inside their generic binding so nullable dates and strings retain their declared types.

`BeakFormSummary.headingGap` separates a heading from its rows. A summary line can declare `valueLabel` for formatting context such as an amount followed by “left”, `subtitleStyle` for tax explanations, and `dividerSpacing` for an emphasized total. These declarations observe the managed draft and do not create another data source. Review sections similarly expose `titleStyle`, `padding`, `divider` and `dividerSpacing`.

`BeakFormNotice.caption` and `captionIcon` place a short annotation at the trailing edge, for example a lock beside a value inherited from a location. `BeakFormProgress.labelStyle` styles detailed milestone labels without changing their semantics.

`BeakFormActionInput.footerMinHeight` can reserve the same footer row height
when its immediate action is replaced by a staged-save hint. The input theme
can set `labelStyle`, `labelGap`, and `supportingGap` consistently across
comboboxes and text inputs. Disabled comboboxes retain their selected label
with the same single dimming treatment as a disabled input surface.


Form screens can set `submitIcon`, `outlinedCancel: true`, and
`showActionsWhileEditing: false` to keep the edit toolbar focused on its managed
Save and Cancel controls. Read-mode commands retain their normal availability
and placement. These options change presentation only.

`BeakRelationAdd(presentation: BeakRelationAddPresentation.search,
placeholder: 'Add an item, e.g. soup', ...)` presents an outlined search-shaped
trigger for the same managed row dialog. It remains an accessible button with
keyboard activation; the placeholder does not create another editable field or
search controller. `inputQuantity(controlWidth: 90)` fixes the compact stepper's
width while keeping its normal bounds, keyboard handling and permissions.

`BeakTab(showValidationBadge: false, ...)` omits a redundant tab validation count
when the active page already shows its errors. Validation and explicitly bound
value counts still apply. Joined metric strips follow the card theme's shadow
unless they use the inset presentation.


`inputRadio(groupLabelAsField: true)` uses the ordinary input label typography
and label gap for a compact field group. The default uses the radio group's
heading style and `groupLabelSpacing`. The heading gap is independent of the
8px space between choices, so wider heading separation does not stretch every
radio-card row. These options retain the same typed selection and validation.


`inputCards(cardPadding: ...)` optionally overrides a relationship choice's
content inset. Omission retains the existing search 12px horizontal / 8px vertical, compact 12px and
rich 16px defaults; outlines continue to paint without consuming layout space.
Scalar `inputRadio(cardPadding: ...)` uses its separate `choiceCardPadding`
placement property. Neither override changes selection, eligibility or binding.


`inputText(multilineContentPadding: ...)` changes only that multiline editor's
inset through its ordinary input theme. Omission retains the existing themed
padding; direction-dependent insets resolve in the current text direction.
This can make a delivery comment denser while a longer internal note keeps its
normal height, without introducing a separate editor or draft controller.


`tableForm(advancedContentPadding: ...)` configures the inline advanced
surface's inset; its default remains 12px on every side. It does not alter the
dialog row layout. Collapsed inline panels contribute no content padding or
separation height; reopening restores that geometry and validation errors
still reveal the same editor automatically.


### Compact page header scrolling

`OiPageLayout.scrollHeaderWhenCompact` defaults to false. When both compact and
`scrollable`, opting in moves the header, navigation and aside trigger into the
content scroll; the footer remains pinned. Desktop layout is unchanged.
Beak intrinsic form pages and `BeakListScrollMode.page` opt in, ensuring tall
stacked headings or metrics cannot consume the whole editing/row viewport.
Bounded table pages retain their ordinary scroll ownership.

### Detailed progress rails

`BeakFormProgress(timeline: true)` opts vertical detailed milestones into an
intrinsic connected rail. The default remains the existing separated connector
layout; horizontal and compact steppers retain their geometry. `contextSpacing`
controls the gap between details and the contextual record and defaults to 6px.

`OiStepperThemeData` supplies upcoming indicator border color/width, upcoming
connector color, `stepSpacing` and `detailsSpacing`. Active, error and completed
colors and 2px state strokes retain precedence. Omitted theme values preserve ordinary 2px indicator
strokes; timeline mode defaults to 1px, 20px between items and 2px between label
and details. Its connector extends beside the item content with 4px end margins
and a 24px minimum length. Gabel uses its border and lineStrong colors in both
light and dark themes, with an 8px contextual-record gap.

A single computed subtitle binding can join related identity metadata into one
line while retaining typed dependencies, full accessible text and the normal
ellipsis policy. This avoids introducing a separate person-summary renderer.
