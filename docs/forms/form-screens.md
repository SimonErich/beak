---
title: Form screens
description: Write one BeakFormScreen and get the create, edit and read pages of a resource from the same typed layout of cards, columns, tabs and inputs.
type: guide
audience: [beginner]
status: stable
---

# Form screens

After this page you can write a form for a resource once and get its create page, its edit page and its read page from it. You will also know which parts of that form the server never sees.

Beak already generates a form for every resource, one input per column. You write a screen when that default is not enough: grouping, conditions, a different control, a table of related rows.

## At a glance

A `BeakFormScreen` goes into the resource's `screens:` list. Its `layout` is a tree of typed placements, and `roles` names the routes that render it. The shop's customer form serves all three:

```dart title="examples/clean_beak_config/lib/resources/users/screens/user_form_screen.dart"
--8<-- "examples/clean_beak_config/lib/resources/users/screens/user_form_screen.dart"
```

Three things to notice:

- `UserModel.email.inputText()` is a method on a generated field, so there is no string key anywhere in the tree. A typo is a compile error.
- `visibleIf` receives the live draft. `state.asUser.companyId` is a typed view that `beak prepare` generates next to the model, so the toggle appears the moment a company is picked.
- `UserModel.profiles.tableForm(...)` edits the customer's delivery profiles inside the same form. Those rows are saved with the customer, in one commit. [Related records in forms](related-records.md) covers that part.

## Roles: one layout, three routes

`roles` decides where the layout is used. A form screen serves `create` and `edit` unless you say otherwise.

| Role | Route | The layout renders as |
| --- | --- | --- |
| `create` | `/<table>/create` | An empty draft, with model defaults applied |
| `edit` | `/<table>/<id>/edit` | A draft loaded from the record |
| `read` | `/<table>/<id>` | The same tree with values instead of editors |

