---
title: Model behavior
description: Declare value lifecycles, shared guards and named business actions on the schema.
---

# Model behavior

A schema can expose a static `BeakModelBehavior get behavior`. The generator forwards it to the generated model. Configured forms preview this behavior; the graph endpoint evaluates it again using trusted stored data before persistence.

## Value lifecycles

| Declaration | Meaning |
| --- | --- |
| `BeakValueBehavior.initial` | Supply a value when creating a record. |
| `BeakValueBehavior.suggested` | Recalculate from dependencies until the user explicitly overrides the value. |
| `BeakValueBehavior.derived` | Recalculate a server-owned value; callers cannot assign it. |
| `BeakValueBehavior.snapshot` | Capture a value for its configured action and preserve it afterward. |

Each declaration names a typed field, a resolver and any dependencies. Dependencies determine evaluation order and related-record loading. The registry rejects cycles and foreign fields. Resolvers receive `BeakValueContext` with typed current, original and action-argument readers. Explicit overrides are draft state, so an unrelated change does not erase an administrator's chosen price.

The order-item model uses suggestions for the product label and price:

```dart title="examples/clean_beak_config/lib/resources/orders/models/order_item.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/models/order_item.dart"
```

## Record guards and actions

`editableWhen` and `deletableWhen` describe lifecycle constraints shared by every screen and API caller. They are distinct from account permissions. The backend checks the stored record, including ownership guards when a child is edited directly. An action-owned status cannot be bypassed by submitting a status field in an ordinary update.

`BeakModelAction` has a stable name, label, availability predicate, optional typed input model and value behaviors. Its `allowOnCreate` flag permits a new graph and the action to commit together. Configured forms and resource tables discover these actions automatically. See [Actions](../panel/actions.md) for the invoice example.

Keep resolvers deterministic and side-effect free. The server's transaction may fail or a request may be recovered. A model action is a validated state transition, not an email or payment execution hook. Adapters without authoritative behavior support reject behavior-bearing graph saves explicitly.

## Rules versus presentation

Shared scalar and record rules define valid data. Model behavior defines how data evolves. Input validators, visibility and enabled predicates shape a particular screen. For invariants every caller must obey, choose the model or a transactional graph preparer; a hidden control is not authorization.

## Continue reading

- [Actions](../panel/actions.md)
- [Transactional business rules](../backend/graph-business-rules.md)
