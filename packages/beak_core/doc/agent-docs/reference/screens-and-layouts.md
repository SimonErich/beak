# Screens and form layouts

> Look up every screen class, form container and presentation node, their parameters and defaults, how roles map to routes, and the setup checks.

A resource route is served by a screen, and a form screen holds a tree of layout nodes. This page lists every screen class, every node of that tree except the input placements, and the checks that fail at setup.

## Import

```dart
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
```

`package:beak/panel.dart` exports every class on this page. `package:beak/ui.dart` is only needed for `OiIcons` and the other obers_ui types that appear in parameters such as `icon`. Input placements (`BeakInput`, `BeakRelationInput`, `BeakRelationTable`, `BeakGallery`, `BeakRelationAdd`) are documented in [Input builders](input-builders.md).

## Summary

### Screens

A screen is attached to a resource through `BeakResource.screens`. Each screen claims one or more routes through its `roles`.

| Class | Extends | Roles | Serves |
| --- | --- | --- | --- |
| `BeakResourceScreen` | none (abstract) | required | Base of the four below |
| `BeakFormScreen` | `BeakResourceScreen` | `{create, edit}` by default | One layout for create, edit and, when `read` is added, the show page |
| `BeakWizardScreen` | `BeakFormScreen` | `{create, edit}` by default | The same form as validated steps |
| `BeakTableScreen` | `BeakResourceScreen` | fixed to `{list}` | The list page, with typed columns, a base query or a composed list |
| `BeakCustomResourceScreen` | `BeakResourceScreen` | required | Any widget replacing a standard route |
| `BeakScreen` | none | not a resource screen | A free-form panel page at its own path, built from blocks |

### Layout containers

| Class | Extends | Purpose |
| --- | --- | --- |
| `BeakFormLayout` | `BeakFormNode` | Ordered children with vertical spacing; the root of every form |
| `BeakCard` | `BeakFormLayout` | Titled surface, optionally collapsible |
| `BeakSection` | `BeakFormLayout` | Heading with optional description and divider, no border |
| `BeakColumns` | `BeakFormLayout` | Responsive side-by-side columns |
| `BeakTabs`, `BeakTab` | `BeakFormLayout` | Tabbed groups over one draft |
| `BeakWizardStep` | `BeakFormLayout` | One validated page of a wizard |
| `BeakReviewSection` | `BeakFormLayout` | Review row with an Edit link back to a step |
| `BeakModeLayout` | `BeakFormLayout` | Separate read and edit trees |
| `BeakFormSections` | none | One list of sections projected as a form, tabs or steps |
| `BeakFormDivider` | `BeakFormNode` | Quiet separator |

### Presentation nodes

| Class | Purpose |
| --- | --- |
| `BeakFormHeader` | Workflow toolbar with close and draft actions |
| `BeakFormTemplate` | A `BeakRecordTemplate` rendered against the live draft |
| `BeakFormPlaceholder` | Neutral block for content that waits on another selection |
| `BeakFormNotice` | Conditional inline notice |
| `BeakFormMetrics`, `BeakFormMetric` | Joined metric strip |
| `BeakFormSummary`, `BeakSummaryLine` | Label and value rows, for totals |
| `BeakFormCapacity` | Utilization bar with a warning threshold |
| `BeakFormProgress`, `BeakProgressStep` | Read-only progress through an enum field |
| `BeakFormTimeline` | A to-many relationship as a chronological timeline |
| `BeakFormLinks`, `BeakFormLink` | External actions computed from the draft |
| `BeakFormActions` | Model commands placed in the layout |
| `BeakFormActionInput` | A command's argument form, inline |
| `BeakFormLock` | Disabled action with the reason it is unavailable |
| `BeakCalculated` | Reactive display value, never submitted |
| `BeakFormWidget` | Custom widget over the same draft |

Every `BeakFormNode` takes `visibleIf` and `enabledIf`, both `bool Function(BeakFormReader state)?`, evaluated on the live draft. A node also stays hidden when the account cannot read the field behind it. The tables below list them once for each class that accepts them.

## Screens

### Roles and routes

`BeakScreenRole` names the four conventional routes of a resource.

| Role | Route | Without a screen | With a screen |
| --- | --- | --- | --- |
| `list` | `/<table>` | Generated list page | `BeakTableScreen` configures it; `BeakCustomResourceScreen` replaces it; a `BeakFormScreen` cannot claim it |
| `create` | `/<table>/create` | Form derived from the model by `BeakFormLayout.fromModel` | `BeakFormScreen`, `BeakWizardScreen` or `BeakCustomResourceScreen` |
| `read` | `/<table>/<id>` | Read-only card of the model's inputs, plus a card with one tab per to-many relationship (related rows read-only, first five columns) | A `BeakFormScreen` that lists `read` renders the same layout in read mode, with Edit and Cancel switching in place |
| `edit` | `/<table>/<id>/edit` | Same form as create, loaded with the record | `BeakFormScreen`, `BeakWizardScreen` or `BeakCustomResourceScreen` |

`BeakFormMode` is the mode a configured form renders in; it follows the role.

| `BeakFormMode` | Role | Renders |
| --- | --- | --- |
| `read` | `read` | Values without editing controls |
| `create` | `create` | A new record draft |
| `edit` | `edit` | An existing record draft |

Adding `BeakScreenRole.read` to a form screen's `roles` is the switch that shares its layout with the show page. The default roles leave the show page on the generated layout.

Real usage, from the package tests. One form screen serves three routes, and a custom builder replaces the list:

```dart title="packages/beak_frontend/test/src/panel/declarative_panel_test.dart"
BeakFormScreen(
  roles: const {
    BeakScreenRole.read,
    BeakScreenRole.create,
    BeakScreenRole.edit,
  },
  layout: BeakFormLayout(
    children: [
      BeakCard(title: 'Configured note', children: [name.inputText()]),
    ],
  ),
),
BeakCustomResourceScreen(
  roles: const {BeakScreenRole.list},
  builder: (_, _) => const OiLabel.body('Custom list'),
),
```

### BeakResourceScreen

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_screen.dart"
const BeakResourceScreen({required this.roles});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `roles` | `Set<BeakScreenRole>` | required | Resource routes rendered by this screen |

