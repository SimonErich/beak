---
title: Escape hatches
description: The four ways to take over from Beak when the generated default is wrong, from one resource to the whole panel.
---

# Escape hatches

Beak generates a great deal, and every piece of it can be replaced. After this
page you know which hatch fits which problem, and the rule they all follow:
**you receive Beak's default and return what you want**, so the file compiles
and changes nothing until your first edit.

They are listed narrowest first. Prefer the narrowest one that works — the
wider ones stop tracking changes you would otherwise get for free.

## 1. One resource: `lib/resources/<table>.dart`

Filters, actions, view modes, the detail layout, the form steps — anything on
`BeakResource`, for one resource, without touching any other.

```bash
beak eject resource products
```

```dart title="examples/store/lib/resources/orders.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  formSteps: const [
    BeakFormStep(
      title: 'Customer',
      subtitle: 'Who is buying',
      icon: OiIcons.user,
      // ...
      columns: [OrderColumns.customerId],
    ),
    // ... three more steps ...
  ],
);
```

`generated` is what Beak derived from the schema class and `beak.yaml`. Every
other resource stays generated, and this one keeps its generated icon, label
and section unless you change them. The file is named after the table; a name
matching no table is an error with a did-you-mean, not a file that silently
does nothing.

## 2. One part of the app: the convention files

| File | Replaces |
| --- | --- |
| `lib/theme.dart` | the light and dark themes |
| `lib/auth.dart` | which auth routes exist and what they call |
| `lib/dashboard.dart` | the screen mounted at `/` |
| `lib/server.dart` | middleware, policy, auth sessions, the storage registry |
| `lib/panel.dart` | the whole `BeakPanelConfig`, last word |

```bash
beak eject server
```

Each starter returns Beak's default:

```dart
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build();
```

`beak prepare` notices the file by its path and wires it in. Delete the file
and the default comes back.

## 3. A hand-written model

A schema class covers what a schema class can describe. When it cannot — a
primary key that is not `id`, a table whose columns are decided at runtime, a
model shared by a package that must not depend on the generator — write the
`BeakModel` yourself:

```dart
final class LegacyOrderModel extends BeakModel {
  const LegacyOrderModel();

  @override
  String get table => 'legacy_orders';

  @override
  String get displayColumnKey => 'reference';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'order_ref', label: 'Reference'),
    // ...
  ];

  @override
  BeakColumn get primaryKey => columns.first;
}
```

Put it under `lib/models/` like any other, with a zero-argument `const`
constructor so Beak can instantiate it. Discovery finds it, the registry
registers it, and the panel and the API treat it identically. It simply has no
part file, because there is no schema class to generate one from. You write its
migration yourself, or let `beak prepare` derive one from the model.

That missing part file is the cost: nothing writes the typed column constants or
the typed record view for you, so hoist the columns into `static const` fields
yourself if you want to pass them around. Reach for this hatch only when a schema
class cannot describe the table.

## 4. A table another system owns

Not a hatch out of Beak so much as one *into* an existing product:

```dart title="examples/embedded/lib/models/legacy_account.dart"
@Resource(table: 'accounts', managesSchema: false)
final class LegacyAccount extends BeakSchema {
  // ... ordinary columns ...
}
```

Beak reads the table, writes it, renders it and relates to it. It writes no
migration for it, and `beak doctor` does not ask why one is missing.

## And below all of it

Nothing here is a wrapper you cannot get under. `BeakServer.handler` is an
ordinary Shelf handler you can mount anywhere; `BeakBlockHost` is an ordinary
widget you can put in any app; `BeakDataSource` is an interface you can
implement against something that is not a database at all.
[`examples/embedded`](https://github.com/SimonErich/beak/tree/main/examples/embedded)
does the first two.

## Continue reading

- [Generated code](generated-code.md) what each hatch is replacing.
- [beak.yaml](../reference/beak-yaml.md) the presentation decisions that need no hatch.
- [CLI commands](../reference/cli-commands.md) `eject` in full.