Leave `read` out and the show page keeps its generated layout (the resource's inputs as values, plus a tab for each to-many relationship). Add it and the show page renders your layout, with an Edit button that flips the same page into edit mode in place. [Detail views](detail-views.md) covers what read mode looks like.

What happens after Save depends on where the form ran:

| Form | After a confirmed save |
| --- | --- |
| Create page | Back to where you came from (the `returnTo` query parameter, else the list) |
| Edit page | The record's show page |
| Read page in edit mode | Back to read mode, same page |

Cancel and navigation both stop at a confirmation when the draft has unsaved changes.

The Edit button is offered only when the resource allows it (`canEdit` on the resource, plus the model's update permission) and the model's `editableWhen` accepts the loaded record. Those checks hide UI, they do not enforce anything. The server checks again on every write.

## The layout tree

Containers group, inputs edit, and everything sits over one draft. The ones you will use in most forms:

| Node | Use it for |
| --- | --- |
| `BeakColumns` | Side-by-side groups that stack on narrow screens |
| `BeakCard` | A titled surface, optionally collapsible |
| `BeakSection` | A heading with a description and no border |
| `BeakTabs` and `BeakTab` | Tabbed groups; every tab is validated and saved together |
| `BeakFormLayout` | A plain group that carries a `visibleIf` or `enabledIf` for its children |

Every node accepts `visibleIf` and `enabledIf`. A hidden input is not validated and is not submitted, so a condition is also a rule about what counts as part of the record. The category form nests tabs, a section and a table editor, and hides one input unless the row is a choice attribute:

```dart title="examples/clean_beak_config/lib/resources/categories/screens/category_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/screens/category_form.dart"
```

`state.read(field)` is the typed reader behind every condition, and it records the dependency, so the node recomputes when that field changes. [Screens and form layouts](../reference/screens-and-layouts.md) lists every container and its parameters.

## When you configure nothing

A resource without a form screen gets `BeakFormLayout.fromModel`: one input per column that is visible in the form context, in declaration order, and a combobox for each belongs-to whose target model is registered. The primary key and custom columns are skipped. That is enough for a lot of resources, and it is why the quickstart has no form code.

The input each column gets is in the [automatic editors table](../reference/input-builders.md#automatic-editors). Write a screen when you need grouping, conditions, a different control or a related-row editor.

## One set of sections, three presentations

An order can be created step by step and read as tabs. `BeakFormSections` holds the sections once and projects them as a stacked form, as tabs or as wizard steps. Conditions stay attached to the section.

```dart title="examples/clean_beak_config/lib/resources/orders/order_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/order_resource.dart"
```

`OrderFormWizardScreen` builds its steps from `orderSections().steps`, and the read screen shows `orderSections().tabs`. The projections copy titles, descriptions and conditions. They do not copy every styling option of a section (the reference lists the gaps), so a section that needs its own look is written per presentation. [Multi-step forms](multi-step-forms.md) picks up from here.

## Values that are not fields

Some values belong on the screen and nowhere in the table: a line total, a summary, a guidance line. `BeakCalculated` reads the draft, formats the result and never submits it. The invoice review is a card of them:

```dart title="examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart:invoiceReview"
```

An input can also follow other fields with `derive:`. The input is then disabled and takes the computed value, which is right for a name copied from a definition and wrong for anything the user should be able to overwrite. If the value should be saved and stay editable, make it a model default or a suggestion in [model behavior](../models/behavior.md), which also runs on the server.

## Rules only the form knows

`validate:` and `validators:` on a placement run in the form and nowhere else. The order wizard uses one to refuse a delivery date in the past when creating:

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart:orderDeliveryDateValidator"
```

That is a usability rule. The API accepts a past date, because historical orders are legitimate. A rule the API must enforce belongs on the schema (`rules:` on the column, or `validationRules`), where the same definition runs in the form and on the server. [Validation](../models/validation.md) covers both.

## Review, inspect, resume

Three switches on the screen change how a save feels without changing what it does:

| Parameter | Effect |
| --- | --- |
| `reviewBeforeSave` | Save opens a "Review changes" dialog listing each changed field (before and after), with Back and Continue |
| `drafts` | Stores the unfinished form locally so it can be resumed, see [Drafts, review and conflicts](drafts-and-review.md) |
| `showInspector` | Adds an "Inspect form" button that lists every field with its visibility, dependencies and validation, for development |

The product form turns on the first two:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductFormScreen"
```

## A widget of your own

When a piece of the form is not an input, `BeakFormWidget` puts any widget inside the layout and hands it the draft. The shop's variant builder is one: it previews combinations of sizes and finishes and adds the chosen ones as ordinary unsaved variant rows, so Save, Cancel, validation and review stay under Beak's control.

```dart title="examples/clean_beak_config/lib/resources/products/screens/product_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:variantBuilderWidget"
```

`showOnRead: false` keeps it off the read page, where a builder makes no sense. Inside the widget, `BeakDraftScope.of(context)` says whether editing is allowed right now, and the `draft` argument is the same object the inputs edit:

```dart title="examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart:variantBuilderEnabled"
```

## Outside a resource

`BeakConfiguredForm` is the widget every screen mounts. Use it directly when a form has to live outside a resource route, in a dialog or a custom page. It takes the model, a data source and the same `layout` or `steps`:

```dart title="examples/clean_beak_config/test/shop_widget_test.dart"
--8<-- "examples/clean_beak_config/test/shop_widget_test.dart:standaloneForm"
```

`onSession` hands you the `BeakFormSession`, which is how a test reads the draft. A `BeakFormScreen` does not expose it. [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md) covers the rest of the embedding story.

## Rules and limits

| Rule | Behavior |
| --- | --- |
| One screen per role | Two screens claiming the same role on one resource throw a `BeakConfigurationException` when the panel starts |
| No list route | A `BeakFormScreen` with the `list` role throws at startup. The list is a `BeakTableScreen` |
| Default roles | `create` and `edit`. The show page uses the generated layout until you add `read` |
| Show page columns | The generated show page lists the columns visible in the detail context. A `BeakFormScreen` for the read role shares its layout with the forms, so there the form columns decide |
| Form-only rules | `validate:` and `validators:` are not sent to the server. Put a rule the API must enforce on the schema |
| Hidden means absent | A hidden input is skipped by validation and left out of the submitted record, unless `submitWhenHidden` is true |
| Locked fields | A field the account cannot write, or that model behavior controls, is disabled and left out of the submitted record |
| Calculated values | `BeakCalculated`, summaries, metrics and capacity bars display values. None of them is submitted or validated |
| Presentation permissions | Hiding an Edit button or a field is a courtesy. The server enforces `BeakPolicies` on every write |
| Wizard parameters | `BeakWizardScreen` forwards 26 of the 29 parameters of `BeakFormScreen`. It has no `layout`, `recordHeader` or `editingLabel`. Use `BeakFormScreen(steps: [...])` when you need one of them |

## Verify it

The form runtime is covered by package tests, and the shop's forms have their own. From the repository root:

```bash
cd packages/beak_frontend
flutter test test/src/form/beak_configured_form_test.dart
```

```bash
cd examples/clean_beak_config
flutter test test/fulfillment_form_test.dart test/order_form_test.dart test/invoice_form_test.dart
```

The second command runs six tests and ends with `All tests passed!`. To see a form rather than test one, run the shop (`examples/clean_beak_config`, API on port 8080) and open Customers, then a customer, then Edit.

## Reference

| Symbol | Where it is documented |
| --- | --- |
| `BeakFormScreen`, `BeakWizardScreen`, `BeakScreenRole` | [Screens and form layouts](../reference/screens-and-layouts.md#screens) |
| `BeakFormLayout`, `BeakCard`, `BeakSection`, `BeakColumns`, `BeakTabs`, `BeakFormSections` | [Screens and form layouts](../reference/screens-and-layouts.md#layout-containers) |
| `BeakCalculated`, `BeakFormWidget`, `BeakFormReader`, `BeakDraftScope` | [Screens and form layouts](../reference/screens-and-layouts.md#draft-access) |
| `inputText`, `inputCombobox`, `tableForm` and every other builder | [Input builders](../reference/input-builders.md) |
| `BeakConfiguredForm`, `BeakFormSession` | `packages/beak_frontend/lib/src/form/beak_configured_form.dart`, `packages/beak_frontend/lib/src/form/beak_form_session.dart` |

## Continue reading

- [Inputs](inputs.md) choosing the right input for each field type.
- [Related records in forms](related-records.md) pickers, table editors and catalogs inside a form.
- [Multi-step forms](multi-step-forms.md) the same sections as validated steps.
- [Detail views](detail-views.md) the read role and the generated show page.