### BeakFormScreen

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_screen.dart"
const BeakFormScreen({
  this.layout,
  this.steps = const [],
  this.drafts,
  this.reviewBeforeSave = false,
  this.showInspector = false,
  this.header,
  this.recordHeader,
  this.aside,
  this.asideFooter,
  this.asideWidthInPixels = 360,
  this.asideFraction,
  this.footer,
  this.fullScreen = false,
  this.navigation = BeakWizardNavigation.inline,
  this.navigationDescription,
  this.submitAction,
  this.submitLabel,
  this.submitIcon,
  this.outlinedCancel = false,
  this.showActionsWhileEditing = true,
  this.editLabel,
  this.editingLabel,
  this.prominentEdit = false,
  this.compactActions = false,
  this.showChangeBar = false,
  this.showBack = true,
  this.pagePadding,
  this.pageGapInPixels,
  super.roles = const {BeakScreenRole.create, BeakScreenRole.edit},
});
```

The parameters group by what they configure. `layout` and `steps` are the content; when both are omitted the form comes from the model.

| Group | Parameters |
| --- | --- |
| Content | `layout`, `steps` |
| Regions | `header`, `aside`, `asideFooter`, `footer`, `recordHeader`, `asideWidthInPixels`, `asideFraction` |
| Wizard | `navigation`, `navigationDescription` |
| Actions | `submitAction`, `submitLabel`, `submitIcon`, `outlinedCancel`, `showActionsWhileEditing`, `editLabel`, `editingLabel`, `prominentEdit`, `compactActions`, `showChangeBar` |
| Page chrome | `showBack`, `pagePadding`, `pageGapInPixels`, `fullScreen` |
| Session | `drafts`, `reviewBeforeSave`, `showInspector` |
| Routes | `roles` |

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `layout` | `BeakFormLayout?` | none | Field and layout declarations. Null selects the model defaults. |
| `steps` | `List<BeakWizardStep>` | `const []` | Optional wizard presentation over the same form session |
| `drafts` | `BeakFormDrafts?` | none | Optional scoped local draft persistence |
| `reviewBeforeSave` | `bool` | `false` | Shows the proposed changes before final submission |
| `showInspector` | `bool` | `false` | Enables development diagnostics on this screen |
| `header` | `BeakFormNode?` | none | Region above the form body, observing the same draft |
| `recordHeader` | `BeakRecordTemplate?` | none | Live record identity, metadata and badges in the generated page heading |
| `aside` | `BeakFormNode?` | none | Supporting column beside the form body, observing the same draft; collapses into a sheet on compact screens |
| `asideFooter` | `BeakFormNode?` | none | Supporting content pinned below the aside, using the same draft |
| `asideWidthInPixels` | `double` | `360` | Width of the supporting column before it collapses into a sheet |
| `asideFraction` | `double?` | none | Optional share of desktop content width after the gap; compact sheets use `asideWidthInPixels`. For example, one third yields a two-to-one page layout. |
| `footer` | `BeakFormNode?` | none | Region below the form body, observing the same draft |
| `fullScreen` | `bool` | `false` | Gives a workflow the full protected route surface, retaining authentication |
| `navigation` | `BeakWizardNavigation` | `BeakWizardNavigation.inline` | Controlled presentation of wizard step navigation |
| `navigationDescription` | `String?` | none | Supporting guidance below desktop wizard steps |
| `submitAction` | `BeakModelAction?` | none | Optional model command used by the final primary submission |
| `submitLabel` | `String?` | none | Optional primary action label, otherwise the model command or Save/Finish |
| `submitIcon` | `IconData?` | none | Optional icon for the heading's primary submission control |
| `outlinedCancel` | `bool` | `false` | Gives the existing-record Cancel control an outlined surface |
| `showActionsWhileEditing` | `bool` | `true` | Keeps standalone model actions available while an existing record edits |
| `editLabel` | `String?` | none | Optional label for switching a shared read view into editing |
| `editingLabel` | `String?` | none | Badge beside the record header title while an existing record is edited; needs `recordHeader` |
| `prominentEdit` | `bool` | `false` | Promotes Edit to the primary visual action in read mode |
| `compactActions` | `bool` | `false` | Shows secondary commands in a named icon menu after the primary action |
| `showChangeBar` | `bool` | `false` | Pins a draft change count, validation feedback and save/discard controls |
| `showBack` | `bool` | `true` | Whether generated page chrome includes its separate Back button |
| `pagePadding` | `EdgeInsetsGeometry?` | none | Optional outer page insets and spacing; defaults preserve standard chrome |
| `pageGapInPixels` | `double?` | none | Space between generated page heading and content |
| `roles` | `Set<BeakScreenRole>` | `const {BeakScreenRole.create, BeakScreenRole.edit}` | Resource routes rendered by this screen |

`BeakWizardNavigation` values: `inline` (compact progress text above the current step) and `rail` (responsive step rail with pinned actions and an optional summary aside).

Regions and the body are one draft. A region is added to the form's root layout, so a `BeakFormSummary` in `aside` reads the same values as the inputs in the body.

### BeakWizardScreen

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_screen.dart"
const BeakWizardScreen({
  required super.steps,
  super.drafts,
  super.reviewBeforeSave,
  super.showInspector,
  super.header,
  super.aside,
  super.asideFooter,
  super.asideWidthInPixels,
  super.asideFraction,
  super.footer,
  super.fullScreen,
  super.navigation,
  super.navigationDescription,
  super.submitAction,
  super.submitLabel,
  super.submitIcon,
  super.outlinedCancel,
  super.showActionsWhileEditing,
  super.editLabel,
  super.prominentEdit,
  super.compactActions,
  super.showChangeBar,
  super.showBack,
  super.pagePadding,
  super.pageGapInPixels,
  super.roles = const {BeakScreenRole.create, BeakScreenRole.edit},
});
```

`BeakWizardScreen` forwards 26 of the 29 parameters of `BeakFormScreen`, with `steps` required. It does not take `layout` (the steps are the layout), `recordHeader` or `editingLabel` (both belong to the single-page heading). A wizard that needs one of them is written as `BeakFormScreen(steps: [...])`, which accepts every parameter.

`showBack`, `pagePadding` and `pageGapInPixels` shape the page around a wizard. They have no effect when `fullScreen` is true, because a full-screen wizard has no page chrome.

### BeakTableScreen

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_screen.dart"
const BeakTableScreen({this.fields, this.query, this.definition})
  : super(roles: const {BeakScreenRole.list});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `fields` | `List<BeakScalarField<Object>>?` | none | Scalar field references, including related paths, in display order |
