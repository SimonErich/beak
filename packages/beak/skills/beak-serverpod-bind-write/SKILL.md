---
name: beak-serverpod-bind-write
description: Route a Serverpod admin model's writes through the project's existing use cases by opening them as custom or derived on its definition class and implementing the generated handler, and add tree rules for category or navigation hierarchies.
---

# Run admin writes through use cases

Use this when a model's writes must reach the database through an existing use
case, a server stamp or a command, instead of plain persistence.

Do not invent a second write path. Every change the panel offers must end in
one of your existing use cases or in ordinary persistence you deliberately
allow.

## 1. Open the operation on the class

```dart
@Resource()
@ServerpodModel(
  area: 'sales',
  create: BeakHandling.custom,
  commands: [BeakCommand('cancelOrder')],
)
final class PlacedOrder extends BeakSchema {
  static BeakModelBehavior get behavior =>
      BeakModelBehavior(actions: [OrderActions.cancel]);
  // ...
}
```

- `stock`: plain persistence for configuration records.
- `derived`: plain persistence after `derive` adds trusted values, such as
  published-at or published-by.
- `custom`: the handler runs the operation through the use case.
- `commands:`: each name is a model action the behavior declares; it is saved
  as an update that changes no field. A plain update stays refused unless
  `update` is opened too. `BeakCommand('addRole', input: AccountRoleCommand)`
  gives the handler `AccountRoleCommandWrite` and `write.input.roleId`.
- `list: BeakHandling.custom`: the handler's `scope` narrows list, count,
  export and opening a record.
- An operation left `off` is refused on the server.

Run `beak generate`. It writes `placed_order_handler.dart` with an abstract
`PlacedOrderHandler` and adds a required `placedOrder:` to `<Prefix>Handlers`.

## 2. Implement the handler

```dart
final class PlacedOrderAdminHandler extends PlacedOrderHandler {
  const PlacedOrderAdminHandler();

  @override
  Future<Object?> create(PlacedOrderWrite write) async {
    final order = await PlaceOrderUseCase()(
      write.session,
      id: write.uuid,
      customerId: write.record.customerId,
      transaction: write.transaction,
    );
    return order.id;
  }

  @override
  Future<Object?> cancelOrder(PlacedOrderWrite write) async {
    final order = await CancelOrderUseCase()(
      write.session,
      orderId: write.uuid,
      transaction: write.transaction,
    );
    return order.id;
  }
}
```

- `write.record` is the record after the write, typed as Serverpod reads it
  (`UuidValue`, the protocol enum); `write.before` the stored one.
- Always pass `write.transaction`, so the use case joins Beak's commit.
- Return the persisted id; Beak reads the row back in the same transaction. A
  delete returns nothing, `derive` returns a `BeakRecord?`.
- `write.arguments` holds a command's `@CommandInput` values,
  `write.runs(action)` says which command runs, `write.principal` who saves.
- Beak checked permissions, admission and rules before the call; a handler
  decides how, never whether.

## 3. Compose the engine

```dart
final engine = BeakServerpodEngine.admitted(
  models: shopModels,
  handlers: const ShopHandlers(placedOrder: PlacedOrderAdminHandler()),
  principal: resolvePrincipal,
  trees: [categoryTree],
  mapException: mapHostException,
);
```

The engine refuses to start when a handler runs a command the behavior does
not declare. `mapException` maps a use-case exception to a `BeakException`.

## 4. Add tree rules when a model is hierarchical

```dart
final categoryTree = BeakTreeRule(
  parent: ProductCategoryModel.parent,
  children: ProductCategoryModel.children,
  sameAs: [ProductCategoryModel.slug],
  maxDepth: 3,
  referencedBy: [ProductModel.categoryId],
);
```

The rule rejects cycles, deleting a parent with children or references, sibling
values repeated in `sameAs`, and trees deeper than `maxDepth`. It locks the
tree's rows first; pass `lockRows: false` only for a small, cold tree.

## 5. Test the wiring

- The server compiles with every required handler and the engine starts.
- A command with extra field values is refused; a plain update of a
  commands-only model is refused.
- A blocked delete is a conflict; a cycle is a validation error on the parent.
- The use case ran once and the row the panel reads back is the one it wrote.

Run `beak generate --check` before committing.

## Example prompt

> Run the writes of the `PlacedOrder` admin model through the existing order use
> cases: cancelling uses `CancelOrderUseCase`, every other change is refused.
> Open `commands: [BeakCommand('cancelOrder')]` on its definition class, implement the
> generated handler, pass it to the handlers aggregate, and write tests proving
> a command with extra field changes is refused and that the panel reads back
> the persisted row.
