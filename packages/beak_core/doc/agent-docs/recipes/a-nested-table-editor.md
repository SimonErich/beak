# A nested table editor

> Edit the rows a record owns, such as order lines, as a table inside the parent form. Rows are staged and saved with the parent in one graph commit.

You want the lines of an order editable inside the order form: add a row, change a quantity, remove a row, see a total, and nothing reaches the server until Save.

## Recipe

Start on the schema. The parent declares the collection as owned, the child declares the way back:

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
/// Owned line items, committed with the order.
@HasMany(owned: true, onDelete: BeakOnDelete.cascade)
late final List<OrderItem> items;
```

```dart title="examples/clean_beak_config/lib/resources/orders/models/order_item.dart"
/// Owning order; wired automatically when the graph is saved.
@BelongsTo(onDelete: BeakOnDelete.cascade)
late final Order order;
```

`owned: true` says the order is the only reason these rows exist. That is what lets a form delete a row instead of only unlinking it. Run `beak prepare` and the generated `OrderModel.items` is a typed to-many field with a `tableForm` builder.

Place it in the form. Each entry of `children` becomes a column of the row:

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
OrderModel.items.tableForm(
  label: 'Products and services',
  minRows: 1,
  removeBehavior: BeakRemoveBehavior.deleteOwned,
  children: [
    OrderItemModel.product.inputCombobox(),
    OrderItemModel.variant.inputCombobox(),
    OrderItemModel.quantity.inputNumber(),
    const BeakCalculated(
      label: 'Net line total',
      value: lineTotal,
      format: BeakValueFormat.currency,
    ),
  ],
  advancedForm: BeakFormLayout(
    children: [
      BeakColumns(
        children: [
          BeakCard(
            title: 'Description',
            children: [
              OrderItemModel.label.inputText(label: 'Line description'),
              OrderItemModel.taxRate.inputCombobox(label: 'Tax rate'),
            ],
          ),
          BeakCard(
            title: 'Price adjustments',
            children: [
              OrderItemModel.overwritePrice.inputCurrency(
                label: 'Negotiated unit price',
              ),
              OrderItemModel.discount.inputCurrency(
                label: 'Line discount',
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  summary: (rows) => rows.fold<BeakDecimal>(
    ShopMoney.zero,
    (total, row) => total + lineTotal(row),
  ),
  summaryFormat: BeakValueFormat.currency,
  summaryLabel: 'Net items total',
),
```

The table shows a product picker, a variant picker, a quantity and a calculated line total in the row. The tax rate, the description and the two price overrides sit in `advancedForm`, which opens in a dialog from each row. The line total is an ordinary function of the row:

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
/// Net line calculation; invoice tax is calculated separately when invoicing.
BeakDecimal lineTotal(BeakFormReader state) {
  final item = state.asOrderItem;
  final unitPrice =
      item.overwritePrice ??
      item.variant?.price ??
      item.product?.price ??
      ShopMoney.zero;
  return unitPrice * (item.quantity ?? 0) - (item.discount ?? ShopMoney.zero);
}
```

## How it works

- Nothing is written while the form is open. Adding a row creates an unsaved draft, editing changes the draft, and removing a row that was never saved drops it. Cancel forgets all of it.
- Save turns the draft into one plan for `POST /api/commits`. Every new row becomes a `create` operation that depends on the parent's `create` and carries the parent's id in its foreign key (`order_id`), so the order and its lines are written in one transaction or not at all. Changed rows become `update`, removed saved rows become `delete`.
- `removeBehavior: BeakRemoveBehavior.deleteOwned` makes removing a saved row a `delete`. The default, `detach`, clears the child's foreign key instead, and that is refused when the column is required. `deleteOwned` on a relation that is not `@HasMany(owned: true)` throws a `BeakConfigurationException` as soon as the form is built, not when a row is removed.
- `minRows: 1` blocks Save with `Add at least 1 row.` This is client-side. The server half is the record rule `BeakCount(OrderModel.items, min: 1)` in the order's `validationRules`, which is why a hand-built request cannot skip the lines either.
- Each row is validated with the child's own rules (`BeakMin(1)` on the quantity, the `BeakExists` that ties a variant to its product) before the form saves. A row that fails keeps the whole form from saving.
- `summary` receives the current rows (removed ones excluded) as `BeakFormReader`s. `.asOrderItem` gives the typed view of a row, so the fold over `lineTotal` is checked by the compiler.
- A collection field has one editable table per form. To show the same lines twice, for example on a review step, repeat them as a second `tableForm(readOnly: true)`.

## Variations

| You want | Do this |
| --- | --- |
| Rows fixed in number | `allowAdding: false` and `allowRemove: false`. `allowEdit: false` locks the inputs of existing rows. |
| Read-only lines on a review step | `tableForm(readOnly: true, children: [...])` |
| Compact separated rows instead of cards | `presentation: BeakRelationTablePresentation.rows`, with `identityChildren` for the shared first cell. |
| The extra inputs inside the row | `advancedPresentation: BeakAdvancedPresentation.inline` instead of the dialog. |
| Rows picked from a big list | `catalog: BeakRelationCatalog(...)`, see [Related records in forms](../forms/related-records.md#a-catalog-for-big-option-lists). |
| The add button somewhere else | `showAddAction: false` on the table and a `BeakRelationAdd` where you want it. |
| A many-to-many | The same `tableForm`, and the row becomes an `attach` operation. `detach` removes the pivot row only. |

## Verify

The shop's test drives the real wizard against an in-process API: it adds a line, prices it, saves, and reads the order and its one item back.

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

```console
$ cd examples/clean_beak_config
$ flutter test test/order_form_test.dart --plain-name 'the actual configured wizard'
00:00 +1: All tests passed!
```

The `minRows` gate has a package test of its own, in a form with no shop around it:

```console
$ cd packages/beak_frontend
$ flutter test test/src/form/beak_form_session_test.dart --plain-name 'minimum collection rows'
00:00 +1: All tests passed!
```

## Continue reading

- [A multi-step form](a-multi-step-form.md) splits the same order form into steps and gates each one.
- [Related records in forms](../forms/related-records.md) covers pickers, inline create and the row catalog.
- [Graph commits](../architecture/graph-commits.md) explains the transaction the rows are saved in.
