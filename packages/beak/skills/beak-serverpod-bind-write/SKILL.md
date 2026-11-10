---
name: beak-serverpod-bind-write
description: Route a generated Serverpod admin model's writes through the project's existing use cases, refuse stock persistence where a use case owns every change, and add tree rules for category or navigation hierarchies.
---

# Bind admin writes to use cases

Use this after `beak generate` produced the model package and you need to
control how a model's writes reach the database. The generated model names its
write binding in `admission.write`; the server decides what that binding does.

Do not invent a second write path. Every change the panel offers must end in one
of your existing use cases or in ordinary persistence you deliberately allow.

## 1. Read the admission

Open the generated model for the resource and find:

- `capabilities` — the operations the panel may offer,
- `permissions` — the roles each operation needs,
- `admission.writable` — the columns a client may send,
- `admission.write` — the binding value, or `null` for a read-only model,
- `admission.restoreKey` — the key a soft-deleted row is restored by.

If the binding is wrong, fix the inventory in `definitions/resources/` and run
`beak generate`; do not hand-edit the generated package.

## 2. Pick one handler per binding

```dart
final writes = BeakWriteBindings<ShopWrite>(
  (binding) => switch (binding) {
    ShopWrite.configuration => const BeakWriteHandler.stock(),
    ShopWrite.menu => const BeakWriteHandler.derive(stampPublication),
    ShopWrite.order => BeakWriteHandler.commands(
      actions: {OrderActions.cancel: cancelOrder},
      otherwise: BeakUnmatched.refuse,
    ),
  },
);
```

- `stock()` for plain configuration records.
- `derive(stamp)` for a server-owned stamp such as published-at or published-by.
- `commands(...)` when a use case owns the operation. Bind commands in
  `actions`; bind `create`, `update` or `delete` directly when the use case owns
  the whole operation. Use `otherwise: BeakUnmatched.refuse` so no plain edit
  can bypass the use cases.

A write returns the persisted identity, not a copied record:

```dart
Future<Object?> cancelOrder(BeakSaveOperationContext context) async {
  context.requireCommandOnly();
  await CancelOrderUseCase()(session, orderId: context.id);
  return context.id;
}
```

`context.requiredCommandOnly()` refuses a client that attached other field
changes to a command. `context.merged` is the stored row with the validated
input over it.

## 3. Validate and compose

Call `writes.validate(registry)` in `main`. Then build the engine:

```dart
final engine = BeakServerpodEngine.admitted(
  models: shopModels,
  definitions: shopDefinitions,
  principal: resolvePrincipal,
  writes: writes,
  trees: [categoryTree],
  mapException: mapHostException,
);
```

`mapException` maps a use-case exception to `BeakException.forCategory(...)`
so the caller gets a typed status instead of an internal error.

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

- Startup validation: a writable model with no binding fails.
- A command with extra field values is refused.
- A blocked delete is a conflict; a cycle is a validation error on the parent.
- The use case ran once and the row the panel reads back is the one it wrote.

Run `beak generate --check` before committing, so the generated package matches
the inventory.

## Example prompt

> Bind the writes of the `Order` admin model to the existing order use cases:
> cancelling uses `CancelOrderUseCase`, every other change is refused, and a
> cancelled order cannot be edited. Add a `BeakWriteBindings<QateryAdminWrite>`
> entry, validate it at startup, and write tests proving a command with extra
> field changes is refused and that the panel reads back the persisted row.
