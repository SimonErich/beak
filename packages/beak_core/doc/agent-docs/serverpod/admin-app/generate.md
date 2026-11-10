# Generating the admin from definition classes

> Declare each exposed Serverpod model as a class; beak generate checks it against Serverpod and writes the typed models and server handler bases.

After this page you can expose a Serverpod model in the admin by writing one
class and running one command, and you know what the generator checks and
refuses.

## At a glance

| You want | Command or key |
| --- | --- |
| Expose a model | `beak make:definition <Model>`, or write the class by hand |
| Scaffold the definition | `beak make:definition <Model> --project apps/shop_admin` |
| Generate the parts and handler bases | `beak generate --project apps/shop_admin` |
| Prove the output is current | `beak generate ... --check` |
| Say where the server is | `beak.yaml` `serverpod:` |
| Say where the classes and handlers live | `beak.yaml` `generate.definitions`, `generate.handlers` |

## The inputs

Four inputs decide the output, and none of them is the output itself:

1. The Serverpod models under the server's `lib/src/**/*.spy.yaml`. Serverpod
   stays the schema owner: tables, column keys, foreign keys, timestamps and
   soft delete come from here.
2. The newest `migrations/*/definition_project.json`, which is the physical
   truth about columns, foreign keys (including Serverpod's shadow keys) and
   unique indexes.
3. The definition classes in `generate.definitions`, one per exposed model.
4. The label files, when `beak.yaml` has `labels:`
   ([Labels in every language](../../panel/labels.md)).

## A definition class

`beak make:definition <Model>` writes the first draft: every stored field with
its Serverpod type and nullability, relations, read-only timestamps and
version, the copied docs and the `part` directive. The model is read-only
until you open an operation.

A definition class has the Serverpod model's name and declares the fields the
admin exposes, typed and named as Serverpod declares them. The field list is
the allowlist: a Serverpod field the class leaves out is never read or
written.

```dart title="examples/serverpod/bookshop_admin/definitions/lib/src/catalog/book.dart"
part 'book.beak.dart';

/// A title the shop stocks. Staff create and edit books; nobody deletes
/// one, so removing a book is a deliberate server change.
@Resource()
@ServerpodModel(
  area: 'catalog',
  create: BeakHandling.stock,
  update: BeakHandling.stock,
  commands: ['restock'],
)
final class Book extends BeakSchema {
  /// The commands staff can run on a book.
  static BeakModelBehavior get behavior =>
      BeakModelBehavior(actions: [BookActions.restock]);

  /// The title printed on the cover.
  @Display()
  late final String title;
// ...
  /// Who wrote it.
  @BelongsTo()
  late final Author? author;

  // supplierCostInCents is server only in Serverpod and not declared here,
  // so the admin never reads or writes it.
}
```

- Every operation is `BeakHandling.off` until the class opens it, so a new
  model is read only and names its `reason:`. `@ServerpodModel.editable()`
  opens stock create, update and delete.
- A `UuidValue` field is declared `String`, a Serverpod enum by its own name,
  a list or other JSON value as `BeakJson`; `?` matches Serverpod's.
- A relation is declared with `@BelongsTo`, `@HasOne` or `@HasMany` and the
  related definition class. Its foreign key comes with it. A foreign key
  declared without its relation (`late final String? publishedById;`) stays a
  plain key column, which is how a relation to a model the admin does not
  expose is kept.
- `@ReadOnly()` shows a field and never writes it; `@Hidden(defaultValue:)`
  keeps it on the server and gives a create its value; `@Column(...)` lays its
  arguments over the ones Beak derives.
- Keys, timestamps and soft-delete fields are always exposed and never
  written, declared or not.
- Behavior and rules are static getters on the class, as on a Beak-owned
  schema: `static BeakModelBehavior get behavior` and
  `static List<BeakRecordRule> get validationRules`.

Every annotation and parameter is in [Annotations](../../reference/annotations.md#serverpod-definition-classes).

## What it emits

```text
definitions/
├── pubspec.yaml
└── lib/
    ├── shop_definitions.dart     # yours: export 'src/generated/models.dart';
    └── src/
        ├── catalog/
        │   ├── book.dart         # yours, the definition class
        │   └── book.beak.dart    # generated part: BookModel, columns, fields
        └── generated/
            ├── models.dart       # every class, shopModels, createShopRegistry()
            ├── enums.dart        # Serverpod's enums, by wire name
            └── writes.dart       # enum ShopWrite, one value per writable model
server/lib/src/admin/generated/   # generate.handlers
├── order_handler.dart            # one per model that runs custom code
└── shop_handlers.dart            # ShopHandlers, the engine's handlers
```

A definition library imports `generated/enums.dart` when it declares an enum
field and `generated/writes.dart` when the model writes, and it has its
`part '<file>.beak.dart';`. The package barrel exports
`src/generated/models.dart`. The server handlers are described in
[Writes, commands and trees](write-bindings.md).

## What it checks

`beak generate` reads the classes without resolving them, checks them against
Serverpod and the migration, and reports every problem at once before it writes
anything:

- a declared field Serverpod does not have, or one it stores as server only;
- a field whose type or `?` differs from Serverpod's
  (`Product.sku is not nullable in Serverpod`);
- a relation of the wrong kind, or one pointing at a model no class exposes;
- a field that looks like a secret (a password hash, a token);
- a stock create that would leave a required Serverpod field without a value;
- a missing `part` directive or `generated/writes.dart` import, with the line
  to add;
- two definition classes in one library;
- an area not in `generate.areas`, a writable model with no area or roles, a
  read-only model without a `reason:`;
- custom code without `generate.handlers`.

## Syncing and checking

The command owns the `*.beak.dart` parts in the definitions package, its
`lib/src/generated/` and the handler folder. It rewrites changed files, deletes
generated files nothing produces any more, and refuses to touch a file in a
generated folder whose first line is not the generated header. `--check`
writes nothing and exits 1 on a stale, missing or orphaned file, which is what
CI runs.

`beak prepare` runs `beak generate` first when the project configures
`generate:`, and `beak doctor` reports stale generated code.

## Rules and limits

- Field and class names equal Serverpod's; there is no rename.
- The definitions package is pure Dart (`beak_core`, `beak_serverpod`), so the
  server imports the same classes as the panel.
- The newest migration is authoritative: a declared column missing there fails
  the run, so migrate before generating.
- Enum values are emitted by wire name; a `serialized: byIndex` enum is refused.
- A many-to-many relation is exposed through its Serverpod pivot class, with two
  `@BelongsTo` fields.

## Verify it

- `beak generate --check` passes.
- `dart analyze` on the definitions package and the server is clean.
- The model's list, detail and form routes open, and one write reaches its
  stock path or its handler.

## Reference

- `beak generate` is described in [CLI commands](../../reference/cli-commands.md).
- The configuration keys are in [beak.yaml](../../reference/beak-yaml.md).
- `packages/beak_cli/lib/src/serverpod/definition_reader.dart` and
  `definition_checks.dart` read and check the classes.

## Continue reading

- [Writes, commands and trees](write-bindings.md): custom operations and their handlers.
- [How the admin app works](how-it-works.md): where the generated models run.
- [Setting up the admin app](setup.md): the panel and the endpoint.
