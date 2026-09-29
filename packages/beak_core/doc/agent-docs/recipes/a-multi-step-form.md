# A multi-step form

> Declare a form as named sections once, project them into a validated wizard for create and edit, and reuse the same sections as tabs on the show page.

You want an order form that walks people through four steps, blocks Continue while a step is invalid, and lets them resume tomorrow. You also want the finished order to read as tabs on its show page without writing the fields twice.

## Recipe

Describe the form as `BeakSection`s inside one `BeakFormSections`. A section is a title, a description and the same form nodes you would put in any layout. The shop's order has four; this is how they open, with the inputs left out:

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
BeakFormSections orderSections() => BeakFormSections(
  sections: [
    BeakSection(
      title: 'Select a customer',
      description: 'Identify the order and its customer.',
      children: [
// ...
    BeakSection(
      title: 'Profile and delivery',
      description: 'Choose an address belonging to the selected customer.',
      children: [
// ...
    BeakSection(
      title: 'Order items',
      description: 'Add catalog items, variants or custom services.',
      children: [
// ...
```

`BeakFormSections` knows three projections. Nothing else about a section changes between them:

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
final class BeakFormSections {
  /// Creates a reusable presentation from ordinary typed layout nodes.
  const BeakFormSections({required this.sections});

  /// Ordered, titled sections shared by every projection.
  final List<BeakSection> sections;

  /// A stacked form suitable for compact screens and review views.
  BeakFormLayout get form => BeakFormLayout(children: sections);

  /// A tabbed presentation over the same field declarations.
  BeakTabs get tabs => BeakTabs(
    tabs: [
      for (final section in sections)
        BeakTab(
          title: section.title,
          visibleIf: section.visibleIf,
          enabledIf: section.enabledIf,
          children: [
            BeakSection(
              title: section.title,
              description: section.description,
              titleStyle: section.titleStyle,
              titleColor: section.titleColor,
              descriptionStyle: section.descriptionStyle,
              trailing: section.trailing,
              headingGapInPixels: section.headingGapInPixels,
              gapInPixels: section.gapInPixels,
              divider: section.divider,
              dividerAfterSpacingInPixels: section.dividerAfterSpacingInPixels,
              children: section.children,
            ),
          ],
        ),
    ],
  );

  /// Wizard steps sharing the same fields, rules, and editability conditions.
  List<BeakWizardStep> get steps => [
    for (final section in sections)
      BeakWizardStep(
        title: section.title,
        description: section.description,
        visibleIf: section.visibleIf,
        enabledIf: section.enabledIf,
        children: section.children,
      ),
  ];
}
```

Turn the sections into a wizard screen. The screen needs the steps, an optional draft store, and whether to show a review before sending:

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

Register it in the resource's `screens:`, and give the read role its own screen built from the tabs of the same sections:

```dart title="examples/clean_beak_config/lib/resources/orders/order_resource.dart"
OrderFormWizardScreen(),
BeakFormScreen(
  roles: const {BeakScreenRole.read},
  layout: BeakFormLayout(children: [orderSections().tabs]),
),
```

That is all. Create and edit now open the wizard, and the show page shows tabs.

## How it works

- A `BeakWizardScreen` serves `create` and `edit` unless you give `roles`. The same wizard edits an existing order, with its lines and picks loaded.
- Continue validates the current step and every step before it. Errors in later steps stay hidden until you reach them. Back never validates, and the values, staged rows and errors are kept.
- The first Continue of the shop's order is blocked until a customer is chosen, because `OrderModel.customer` is non-nullable and so required. Nothing in the section says so. The rule comes from the schema, and the server runs it again when the wizard saves.
- Finish validates all steps, saves the whole draft as one graph commit, and opens the first step with an error if one fails. Nothing is saved between steps.
- `reviewBeforeSave: true` shows the `Review changes` dialog first, and `drafts:` stores the unsaved form so leaving and coming back resumes it. The shop keeps drafts in memory on desktop and in the browser on the web:

```dart title="examples/clean_beak_config/lib/shop_drafts.dart"
import 'package:beak/panel.dart';
import 'package:flutter/foundation.dart';

final BeakDraftStore _shopDraftStore = kIsWeb
    ? const BeakBrowserDraftStore()
    : BeakMemoryDraftStore();

/// Resumable drafts for this single-user, local demonstration panel.
///
/// An authenticated host supplies its stable user and tenant identity here.
BeakFormDrafts shopDrafts(String form) => BeakFormDrafts(
  store: _shopDraftStore,
  key: form,
  context: 'clean-shop:local-demo',
  schemaVersion: 2,
);
```

- `context` must name the signed-in user and tenant (the shop is single-user, so it uses a fixed demo string). `schemaVersion` is the migration boundary: bump it when the layout changes, so an old draft is not restored into fields that moved. Drafts older than `retention`, seven days by default, are discarded.

## Variations

| You want | Do this |
| --- | --- |
| A step rail with summaries instead of Previous and Next | `navigation: BeakWizardNavigation.rail`, see [Multi-step forms](../forms/multi-step-forms.md#compact-or-rail). |
| A summary of the answers as the last step | `BeakReviewSection`, whose Edit link calls `goToStep`. |
| The wizard on the whole screen, sending through a named command | `fullScreen: true` and `submitAction:`. Foodio's order wizard does. |
| Fields that appear only for some answers | `visibleIf` on the input or the card. On a whole section it hides the content but leaves an empty step in the navigation. |
| A plain stacked form from the same sections | `orderSections().form`. |
| One of the `BeakFormScreen` options the wizard lacks (`layout`, `recordHeader`, `editingLabel`) | Write `BeakFormScreen(steps: [...])` directly. `BeakWizardScreen` forwards 26 of its 29 parameters. |

A wizard has no generated page frame, so record actions such as a print button do not appear on it. If the model has commands, place them with `BeakFormActions` inside a step.

## Verify

The wizard's package tests check that a step with an empty required field blocks advancing, and that the next step opens once it is valid:

```console
$ cd packages/beak_frontend
$ flutter test test/src/form/beak_wizard_form_test.dart --plain-name 'blocks advancing'
00:00 +1: All tests passed!
$ flutter test test/src/form/beak_wizard_form_test.dart --plain-name 'advances to the next step'
00:00 +1: All tests passed!
```

The shop's test drives its real order sections through `validateStep`, then saves through an in-process API:

```dart title="examples/clean_beak_config/test/order_form_test.dart"
test(
  'the actual configured wizard binds, calculates and saves its draft',
  () async {
    final registry = buildBeakRegistry();
    final api = await ShopTestApi.start();
    addTearDown(api.dispose);
    final source = HttpBeakDataSource(api.client);
    final customer = (await source.getOne(
      const UserModel().table,
      ShopSeedIds.ada,
    ))!;
    final profile = (await source.getOne(
      const UserProfileConnectionModel().table,
      ShopSeedIds.adaProfile,
    ))!;
    final product = (await source.getOne(
      const ProductModel().table,
      ShopSeedIds.beans,
    ))!;
    final before = (await source.query(const OrderModel().query())).total;
    final session = BeakFormSession(
      model: const OrderModel(),
      dataSource: source,
      registry: registry,
      steps: orderSteps(),
    );
    addTearDown(session.dispose);
    expect(await session.validateStep(0), isFalse);
    session.root.set(OrderModel.reference, 'SHOP-001');
    session.root.select(OrderModel.customer, customer);
    expect(await session.validateStep(0), isTrue);
    session.root.select(OrderModel.profile, profile);
    session.root.set(OrderModel.deliveryDate, DateTime.utc(2200));
    final row = session.root.addRow(OrderModel.items);
    row.set(OrderItemModel.quantity, 2);
    row.select(OrderItemModel.product, product);
    expect(lineTotal(BeakFormReader(row)), eur('25.00'));
    final checkpoint = row.checkpoint();
    row.set(OrderItemModel.discount, eur('5'));
    expect(lineTotal(BeakFormReader(row)), eur('20.00'));
    row.restore(checkpoint);
    expect(lineTotal(BeakFormReader(row)), eur('25.00'));
    expect((await source.query(const OrderModel().query())).total, before);
    final result = await session.save();
    expect(
      result?.complete,
      isTrue,
      reason:
          '${session.error.value}; root=${session.root.errors}; row=${row.errors}; result=${result?.toJson()}',
    );
    expect(
      (await source.query(const OrderModel().query())).total,
      before + 1,
    );
    expect(
      (await source.query(
        const OrderItemModel().query(
          filter: OrderItemModel.orderId.eq(result!.rootRecord!.asOrder.id),
        ),
      )).items.single.asOrderItem.quantity,
      2,
    );
  },
);
```

## Continue reading

- [A kanban view](a-kanban-view.md) shows the same records as cards on a board.
- [Multi-step forms](../forms/multi-step-forms.md) covers step options, the rail layout and review sections.
- [Drafts, review and conflicts](../forms/drafts-and-review.md) explains resuming and recovering an interrupted save.
