---
title: Transactional business rules
description: Write a preparePlan that validates and completes a whole record graph inside its transaction, and close the routes that could write around it.
type: guide
audience: [expert]
status: stable
---

# Transactional business rules

An invoice total needs its lines. A variant is unique within its product, and a delivery slot can only be booked while it has room. None of that fits on one field, and none of it can be trusted to a form. After this page you can write a server-side preparer that sees the whole proposed graph, rejects it or completes it, and know which routes to close so nothing writes around it.

Form saves are graph commits: one `POST /api/commits` carries every record of the form, the server runs the rules, and the answer is a receipt. The rules run in the same database transaction as the writes, so a rejected graph leaves nothing behind. [Graph commits](../architecture/graph-commits.md) explains the machinery. This page is the author's side of it.

## At a glance

| Tool | Where it lives | Use it for |
| --- | --- | --- |
| Model `behavior` and `validationRules` | On the model, shared with the panel | Derived values, `editableWhen`, named actions, uniqueness. Runs on both sides automatically, see [Model behavior](../models/behavior.md) |
| `preparePlan` | Your class, wired in `lib/server.dart` | Rules across records: totals, snapshots, reconciliation, guarded counters. Server only |
| `finalizePlan` | The same place | Queueing effects after validation, see [Durable effects](durable-effects.md) |
| `graphOnly` | The same place | Closing the per-record routes so nothing writes around the rules |

Reach for shared behavior first, because the panel previews it. Reach for a preparer when the rule needs records the form does not hold, or must not be overridable by a client that skips the form. The shop wires exactly one preparer and one list of tables:

```dart title="examples/clean_beak_config/lib/server.dart"
--8<-- "examples/clean_beak_config/lib/server.dart:shopServer"
```

## The contract

Both hooks are plain function types. A preparer returns the plan to execute, and a finalizer returns nothing:

```dart title="packages/beak_backend/lib/src/service/beak_graph_commit_service.dart"
--8<-- "packages/beak_backend/lib/src/service/beak_graph_commit_service.dart:BeakSavePlanHooks"
```

What the framework promises a preparer, and what it demands back:

- It runs after the client's operations passed the table-level policy check and field-write check, and after the built-in behavior pass. Application code never runs for a write the caller may not make.
- It receives a transaction-bound `WormDataSource`. Read through it, so calculation and persistence see the same snapshot.
- It must keep the save identity and root, and every original operation with its id, kind and target. It may add operations. Anything it adds still passes ownership, table policy and validation.
- It runs once per save. A replay of a completed save returns the stored receipt, and the preparer is not called again.

What it demands: break the identity rule and the request is a `500` with code `configuration` and the message `Graph preparation must retain each original operation identity and kind.` That is a programming error, and it is reported as one.

## Read the graph, not the database

`BeakCandidateGraph.open` loads the operations of the plan and overlays them on the stored records. Reads walk the graph as it will be after the save: drafts exist, removed rows are gone, changed values are the proposed ones. The shop's preparer, trimmed to its skeleton:

```dart title="examples/clean_beak_config/lib/domain/shop_graph_preparer.dart"
final class ShopGraphPreparer {
  /// Uses the same model registry as the generated server.
  const ShopGraphPreparer(this.registry);

  /// Metadata used to follow the submitted graph's owned relationships.
  final BeakModelRegistry registry;

  /// Validates the final graph and appends server-calculated invoice snapshots.
  Future<BeakSavePlan> prepare(
    BeakSavePlan plan,
    WormDataSource source,
    BeakPrincipal? principal,
  ) async {
    try {
      final graph = await BeakCandidateGraph.open(
        plan: plan,
        source: source,
        registry: registry,
        authorizeRead: source.authorizeRead,
      );
      _validateOwnership(plan, graph);
      for (final node in graph.nodes.toList()) {
        if (node.deleted || !node.changed) continue;
        switch (node.model) {
          case OrderModel():
            final profile = await graph.linked(node, OrderModel.profile);
            // ...
      for (final ref in invoiceRefs) {
        await _invoice(graph, await graph.load(ref));
      }
      return graph.build();
    } on FormatException catch (error) {
      throw BeakValidationException(error.message);
    }
  }
```

The vocabulary, all typed, none of it takes a column name:

| On | Method | Answers |
| --- | --- | --- |
| Graph | `nodes` | Every loaded record, deletions included. Copy with `.toList()` before you write while iterating |
| Graph | `load(ref)` | One record by stored or draft identity, loaded once |
| Graph | `linked(node, field)` | The record a to-one field points at, drafts included |
| Graph | `children(node, field, includeDeleted:)` | The final collection: additions in, removals out |
| Graph | `owners(node)`, `parents(node)` | The owning record of an owned child, or every inverse parent |
| Graph | `materialize(node, fields:)` | A record with the relations named by the fields loaded and overlaid |
| Node | `read(field)`, `original(field)` | The proposed value, and the value before this transaction |
| Node | `reference(field)`, `originalReference(field)` | A belongs-to identity, proposed and stored |
| Node | `changed`, `deleted`, `hasChanged(field)` | What this save does to the record |
| Node | `materiallyChanged(except:)` | Whether anything but the listed derived fields changed |
| Graph | `write`, `writeAll`, `link`, `restore`, `patch` | Changes to the plan, see below |
| Graph | `build()` | The enriched plan to return |