| `query` | `BeakQuerySpec?` | none | Initial sort, pagination, and permanent filtering for this screen |
| `definition` | `BeakListDefinition?` | none | Optional composed list with presets, a shared query and typed cells |

`fields` positions typed columns without a composed list. `definition` adds presets, a shared query and typed cells; see [Composed lists and query state](../panel/composed-lists.md).

### BeakCustomResourceScreen

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_screen.dart"
const BeakCustomResourceScreen({required this.builder, required super.roles});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `builder` | `Widget Function(BuildContext context, Object? recordId)` | required | Builds the custom surface. Record routes receive their identifier. |
| `roles` | `Set<BeakScreenRole>` | required | Resource routes rendered by this screen |

The builder receives `null` as `recordId` on the list and create routes, and the route's id on the read and edit routes. Routing, the redirect to `/403` and the permission checks stay with the resource. A custom `create` or `edit` screen makes the route available even when the model does not expose the operation as standard, as long as the resource's `canCreate` or `canEdit` and the model's permissions allow it.

### BeakScreen

A page that belongs to the panel rather than to a resource. Register it in `BeakPanelConfig.pages`.

```dart title="packages/beak_frontend/lib/src/panel/beak_screen.dart"
const BeakScreen({
  required this.path,
  required this.title,
  required this.icon,
  required this.body,
  this.navigationTitle,
  this.navigationGroup,
  this.showInNav = true,
  this.framed = true,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `path` | `String` | required | The route this screen is mounted at (e.g. `'/analytics'`). |
| `title` | `String` | required | The screen title, shown in the framed header and used as the sidebar title fallback |
| `icon` | `BeakIconToken` | required | The sidebar icon |
| `body` | `BeakBlock` | required | The declarative screen content |
| `navigationTitle` | `String?` | none | Sidebar title override; defaults to `title` |
| `navigationGroup` | `String?` | none | Optional sidebar group heading this screen is filed under |
| `showInNav` | `bool` | `true` | Whether the screen appears in the sidebar. Set false for detail pages reached only by navigation (e.g. an invoice document). |
| `framed` | `bool` | `true` | Whether to provide the standard page header, gutters and scrolling. The frame does not add a card or background behind the body: card, chart and table blocks own their surfaces. Wrap the body in a `BeakCardBlock` to deliberately place it on one shared surface. Set false for full-bleed screens like a calendar or kanban board. |

## Layout containers

### BeakFormLayout

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormLayout({
  required this.children,
  this.spacingInPixels = 16,
  this.showChangeIndicators = false,
  super.visibleIf,
  super.enabledIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `children` | `List<BeakFormNode>` | required | Ordered child nodes rendered in this layout |
| `spacingInPixels` | `double` | `16` | Vertical spacing for plain layouts and tab contents |
| `showChangeIndicators` | `bool` | `false` | Marks modified field headings and added owned rows while editing a persisted record. Markers use the existing draft baseline, not extra state. |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

`showChangeIndicators` is read from the root layout only. `BeakFormLayout.fromModel` builds the layout used when a screen declares none:

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
factory BeakFormLayout.fromModel(
  BeakModel model, {
  BeakModelRegistry? registry,
  BeakContext surface = BeakContext.form,
}) {
  // ...
}
```

It places one input for each column visible on `surface`, a form unless the caller asks for `BeakContext.detail`, skipping the primary key and custom columns. The generated read page asks for `detail`. A belongs-to foreign key becomes a `BeakRelationInput` when the target model is in the registry, and a plain input otherwise.

