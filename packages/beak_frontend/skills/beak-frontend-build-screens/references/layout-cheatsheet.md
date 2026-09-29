# Layout cheatsheet

Compiled and tested in a project created with `beak create` at Beak 0.9: an
`Order` that owns `OrderLine` rows (`@HasMany(owned: true, onDelete:
BeakOnDelete.cascade)` on `Order.lines`, `@BelongsTo(onDelete:
BeakOnDelete.cascade)` on `OrderLine.order`). The shop example in the Beak
repository (`examples/clean_beak_config/lib/resources/products/screens/product_form.dart`,
`.../orders/screens/order_form_wizard_screen.dart`, `lib/overview.dart`) shows
the same shapes at full size.

Import `package:beak/panel.dart` in layout files, plus `package:beak/ui.dart`
where an `OiIcons`, `Oi*` widget or `BeakIconToken` is used. The schema files
bring the `<Name>Model` classes.

## A form with tabs, cards and an owned-child table

```dart
BeakFormLayout orderForm() => BeakFormLayout(
  children: [
    BeakTabs(
      tabs: [
        BeakTab(
          title: 'Overview',
          children: [
            BeakColumns(
              children: [
                BeakCard(
                  title: 'Order',
                  children: [OrderModel.reference.inputText()],
                ),
                BeakCard(
                  title: 'Packing',
                  children: [OrderModel.note.inputText(maxLines: 4)],
                ),
              ],
            ),
            BeakFormWidget(
              showOnRead: false,
              builder: (context, draft) => OrderHint(draft: draft),
            ),
          ],
        ),
        BeakTab(
          title: 'Lines',
          children: [
            OrderModel.lines.tableForm(
              label: 'Order lines',
              removeBehavior: BeakRemoveBehavior.deleteOwned,
              children: [
                OrderLineModel.label.inputText(),
                OrderLineModel.quantity.inputNumber(),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
```

`tableForm` also takes `advancedForm:` (extra fields in a dialog per row),
`allowAdding`, `allowRemove`, `minRows`, `summary:` and `readOnly:`. Conditional
inputs: `inputText(visibleIf: (state) => state.asOrder.reference != null)`, where
`state.asOrder` is the generated typed view of the live draft.

## The same sections as a wizard

```dart
BeakFormSections orderSections() => BeakFormSections(
  sections: [
    BeakSection(
      title: 'Order',
      description: 'Who and what.',
      children: [OrderModel.reference.inputText(), OrderModel.note.inputText()],
    ),
    BeakSection(
      title: 'Lines',
      children: [
        OrderModel.lines.tableForm(
          removeBehavior: BeakRemoveBehavior.deleteOwned,
          children: [
            OrderLineModel.label.inputText(),
            OrderLineModel.quantity.inputNumber(),
          ],
        ),
      ],
    ),
  ],
);
```

`orderSections().steps` are the wizard steps, `.form` the stacked form.
Every step validates before Next, and the last one saves the whole graph.

## The resource

```dart
final class OrderResource extends BeakResource {
  OrderResource()
    : super(
        model: const OrderModel(),
        icon: const BeakIconToken(OiIcons.shoppingCart),
        filters: [OrderModel.reference.textFilter()],
        screens: [
          BeakTableScreen(fields: [OrderModel.reference, OrderModel.note]),
          BeakWizardScreen(
            steps: orderSections().steps,
            roles: const {BeakScreenRole.create},
          ),
          BeakFormScreen(
            layout: orderForm(),
            roles: const {BeakScreenRole.read, BeakScreenRole.edit},
          ),
        ],
      );
}
```

A role may be claimed by one screen only; two screens for `create` make that
route throw a `BeakConfigurationException`. A `BeakTableScreen` with no
`fields` keeps the generated columns.

## A custom widget in a form

```dart
class OrderHint extends HookWidget {
  const OrderHint({required this.draft, super.key});

  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    final scope = BeakDraftScope.of(context);
    final expanded = useState(false);
    final reference = draft.read(OrderModel.reference);
    return OiColumn(
      breakpoint: context.breakpoint,
      children: [
        OiLabel.small(
          scope.enabled
              ? 'Editing ${reference ?? 'a new order'}'
              : 'This order is read only',
        ),
        OiButton.ghost(
          label: expanded.value ? 'Hide help' : 'Show help',
          onTap: () => expanded.value = !expanded.value,
        ),
      ],
    );
  }
}
```

Imports: `package:beak/panel.dart`, `package:beak/ui.dart`,
`package:flutter/widgets.dart`, `package:flutter_hooks/flutter_hooks.dart`.
Read the shop's `variant_builder.dart` for a widget that writes back into the
draft. For custom cells and blocks see
`.dart_tool/beak/docs/extending/custom-blocks-and-widgets.md`.

## A dashboard page

`lib/screens/overview.dart` (a generated `lib/main.dart` finds it after
`beak prepare`; an authored panel lists it in `pages:`)

```dart
BeakScreen overview() => BeakScreen(
  path: '/overview',
  title: 'Overview',
  icon: const BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      BeakGridBlock(
        minColumnWidthInPixels: 220,
        children: [
          BeakMetricBlock(
            label: 'Orders',
            icon: OiIcons.shoppingCart,
            aggregate: const OrderModel().count(),
          ),
        ],
      ),
      BeakCardBlock(
        title: 'Latest orders',
        child: BeakTableBlock(
          model: const OrderModel(),
          fields: [OrderModel.reference],
        ),
      ),
    ],
  ),
);
```

## Tests

A form at a phone and a desktop width, tab switching, and the draft surviving it:

```dart
for (final width in [375.0, 1280.0]) {
  testWidgets('the order form keeps its draft across tabs at $width', (tester) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final registry = buildBeakRegistry();
    BeakFormSession? session;
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakConfiguredForm(
          model: const OrderModel(),
          registry: registry,
          dataSource: InMemoryBeakDataSource(registry: registry),
          mode: BeakFormMode.create,
          layout: orderForm(),
          onSession: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    session!.root.set(OrderModel.reference, 'SO-1');
    await tester.tap(find.text('Lines').first);
    await tester.pumpAndSettle();
    expect(find.text('Order lines'), findsOneWidget);
    expect(session!.root.read(OrderModel.reference), 'SO-1');
    expect(tester.takeException(), isNull);
  });
}
```

Imports: `package:beak/panel.dart`, `package:beak/testing.dart`,
`package:beak/ui.dart`, `package:flutter/widgets.dart`,
`package:flutter_test/flutter_test.dart`, the project's `beak/registry.g.dart`,
the schema and the layout file.

A whole panel over seeded data (authored panel; a generated one uses
`BeakApp(dataSource: source)` from `beak/app.g.dart`):

```dart
await tester.pumpWidget(
  BeakPanel(
    pages: [overview()],
    resources: [OrderResource()],
    dataSource: InMemoryBeakDataSource(registry: registry),
  ),
);
```

Wrap the source in `BeakRecordingDataSource(inner)` to assert how many round
trips a screen costs (`source.queryCalls`). Never assert on generated widget
internals; assert on text the user reads.