`BeakCandidateGraph.open` refuses a graph over `maxNodes` (default 10,000) with `The proposed graph is too large.`, so a rule that walks a whole table fails loudly and not slowly.

## Write what only the server may decide

A write on the graph does not touch the database. It replaces an operation of the plan, or adds one named `beak-derived-<n>`, and the executor persists the result. The shop derives every amount of an invoice from its lines and vouchers, and the client cannot author those:

```dart title="examples/clean_beak_config/lib/domain/shop_graph_preparer.dart"
final totals = ShopTotals.calculate(lines: lineInputs, vouchers: vouchers);
for (var index = 0; index < retainedItems.length; index++) {
  final total = totals.lines[index];
  graph.writeAll(retainedItems[index], [
    InvoiceItemModel.net.to(total.net),
    InvoiceItemModel.tax.to(total.tax),
    InvoiceItemModel.total.to(total.total),
  ]);
}
```

`ShopTotals.calculate` is the same pure function the form uses for its live preview, so the number the user saw and the number the server stores cannot disagree. `field.to(value)` encodes the value the way the column stores it (exact money as a scaled integer), and `graph.restore(node, fields)` returns server-derived columns to their stored values, which is how the shop keeps a client from editing an issued invoice's totals.

`graph.link(node, OrderModel.budgetAccount, ledger.ref)` sets a belongs-to field to a record that may be a draft of the same plan. The link keeps the draft's request-local identity, so a calculation can create a ledger and point an order at it in one atomic plan without inventing an id. Pass `null` to unlink. The node must be live, the field must belong to its model, and a draft target must have a create operation in the plan.

## Reject with a field

Throw a `BeakValidationException` and the whole graph is rolled back. The client gets a `200` receipt whose root operation is `unapplied`, with the message and `fieldErrors` it needs to mark the input. `field.invalid(message)` builds the exception from a typed field, so no rule spells a column key:

```dart title="examples/clean_beak_config/lib/domain/shop_graph_preparer.dart"
Never _invalid(BeakFieldRef<Object> field, String message) =>
    throw field.invalid(message);
```

A run against a scratch server whose preparer rejects a negative price shows what arrives:

```console
$ curl -s -X POST localhost:8392/api/commits -H 'content-type: application/json' -d "$PLAN"
{"saveId":"neg","mode":"atomic","outcomes":[{"id":"p","status":"unapplied","error":{"code":"validation","message":"A price cannot be negative.","fieldErrors":{"price":["A price cannot be negative."]}},"reason":"rejected"}]}
```

| A preparer throws | The caller sees | Stored |
| --- | --- | --- |
| A `BeakException` (validation, conflict, authorization) | `200` receipt, `unapplied`, `reason: rejected`, the exception's code and message | A rejected receipt, replayed for the same `saveId` |
| Anything else | `500` `internal`, `Internal server error.` | Nothing. A retry runs the preparer again, and the error goes to `onUnexpectedError` |

Throw the typed exception for anything a user can fix, and let a bug be a bug. Field errors ride on the first operation of the plan, which is what the form maps back to inputs.

## Reserve shared capacity

Some rules are about a resource many saves compete for: seats in a delivery slot, a company's monthly budget. A read followed by a write races with another save between the two. Foodio's preparer moves a counter with a compare-and-set inside the transaction, and refuses when the result would pass the limit:

```dart title="examples/foodio-adminpanel/lib/domain/foodio_order_preparer.dart"
--8<-- "examples/foodio-adminpanel/lib/domain/foodio_order_preparer.dart:foodioGuardedCounter"
```

The write goes through the transaction-bound `source`, not through the graph, so it lands immediately. It is still safe, because the transaction and the receipt are one unit: if any later step rejects the save, the counter moves back with everything else. A concurrent save that got there first makes `_compareAndSet` fail, and the caller gets a rejected receipt with the `conflict` code, telling it to reload.

## Close the direct routes

A rule in a preparer is worthless if `PATCH /api/orders/<id>` writes around it. `graphOnly` names the models whose create, update, delete, restore, attach and detach routes answer `422` and point at the commit endpoint. Reads, `validate`, `capabilities`, export and uploads stay open.

```console
$ curl -s -w ' [%{http_code}]\n' -X POST localhost:8392/api/products -H 'content-type: application/json' -d '{"name":"x","price":1}'
{"code":"validation","message":"This resource must be saved through a graph commit.","requestId":"19917d7ad55a473b"} [422]
```

The router also closes a table without being asked when its model declares `behavior`, when it is an owned child of a model with `editableWhen`, or when another model's shared rules load it. List every table your preparer reasons about, owned children included: the shop lists items, vouchers and attribute rows next to their parents, since a direct write to a child would bypass a rule on its parent.