### BeakCard

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakCard({
  this.title,
  required super.children,
  this.description,
  this.padding,
  this.headerGapInPixels = 16,
  this.headerSubtitle,
  this.headerTrailing,
  this.collapseLeading = false,
  this.disclosurePadding,
  this.collapsible = false,
  this.initiallyExpanded = true,
  this.presentation = BeakCardPresentation.surface,
  super.spacingInPixels,
  super.visibleIf,
  super.enabledIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String?` | none | Heading displayed above this content |
| `children` | `List<BeakFormNode>` | required | Ordered child nodes rendered in this layout |
| `description` | `String?` | none | Optional guidance below the card heading |
| `padding` | `EdgeInsetsGeometry?` | none | Inner inset of a surface card; omitted values follow the card theme. Plain sections keep their borderless layout without an additional inset. |
| `headerGapInPixels` | `double` | `16` | Space after a surface card header; ignored when no header is declared |
| `headerSubtitle` | `BeakValueBinding<Object>?` | none | Typed supporting metadata retained below the heading when collapsed |
| `headerTrailing` | `BeakValueBinding<Object>?` | none | Typed caption at the trailing edge of the heading |
| `collapseLeading` | `bool` | `false` | Places the disclosure before the heading for compact summary cards |
| `disclosurePadding` | `EdgeInsetsGeometry?` | none | Optional interior header spacing for a plain collapsible card |
| `collapsible` | `bool` | `false` | Allows collapsing the card without removing its fields from the draft |
| `initiallyExpanded` | `bool` | `true` | Initial expansion state when `collapsible` is enabled |
| `presentation` | `BeakCardPresentation` | `BeakCardPresentation.surface` | Surface geometry; the same draft owns both presentations |
| `spacingInPixels` | `double` | `16` | Vertical spacing for plain layouts and tab contents |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

`BeakCardPresentation` values: `surface` (themed card with border and padding) and `plain` (borderless; a collapsible plain card uses an inline disclosure header).

### BeakSection

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakSection({
  required this.title,
  required super.children,
  this.description,
  this.descriptionStyle,
  this.titleStyle,
  this.titleColor,
  this.trailing,
  this.headingGapInPixels = 4,
  this.gapInPixels = 16,
  this.divider = false,
  this.dividerAfterSpacingInPixels = 0,
  super.visibleIf,
  super.enabledIf,
}) : assert(headingGapInPixels >= 0),
     assert(gapInPixels >= 0);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | Section heading |
| `children` | `List<BeakFormNode>` | required | Ordered child nodes rendered in this layout |
| `description` | `String?` | none | Optional guidance below the heading |
| `descriptionStyle` | `TextStyle?` | none | Optional typography for section guidance; the theme body is the default |
| `titleStyle` | `TextStyle?` | none | Optional heading typography; unspecified properties inherit the theme |
| `titleColor` | `BeakColor?` | none | Optional semantic heading color, resolved from the current theme |
| `trailing` | `BeakValueBinding<Object>?` | none | Short typed metadata beside the section heading, wrapping when needed |
| `headingGapInPixels` | `double` | `4` | Spacing between the heading and its supporting description |
| `gapInPixels` | `double` | `16` | Spacing between the heading group and each content node |
| `divider` | `bool` | `false` | Separates this section from a preceding section with the themed divider |
| `dividerAfterSpacingInPixels` | `double` | `0` | Additional spacing after a section separator, independent of content gaps |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

### BeakColumns

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakColumns({
  required super.children,
  this.columns = 2,
  this.minColumnWidthInPixels = 280,
  this.gapInPixels = 16,
  this.columnWidths = const [],
  this.padding = EdgeInsets.zero,
  super.visibleIf,
  super.enabledIf,
}) : assert(columns > 0),
     assert(minColumnWidthInPixels > 0);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `children` | `List<BeakFormNode>` | required | Ordered child nodes rendered in this layout |
| `columns` | `int` | `2` | Number of columns at the active responsive breakpoint |
| `minColumnWidthInPixels` | `double` | `280` | Minimum comfortable column width before the layout stacks vertically |
| `gapInPixels` | `double` | `16` | Gap between columns and stacked children |
| `columnWidths` | `List<double?>` | `const []` | Optional fixed widths; null cells share the remaining available width |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.zero` | Optional inset around this group without introducing another surface |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

### BeakTabs and BeakTab

Every tab is validated and saved by the enclosing form; tabs add no controller or save handler.

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakTabs({
  required List<BeakTab> tabs,
  this.initialIndex = 0,
  this.acrossRegions = false,
  super.visibleIf,
  super.enabledIf,
}) : assert(initialIndex >= 0),
     super(children: tabs);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `tabs` | `List<BeakTab>` | required | Tabs in display order |
| `initialIndex` | `int` | `0` | Initially active tab, clamped when visibility reduces the tab count |
| `acrossRegions` | `bool` | `false` | Promotes a sole root tab selector above both content and aside regions |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakTab({
  required this.title,
  required super.children,
  super.spacingInPixels,
  this.icon,
  this.badge,
  this.showValidationBadge = true,
  super.visibleIf,
  super.enabledIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | Text displayed on the tab selector |
| `children` | `List<BeakFormNode>` | required | Ordered child nodes rendered in this layout |
| `spacingInPixels` | `double` | `16` | Vertical spacing for plain layouts and tab contents |
| `icon` | `IconData?` | none | Optional icon displayed beside the tab title |
| `badge` | `BeakValueBinding<int>?` | none | Optional live count; validation errors take precedence when present |
| `showValidationBadge` | `bool` | `true` | Whether this tab exposes a validation count beside its title |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

Validation errors take precedence over `badge` when both apply. `BeakTabs.tabs` returns the declared tabs.

### BeakWizardStep

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakWizardStep({
  required this.title,
  required super.children,
  this.description,
  this.heading,
  this.introduction,
  this.introductionBuilder,
  this.continueLabel,
  this.completedDescription,
  this.footerHint,
  this.footerHintBuilder,
  this.dependencies = const [],
  super.spacingInPixels,
  super.visibleIf,
  super.enabledIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | Short title displayed in step navigation |
| `children` | `List<BeakFormNode>` | required | Ordered child nodes rendered in this layout |
| `description` | `String?` | none | Short guidance displayed in step navigation |
| `heading` | `String?` | none | Main step heading, pinned above a rail wizard's scrolling inputs. Defaults to `title`; ordinary sections remain part of the scrolling body. |
| `introduction` | `String?` | none | Main step guidance, independent of the short navigation description. Defaults to `description`. |
| `introductionBuilder` | `String Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Live introductory text derived from this wizard's single draft |
| `continueLabel` | `String?` | none | Optional context-specific forward label, preserving automatic validation |
| `completedDescription` | `String? Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Replaces navigation guidance after this step has been completed. Reads the shared live draft and panel formatting policy, so returning to edit updates the summary without creating another owner for its state. |
| `footerHint` | `String?` | none | Supporting text between the back and continue actions in a rail wizard |
| `footerHintBuilder` | `String Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Live footer guidance; ordinary navigation and validation remain automatic |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Related values used by live step metadata, loaded with the form |
| `spacingInPixels` | `double` | `16` | Vertical spacing for plain layouts and tab contents |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

Moving forward validates every step before the target, and a failed step stays current. A failed submit returns to the first invalid step. Steps share one draft, so values and related edits survive navigation.

### BeakReviewSection

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakReviewSection({
  required this.title,
  required super.children,
  this.stepIndex,
  this.divider = true,
  this.dividerSpacingInPixels = 20,
  this.padding = EdgeInsets.zero,
  this.contentPadding = EdgeInsets.zero,
  this.titleStyle,
  super.visibleIf,
  super.enabledIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | Label shown beside the review content, or above it on compact screens |
| `children` | `List<BeakFormNode>` | required | Ordered child nodes rendered in this layout |
| `stepIndex` | `int?` | none | Zero-based wizard step opened by the automatic Edit link |
| `divider` | `bool` | `true` | Separates review rows; the final row can lead directly into totals |
| `dividerSpacingInPixels` | `double` | `20` | Space between this row and its optional separator |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.zero` | Insets around the review content, before its separator |
| `contentPadding` | `EdgeInsetsGeometry` | `EdgeInsets.zero` | Insets within the content column, independent of the row heading |
| `titleStyle` | `TextStyle?` | none | Optional heading typography within a compact review hierarchy |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

### BeakModeLayout

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakModeLayout({required this.read, required this.edit})
  : super(children: [read, edit]);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `read` | `BeakFormLayout` | required | Presentation while the parent form is read-only |
| `edit` | `BeakFormLayout` | required | Presentation while the parent form is editable |

Both branches remain in the same graph, so the dependencies of both are declared and loaded.

### BeakFormSections

One list of sections, shown as a stacked form, as tabs or as wizard steps. Conditions stay on the section.

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
final class BeakFormSections {
  const BeakFormSections({required this.sections});
  final List<BeakSection> sections;
  BeakFormLayout get form => BeakFormLayout(children: sections);
  BeakTabs get tabs => BeakTabs(
  // ...
  List<BeakWizardStep> get steps => [
```

| Member | Type | Meaning |
| --- | --- | --- |
| `sections` | `List<BeakSection>` | Ordered, titled sections shared by every projection |
| `form` | `BeakFormLayout` | The sections in a stacked layout |
| `tabs` | `BeakTabs` | One tab per section, each wrapping a copy of the section |
| `steps` | `List<BeakWizardStep>` | One step per section |

The projections carry the section's title, description, `visibleIf`, `enabledIf` and children. `tabs` also copies the section's title style, color, description style, `trailing`, gaps and divider with the space after it. `steps` does not copy any styling, `trailing` or the divider.

### BeakFormDivider

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormDivider({super.visibleIf});
```

Takes only `visibleIf`. The surrounding layout owns the vertical spacing.

## Presentation nodes

### BeakFormHeader

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormHeader({
  required this.title,
  this.description,
  this.showClose = true,
  this.showDraftAction = true,
  this.showDraftSavedAt = true,
  super.visibleIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | Workflow name |
| `description` | `String?` | none | Optional supporting text beside the title |
| `showClose` | `bool` | `true` | Offers the ordinary guarded return to the resource list |
| `showDraftAction` | `bool` | `true` | Offers local draft persistence when the screen configures a draft store |
| `showDraftSavedAt` | `bool` | `true` | Shows the last successful local draft write, including automatic saves |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

### BeakFormTemplate and BeakFormPlaceholder

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormTemplate({required this.template, super.visibleIf});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `template` | `BeakRecordTemplate` | required | Typed presentation reused across forms, lists and relationship choices |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormPlaceholder({
  required this.label,
  this.heightInPixels = 96,
  this.template,
  super.visibleIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | Explanation of the missing selection or empty section |
| `heightInPixels` | `double` | `96` | Minimum presentation height |
| `template` | `BeakRecordTemplate?` | none | Optional live preview of the record that will populate this region |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

### BeakFormNotice

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormNotice({
  required this.message,
  this.title,
  this.titleBuilder,
  this.tone = BeakColor.info,
  this.inline = false,
  this.plain = false,
  this.icon,
  this.caption,
  this.captionIcon,
  this.dependencies = const [],
  super.visibleIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `message` | `String Function(BeakFormReader state)` | required | Message evaluated from the same draft as surrounding inputs |
| `title` | `String?` | none | Optional heading |
| `titleBuilder` | `String Function(BeakFormReader state)?` | none | Optional live heading over `dependencies`, with `title` as a fallback |
| `tone` | `BeakColor` | `BeakColor.info` | Semantic severity; informational colors use the standard info treatment |
| `inline` | `bool` | `false` | Places the heading and message on one wrapping line |
| `plain` | `bool` | `false` | Uses a compact icon-and-text line without a banner surface |
| `icon` | `IconData?` | none | Optional semantic icon, including for neutral notices |
| `caption` | `String? Function(BeakFormReader state)?` | none | Optional short annotation at the trailing edge of the notice |
| `captionIcon` | `IconData?` | none | Optional decorative icon next to the trailing annotation |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Related values to load when no editable placement requests them |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

### BeakFormMetrics and BeakFormMetric

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormMetrics({
  required this.metrics,
  this.minColumnWidthInPixels = 200,
  this.padding = const EdgeInsets.all(20),
  this.gapInPixels = 6,
  this.inset = false,
  super.visibleIf,
}) : assert(minColumnWidthInPixels > 0);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `metrics` | `List<BeakFormMetric>` | required | Ordered metric cells |
| `minColumnWidthInPixels` | `double` | `200` | Minimum cell width before metrics wrap into another row |
| `padding` | `EdgeInsetsGeometry` | `const EdgeInsets.all(20)` | Interior spacing shared by all metric cells |
| `gapInPixels` | `double` | `6` | Spacing between label, value, and description |
| `inset` | `bool` | `false` | A subdued inset strip without an outer card border |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormMetric({
  required super.label,
  required super.value,
  super.format,
  super.labelBuilder,
  super.dependencies,
  this.description,
  super.subtitle,
  super.valueStyle,
  this.flex = 1,
}) : assert(flex > 0);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | Metric name |
| `value` | `Object? Function(BeakFormReader state)` | required | Live value; never persisted by this presentation |
| `format` | `BeakValueFormat` | `BeakValueFormat.text` | Shared panel formatting policy |
| `labelBuilder` | `String Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Optional reactive label, with `label` as its configuration fallback |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Related fields used by this metric, loaded automatically |
| `description` | `String?` | none | Optional supporting explanation |
| `subtitle` | `String? Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Secondary explanation below the label, such as an included tax breakdown |
| `valueStyle` | `TextStyle?` | none | Typography merged with the value's normal or emphasized theme variant |
| `flex` | `int` | `1` | Relative horizontal space within each responsive row |

### BeakFormSummary and BeakSummaryLine

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormSummary({
  required this.lines,
  this.title,
  this.titleStyle,
  this.maxWidthInPixels,
  this.titleColor,
  this.labelColor,
  this.alignment = AlignmentDirectional.centerStart,
  this.gapInPixels = 12,
  this.headingGapInPixels,
  this.source,
  super.visibleIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `lines` | `List<BeakSummaryLine>` | required | Ordered live values |
| `title` | `String?` | none | Optional heading |
| `titleStyle` | `TextStyle?` | none | Optional typography for the summary heading |
| `maxWidthInPixels` | `double?` | none | Optional width cap, useful for invoice totals inside a wide section |
| `titleColor` | `BeakColor?` | none | Semantic heading color resolved from the current light/dark theme |
| `labelColor` | `BeakColor?` | none | Semantic color of ordinary labels; emphasized totals retain normal ink |
| `alignment` | `AlignmentGeometry` | `AlignmentDirectional.centerStart` | Placement of the capped summary within the available width |
| `gapInPixels` | `double` | `12` | Vertical spacing between individual summary lines |
| `headingGapInPixels` | `double?` | none | Spacing after the heading; defaults to `gapInPixels` |
| `source` | `BeakToManyField?` | none | Repeats `lines` for each live child draft, including staged changes. Line dependencies are relative to the child model and load automatically. Omit to summarize the enclosing record. |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakSummaryLine({
  required this.label,
  required this.value,
  this.format = BeakValueFormat.text,
  this.emphasized = false,
  this.dependencies = const [],
  this.labelBuilder,
  this.subtitle,
  this.visibleIf,
  this.dividerBefore = false,
  this.dividerSpacingInPixels = 0,
  this.valueStyle,
  this.labelStyle,
  this.valueCaption,
  this.valueLabel,
  this.subtitleStyle,
  this.subtitleGapInPixels = 2,
  this.afterSpacingInPixels = 0,
  this.valueAlignment = CrossAxisAlignment.start,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | Left-hand label |
| `value` | `Object? Function(BeakFormReader state)` | required | Live value; it is never persisted by this presentation |
| `format` | `BeakValueFormat` | `BeakValueFormat.text` | Shared panel formatting policy |
| `emphasized` | `bool` | `false` | Highlights a subtotal or other important line |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Related fields used only by this summary, loaded automatically |
| `labelBuilder` | `String Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Optional reactive label, with `label` as its configuration fallback |
| `subtitle` | `String? Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Secondary explanation below the label, such as an included tax breakdown |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `dividerBefore` | `bool` | `false` | Adds a themed separator above an important line, such as the grand total |
| `dividerSpacingInPixels` | `double` | `0` | Extra vertical space on each side of `dividerBefore`, in addition to the enclosing summary's regular line gap |
| `valueStyle` | `TextStyle?` | none | Typography merged with the value's normal or emphasized theme variant |
| `labelStyle` | `TextStyle?` | none | Typography merged with the label's normal or emphasized theme variant |
| `valueCaption` | `String? Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Optional short context before the value, such as its previous amount |
| `valueLabel` | `String Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Optional formatted value text, for example an amount followed by “left” |
| `subtitleStyle` | `TextStyle?` | none | Typography merged with the secondary explanation |
| `subtitleGapInPixels` | `double` | `2` | Gap between the label and its secondary explanation |
| `afterSpacingInPixels` | `double` | `0` | Additional space below this line, before the summary line gap |
| `valueAlignment` | `CrossAxisAlignment` | `CrossAxisAlignment.start` | Alignment of a horizontal value beside its label and subtitle |

### BeakFormCapacity

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormCapacity({
  required this.label,
  required this.value,
  required this.max,
  this.subtitle,
  this.warningText,
  this.warningThreshold = .9,
  this.format = BeakValueFormat.number,
  this.dependencies = const [],
  this.showValue = true,
  this.showLabel = true,
  this.caption,
  this.valueLabel,
  this.heightInPixels = 4,
  this.gapInPixels,
  this.labelStyle,
  this.valueStyle,
  super.visibleIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | Capacity label |
| `value` | `num? Function(BeakFormReader state)` | required | Current utilization |
| `max` | `num? Function(BeakFormReader state)` | required | Total available capacity |
| `subtitle` | `String?` | none | Optional supporting explanation |
| `warningText` | `String?` | none | Optional near-capacity message |
| `warningThreshold` | `double` | `.9` | Utilization ratio activating the warning treatment |
| `format` | `BeakValueFormat` | `BeakValueFormat.number` | Number or currency presentation shared with the panel |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Related fields required by this presentation |
| `showValue` | `bool` | `true` | Whether the numeric ratio is displayed beside the title |
| `showLabel` | `bool` | `true` | Keeps a capacity bar's accessible label while optionally hiding its title |
| `caption` | `String? Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Reactive supporting explanation below the bar |
| `valueLabel` | `String Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Optional localized value text, for example a remaining balance |
| `heightInPixels` | `double` | `4` | Track height, independent of text and available width |
| `gapInPixels` | `double?` | none | Optional spacing around the track |
| `labelStyle` | `TextStyle?` | none | Optional label typography for dense summaries |
| `valueStyle` | `TextStyle?` | none | Optional ratio typography independent of the capacity label |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

### BeakFormProgress and BeakProgressStep

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormProgress({
  required this.field,
  this.states,
  this.steps,
  this.initialState,
  this.planned = false,
  this.labelStyle,
  this.timeline = false,
  this.contextSpacingInPixels = 6,
  super.visibleIf,
}) : assert(states == null || steps == null);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `field` | `BeakScalarField<T>` | required | Current state, updated only by ordinary model behavior or commands |
| `states` | `List<T>?` | none | Optional normal workflow sequence, excluding alternate terminal states |
| `steps` | `List<BeakProgressStep<T>>?` | none | Explicit milestones, including optional preceding events and metadata |
| `initialState` | `T?` | none | Presentation fallback used only while the stored state is absent or null. It does not change the draft or replace unknown/alternate stored states. |
| `planned` | `bool` | `false` | Displays a neutral numbered plan without inferring persisted progress |
| `labelStyle` | `TextStyle?` | none | Optional milestone label typography, retaining semantic state indicators |
| `timeline` | `bool` | `false` | Uses an intrinsic connected rail for vertical detailed milestones. Defaults to the existing separated connector layout. |
| `contextSpacingInPixels` | `double` | `6` | Spacing between milestone details and the contextual record |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakProgressStep({
  required this.label,
  this.state,
  this.details,
  this.context,
  this.contextInset = false,
  this.labelBuilder,
  this.dependencies = const [],
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | Concise milestone name |
| `state` | `T?` | none | Model state represented by this milestone |
| `details` | `BeakRecordTemplate?` | none | Optional time, actor or other record information below the milestone |
| `context` | `BeakRecordTemplate?` | none | Optional contextual identity beneath the step description |
| `contextInset` | `bool` | `false` | Places supplemental identity in a padded neutral surface |
| `labelBuilder` | `String Function(BeakFormReader state)?` | none | Contextual milestone label using the existing form draft |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Additional fields used by `labelBuilder` |

`states` and `steps` are exclusive. Omitting both uses the enum column's value order. A step without `state` is a milestone that precedes the first matching state.

### BeakFormTimeline

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormTimeline({
  required this.field,
  required this.title,
  required this.time,
  this.description,
  this.compact = false,
  this.messages = false,
  this.emphasizeMentions = false,
  this.inlineTime = false,
  this.actor,
  this.messageIdentity,
  this.columns = 1,
  super.visibleIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `field` | `BeakToManyField` | required | History relation on the enclosing record |
| `title` | `BeakScalarField<String>` | required | Primary text on the history row model |
| `time` | `BeakScalarField<DateTime>` | required | Event time on the history row model |
| `description` | `BeakScalarField<String>?` | none | Optional secondary text on the history row model |
| `compact` | `bool` | `false` | Renders compact activity rows rather than individual cards |
| `messages` | `bool` | `false` | Presents author/time above a neutral message bubble |
| `emphasizeMentions` | `bool` | `false` | Highlights conventional @Name mentions inside staff message bubbles |
| `inlineTime` | `bool` | `false` | Shows compact time-first connected rows, arranged down each column |
| `actor` | `BeakValueBinding<String>?` | none | Optional actor shown with emphasis before the event title |
| `messageIdentity` | `BeakRecordTemplate?` | none | Typed identity shown above message bubbles |
| `columns` | `int` | `1` | Maximum responsive columns used by the compact presentation |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

### BeakFormLinks and BeakFormLink

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormLinks({required this.links, super.visibleIf, super.enabledIf});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `links` | `List<BeakFormLink>` | required | Ordered links; unavailable or unreadable destinations are omitted |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormLink({
  required this.label,
  required this.destination,
  this.icon,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | Visible and accessible action label |
| `destination` | `BeakValueBinding<String>` | required | Safe absolute URI string, for example `mailto:person@example.com` |
| `icon` | `IconData?` | none | Optional themed action icon |

Only safe schemes can launch. A link whose destination is unavailable or unreadable is omitted.

### BeakFormActions and BeakFormActionInput

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormActions({this.actions, super.visibleIf, super.enabledIf});
```

`actions` null shows every currently available model command; a list shows exactly those commands, in order.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `actions` | `List<BeakModelAction>?` | none | Explicit commands, in display order |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormActionInput({
  required this.action,
  this.layout,
  this.submitWithForm,
  this.optionalWithForm = false,
  this.description,
  this.editDescription,
  this.inlineFooter = false,
  this.footerMinHeightInPixels = 0,
  super.visibleIf,
  super.enabledIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `action` | `BeakModelAction` | required | Authoritative command used by the inline button in read mode |
| `layout` | `BeakFormLayout?` | none | Argument placements; omitted uses the command's input model conventions |
| `submitWithForm` | `BeakModelAction?` | none | Primary edit command that accepts the same argument fields |
| `optionalWithForm` | `bool` | `false` | Allows an entirely empty argument form when submitting with the record. The primary command's input model must also permit empty arguments. |
| `description` | `String?` | none | Supporting text below the inputs |
| `editDescription` | `String?` | none | Supporting text while the arguments save with the parent edit |
| `inlineFooter` | `bool` | `false` | Places guidance and a compact primary action on the same footer row |
| `footerMinHeightInPixels` | `double` | `0` | Optional minimum footer height across read and staged edit modes |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

The arguments belong to the parent session, including its unsaved-change guard and optional durable drafts. They are never written as record fields. The commands themselves are described in [Behavior and actions](behavior-and-actions.md).

### BeakFormLock

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormLock({
  required this.label,
  this.description,
  this.icon,
  super.visibleIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | The action which cannot currently be performed |
| `description` | `String?` | none | Explains why the action is unavailable |
| `icon` | `IconData?` | none | Optional lock or other contextual icon |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

A disabled control with contextual guidance. It registers no callable command.

### BeakCalculated

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakCalculated({
  required this.value,
  this.label,
  this.labelBuilder,
  this.description,
  this.subtitle,
  this.textAlign = TextAlign.start,
  this.valueStyle,
  this.display,
  this.descriptionTone = BeakColor.muted,
  this.icon,
  this.presentation = BeakCalculatedPresentation.text,
  this.dependencies = const [],
  this.format = BeakValueFormat.text,
  super.visibleIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `value` | `Object? Function(BeakFormReader state)` | required | Reactive display calculation; its result is never submitted |
| `label` | `String?` | none | Optional label overriding the model metadata |
| `labelBuilder` | `String Function(BeakFormReader state)?` | none | Contextual label evaluated from the same draft as `value` |
| `description` | `String Function(BeakFormReader state)?` | none | Supporting explanation below a field or locked checkbox |
| `subtitle` | `String? Function(BeakFormReader state, BeakFormatPolicy formatting)?` | none | Secondary value text using the same global format policy as `value` |
| `textAlign` | `TextAlign` | `TextAlign.start` | Alignment of the formatted value and its subtitle |
| `valueStyle` | `TextStyle?` | none | Optional semantic value typography override |
| `display` | `String Function(Object? value, BeakFormatPolicy formatting)?` | none | Pure contextual formatting using the panel locale and timezone policy |
| `descriptionTone` | `BeakColor` | `BeakColor.muted` | Tone of the supporting caption in a labelled detail presentation |
| `icon` | `IconData?` | none | Optional leading value icon, for example a locked date or shipping mode |
| `presentation` | `BeakCalculatedPresentation` | `BeakCalculatedPresentation.text` | Display treatment; calculated values are never editable or submitted |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Explicit dependencies for automatic relation loading and read access |
| `format` | `BeakValueFormat` | `BeakValueFormat.text` | Shared panel formatting for the calculated result |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |

| `BeakCalculatedPresentation` | Renders |
| --- | --- |
| `text` | Inline text, optionally prefixed by a label |
| `field` | A labelled field with a subdued value surface |
| `checkbox` | A locked checkbox showing an automatic rule or requirement |
| `detail` | A caption, a readable value and an optional supporting caption, without a box |
| `message` | A labelled, neutral message well for read-only notes or quotations |

### BeakFormWidget

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakFormWidget({
  required this.builder,
  this.showOnRead = true,
  super.visibleIf,
  super.enabledIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `builder` | `Widget Function(BuildContext context, BeakDraftRecord draft)` | required | Custom content builder with access to the same local draft |
| `showOnRead` | `bool` | `true` | Whether this custom content is useful on a record's read surface |
| `visibleIf` | `BeakVisibility?` | none | Predicate over the live draft; false hides the node and its descendants |
| `enabledIf` | `BeakVisibility?` | none | Predicate over the live draft; false disables the node and its descendants |

## Draft access

### BeakFormReader

The tracked reader every predicate, builder and calculation receives.

| Member | Type | Meaning |
| --- | --- | --- |
| `read<T>(BeakFieldRef<T> field)` | `T?` | Typed value of a field of this record; records the dependency. Throws `BeakConfigurationException` for a field of another model |
| `rows(BeakToManyField field)` | `List<BeakFormReader>` | Readers over the current rows of a collection; tracks membership |
| `draft` | `BeakDraftRecord` | The record this reader observes |
| `stepIndex` | `int` | Zero-based wizard step, or 0 for a single-page form |
| `parent` | `BeakFormReader?` | The owning record's reader, when this reader belongs to a related row |
| `root` | `BeakFormReader` | The reader of the form's root record |
| `reads` | `Set<String>` | Field paths accessed so far |

### BeakDraftRecord

One local record in the form graph. It never persists itself; the session saves the whole graph.

| Member | Type | Meaning |
| --- | --- | --- |
| `read<T>(BeakFieldRef<T> field)` | `T?` | Typed value |
| `set<T>(BeakScalarField<T> field, T? value)` | `void` | Updates a field; ignored while a save is in flight or unresolved. Throws for a field of another model or with a path |
| `snapshot` | `BeakRecord` | The complete local record, hidden values and relations included |
| `errors` | `Map<String, List<String>>` | Validation and server errors by field key |
| `isDirty` | `bool` | Whether unapplied scalar or relationship changes exist |
| `rows(BeakToManyField field)` | `List<BeakDraftRecord>` | The current rows of a collection, staged removals excluded |
| `addRow(BeakToManyField field, {BeakRecord? values})` | `BeakDraftRecord` | Adds an unsaved row; throws when the table disallows adding |
| `removeRow(BeakDraftRecord row)` | `void` | Stages a removal, or discards a new row |
| `restoreRow(BeakDraftRecord row)` | `void` | Cancels a staged removal |
| `enabled(BeakFormNode node)` | `bool` | Effective editability, including ancestors, permissions and model behavior |
| `visible(BeakFormNode node)` | `bool` | Whether the server permits displaying the placement |
| `validate({Set<BeakFormNode>? only})` | `Future<bool>` | Validates the visible placements, awaiting asynchronous rules |

### BeakDraftScope and BeakRecordScope

| Class | Provided by | Read with | Use |
| --- | --- | --- | --- |
| `BeakDraftScope` | The configured form, around each `BeakFormWidget` | `BeakDraftScope.of(context)`; throws `BeakConfigurationException` when none is mounted | A custom widget edits the draft, respecting `readOnly` and `enabled` |
| `BeakRecordScope` | Your code, around a block tree; no built-in page mounts it | `BeakRecordScope.of(context)`; returns null when none is mounted | Record blocks (`BeakFieldBlock`, `BeakFieldGroupBlock`, `BeakRelationBlock`) resolve values from the record it carries |

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakDraftScope({
  required this.draft,
  required this.readOnly,
  required this.enabled,
  required super.child,
  super.key,
});
```

```dart title="packages/beak_frontend/lib/src/detail/beak_record_scope.dart"
const BeakRecordScope({
  required this.model,
  required this.record,
  required super.child,
  super.key,
});
```

## Rules and limits

| Rule | Behavior |
| --- | --- |
| One screen per role | Two screens claiming the same role on one resource throw a `BeakConfigurationException` when the panel builds its registry, at startup |
| Form screens and lists | A `BeakFormScreen` with the `list` role throws `A form screen cannot serve the list route.` at startup |
| Table screen query | `BeakTableScreen.query` must target the resource's table; otherwise a `BeakConfigurationException` at startup |
| Default roles | `BeakFormScreen` and `BeakWizardScreen` default to `{create, edit}`. The show page uses the generated read layout until `read` is added |
| Wizard chrome | A screen with `steps`, or with `fullScreen: true`, does not use the generated page frame; `showBack`, `pagePadding` and `pageGapInPixels` do not apply, and `recordHeader` is not placed |
| Regions | `header`, `aside`, `asideFooter` and `footer` are appended to the root layout, so they share the draft and its dependencies |
| Root only | `showChangeIndicators` is read from the root layout; `BeakCard`, `BeakSection` and the other layout subclasses do not accept it |
| Inline commands | Each `BeakFormActionInput` needs a command with an input model, command names must be unique in the form, and `submitWithForm` must share the argument model of the inline command; otherwise a `BeakConfigurationException` when the session is created |
| Calculated values | `BeakCalculated`, `BeakFormSummary`, `BeakFormMetrics` and `BeakFormCapacity` display values. None of them is submitted or validated |
| Hidden by permission | A node whose field the account cannot read is hidden even when its `visibleIf` is true |
| Asserts | `BeakColumns` needs `columns` and `minColumnWidthInPixels` above 0, `BeakSection` needs non-negative gaps, `BeakTabs` a non-negative `initialIndex`, `BeakFormMetric` a `flex` above 0, `BeakFormMetrics` a `minColumnWidthInPixels` above 0, and `BeakFormProgress` not both `states` and `steps`. These fail in debug builds |
| Sections projection | `BeakFormSections.steps` drops the styling, `trailing` and divider of a section, as listed under that class |

## Source

- `packages/beak_frontend/lib/src/panel/beak_resource_screen.dart`: `BeakScreenRole`, `BeakResourceScreen`, `BeakFormScreen`, `BeakWizardScreen`, `BeakTableScreen`, `BeakCustomResourceScreen`.
- `packages/beak_frontend/lib/src/panel/beak_screen.dart`: `BeakScreen`.
- `packages/beak_frontend/lib/src/panel/beak_resource.dart`: `BeakResource.screens` and `screenFor`.
- `packages/beak_frontend/lib/src/panel/beak_panel_config.dart`: the setup checks in `buildRegistry`.
- `packages/beak_frontend/lib/src/panel/beak_router.dart` and `packages/beak_frontend/lib/src/pages/beak_resource_pages.dart`: which route renders which screen.
- `packages/beak_frontend/lib/src/pages/beak_default_show_layout.dart`: the generated read layout.
- `packages/beak_frontend/lib/src/form/beak_form_layout.dart`: every node and layout class, `BeakFormMode` and `BeakWizardNavigation`.
- `packages/beak_frontend/lib/src/form/beak_form_session.dart`: `BeakFormReader`, `BeakDraftRecord` and the session checks.
- `packages/beak_frontend/lib/src/detail/beak_record_scope.dart`: `BeakRecordScope`.

## Continue reading

- [Input builders](input-builders.md) the inputs, relationship pickers and table editors placed inside these containers.
- [Form screens](../forms/form-screens.md) writing a screen from the model up, with worked layouts.
- [Multi-step forms](../forms/multi-step-forms.md) validation and navigation across wizard steps.
- [Workflow presentations](../forms/workflow-presentations.md) regions, record templates and catalog editors over one draft.
