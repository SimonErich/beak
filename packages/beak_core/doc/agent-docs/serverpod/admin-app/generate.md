# Generating the schema package

> Turn the Serverpod models, the newest migration and a reviewed inventory into the admin's typed model package.

After this page you can add a model to the admin by reviewing one inventory
entry and running one command, and you know what the generator refuses.

## At a glance

| You want | Command or key |
| --- | --- |
| Generate the typed models | `beak generate --project apps/shop_admin` |
| Prove the output is current | `beak generate ... --check` |
| Say where the server is | `beak.yaml` `serverpod:` |
| Say what the panel may write | `beak.yaml` `generate:` + `definitions/resources/*.yaml` |

## The inputs

Three inputs decide the output, and none of them is the output itself:

1. The Serverpod models under the server's `lib/src/**/*.spy.yaml`.
2. The newest `migrations/*/definition_project.json`, which is the physical
   truth about columns, foreign keys (including Serverpod's shadow keys) and
   unique indexes.
3. The reviewed inventory in the output-adjacent `definitions/resources/`.

The generated package under `generate.output` is pure Dart. It imports only
`package:beak_core` and its own files, never an authored file, and no part
files are used.

## What it emits

```text
generated/
├── pubspec.yaml              # yours, tracked
└── lib/                      # the generator's, gitignored
    ├── shop_generated.dart   # models, createShopRegistry, enum ShopWrite
    └── src/
        ├── models.dart
        ├── enums.dart
        └── models/product.dart
```

Each model declares the columns and relationships, its `capabilities`,
`permissions` and `admission` from the inventory, and resolves its authored
behavior and rules through `BeakDefinitions`.

## Reviewing a model

The inventory entry decides exposure, writes and presentation:

```yaml
area: catalog
resources:
  Product:
    display: sku
    operations: [read, create, update, delete]
    write: catalog
    writeFields: [sku, productType, status, netPriceCents, categoryId]
    ownedRelations: [translations, variants]
```

A write needs `write:` and `writeFields:`; an empty list means every change
goes through a command. A read-only model needs a `reason:`. The generator
fails closed on a writable model with no binding, an unknown write or area, a
write field that is not a column, a column that is not in the migration, or a
relation whose two sides do not name each other.

## Syncing and checking

The command owns `lib/` under the output package. It rewrites changed files,
deletes generated files nothing produces any more, and refuses to touch a file
whose first line is not the generated header. `--check` writes nothing and
exits 1 on a stale, missing or orphaned file, which is what CI runs.

`beak prepare` runs `beak generate` first when the project configures
`generate:`, and `beak doctor` reports a stale generated package.

## Rules and limits

- The generated package may depend only on `beak_core`; add authored behavior
  in the definitions package, not in generated code.
- The newest migration is authoritative: a model column missing there fails the
  run, so migrate before generating.
- Enum values are emitted by wire name; a `serialized: byIndex` enum is refused.

## Verify it

- `beak generate --check` passes.
- `dart analyze` on the generated package and the definitions is clean.
- The model's list, detail and form routes open, and one write reaches its use
  case.

## Reference

- `beak generate` is described in [CLI commands](../../reference/cli-commands.md).
- The configuration keys are in [beak.yaml](../../reference/beak-yaml.md).
- Writes, commands and tree rules: [Writes, commands and trees](write-bindings.md).

## Continue reading

- [How the admin app works](how-it-works.md): where the generated models run.
- [Setting up the admin app](setup.md): the panel and the endpoint.