`graphOnly` needs no `preparePlan`: list a table to close its direct routes and every save of it goes through `POST /api/commits`, where the usual authorization and validation still run. Two checks protect the rest of the wiring. `preparePlan`, `finalizePlan` and tables closed by behavior or shared rules need a `WormDataSource`, which the router checks at build time, and a transactional adapter, which a commit checks when it runs.

## Revision guards and replay

Graph updates and deletes carry `expectedUpdatedAt`, and the write is conditional on the exact stored timestamp, so two editors cannot overwrite each other. A conflict arrives as a receipt with `error.code == 'conflict'`. An unchanged update keeps its timestamp and still returns an applied receipt. [Graph commits](../architecture/graph-commits.md#conditional-writes) has the mechanics.

A confirmed replay returns the previous result without recalculating against a changed catalog, which is why an invoice that was priced last Tuesday is still that price today. Reusing a `saveId` with different content is a `409`:

```console
{"code":"conflict","message":"Save identity was reused with different content.","requestId":"0001ce89b7c98f82"} [409]
```

## Test the rules

Test a preparer without a server. `BeakGraphCommitService` takes the hook directly, so a test hands it a plan and reads the receipt. This one proves that a rejected preparation rolls back its own side effects:

```dart title="packages/beak_backend/test/src/service/beak_commit_preparer_test.dart"
--8<-- "packages/beak_backend/test/src/service/beak_commit_preparer_test.dart:preparerRollbackTest"
```

For the whole path, the shop's `ShopTestApi` starts the real host on `sqlite::memory:` and posts through `BeakClient`, see [Running the server](running-the-server.md#test-the-same-host). Its tests save a valid order graph and replay it, then save one with an invalid child and check that nothing of the graph was written:

```dart title="examples/clean_beak_config/test/shop_api_test.dart"
--8<-- "examples/clean_beak_config/test/shop_api_test.dart:graphSaveTests"
```

Assert three things per rule: the accepted graph gets the derived values, the rejected one leaves no rows, and a direct `POST` to a `graphOnly` table is a `422`.

## Rules and limits

| Rule | Consequence |
| --- | --- |
| Preparers, finalizers and tables closed by behavior or shared rules need a `WormDataSource` on a transactional adapter | A data source that is not worm makes the router refuse to build. An adapter without transactions makes every commit refuse with `Graph preparation requires a transactional data source.` A plain `graphOnly` list has no such need |
| A preparer must keep the save identity, the root and each original operation | Otherwise `500` `configuration`. It may add operations freely |
| A preparer's reads apply no row scope | The transaction-bound source is unscoped, so a rule can count rows the caller cannot see. Pass `authorizeRead: transaction.authorizeRead` to `BeakCandidateGraph.open` and the records the plan names are checked against the caller's `canView` and row scope |
| Field-write checks cover client-sent operations only | Operations a preparer adds skip that check, and keep every other one |
| An untyped exception is a `500` and stores no receipt | Throw `BeakValidationException` for user errors. Retries run the preparer again |
| A plan that decodes but is invalid (unknown field, cycle, duplicate id) is a `422` | `Invalid save plan: ...` names the problem, before any hook runs. The panel always sends valid plans |
| Plan size is bounded | `saveId` up to 200 characters, 1000 operations, 10,000 graph nodes |
| A graph commit needs `BeakCommitReceiptsMigration` applied | Every generated host lists it. Run `beak migrate` before the first save |
| Nothing prunes receipts | Old idempotency keys never become new writes, and the table grows |

## Verify it

Three requests prove a rule is really enforced, and none of them uses the panel:

```console
$ curl -s -w ' [%{http_code}]\n' -X POST localhost:8392/api/products ...        # direct write
$ curl -s -X POST localhost:8392/api/commits ... -d "$BAD_PLAN"                 # rejected graph
$ curl -s -X POST localhost:8392/api/products/query ... -d '{"table":"products"}'  # no partial rows
```

The first must answer `422`, the second a `200` receipt with `unapplied` and your field error, the third must not contain the rejected record. Replay the accepted plan with the same `saveId` and expect the same receipt, then change one value and expect `409`.

## Reference

- `packages/beak_backend/lib/src/service/beak_graph_commit_service.dart`: `BeakGraphCommitService`, `BeakSavePlanPreparer`, `BeakSavePlanFinalizer`.
- `packages/beak_core/lib/src/data/beak_candidate_graph.dart`: `BeakCandidateGraph`, `BeakCandidateNode`.
- `packages/beak_backend/lib/src/endpoints/beak_resource_router.dart`: which tables `beakApiRouter` closes.
- `examples/clean_beak_config/lib/domain/shop_graph_preparer.dart` and `examples/foodio-adminpanel/lib/domain/foodio_order_preparer.dart`: two preparers in full.

## Continue reading

- [Durable effects](durable-effects.md) what happens after the rules pass and the mail has to go out.
- [Auth and policies](auth-and-policies.md) the checks that run before your preparer does.
- [Model behavior](../models/behavior.md) the shared half of the rules, previewed in the form.
- [Graph commits](../architecture/graph-commits.md) receipts, staged mode and conditional writes in depth.
