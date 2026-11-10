---
name: beak-serverpod-setup
description: Set up the Beak admin for a Serverpod 4 workspace, and add a model later. The server keeps its models, migrations, sessions and use cases; the panel's schema package is generated from the inventory, and every write runs through Beak's admitted engine.
---

# Beak admin on Serverpod

Beak's API runs inside the Serverpod server behind one gated endpoint, on
Serverpod's database, sessions and transactions. The panel's schema package is
generated: you review an inventory, not a schema class.

| Package | What it is | You edit |
| --- | --- | --- |
| `server` | `.spy.yaml` models, migrations, the Beak endpoint and use cases | yes |
| `apps/<name>_admin` | Flutter panel: `beak.yaml`, `definitions/`, `lib/` | yes |
| `apps/<name>_admin/generated` | pure Dart, written by `beak generate` | never |
| `apps/<name>_admin/definitions` | inventory + authored behavior/rules | yes |

Never edit `generated/lib/`, the Serverpod client, `*.beak.dart` or `*.g.dart`.

Read first: the workspace `AGENTS.md`, the installed Serverpod skills, and by
path `.dart_tool/beak/docs/serverpod/admin-app/index.md`, then its setup, how-it-works, generate and write-bindings pages.
Folder missing? Run `beak docs` after the first `dart pub get`.

## Set up

1. In the panel's `beak.yaml`, point at the server and say what to generate:

   ```yaml
   serverpod:
     server: ../../server
     models: [lib/src]
     migrations: migrations
   generate:
     output: generated
     inventory: definitions/resources
     prefix: Shop
     areas:
       catalog: {read: readCatalog, write: writeCatalog}
     writes: [configuration, catalog, menu]
   ```

2. Review the inventory under `definitions/resources/`. Every model the panel
   exposes needs an entry with `operations`, and a write needs `write:` and
   `writeFields:`. A read-only model needs `reason:`.

3. Generate: `beak generate --project apps/shop_admin`. It reads the models,
   the newest migration and the inventory. `--check` is the CI gate.

4. Bind authored behavior in `definitions/lib/src/definitions.dart`:

   ```dart
   final shopDefinitions = BeakDefinitions([
     BeakModelDefinition(const ProductModel(), rules: [ProductPriceRule()]),
   ]);
   ```

5. Compose the server engine in the endpoint:

   ```dart
   final engine = BeakServerpodEngine.admitted(
     models: shopModels,
     definitions: shopDefinitions,
     principal: resolveShopPrincipal,
     writes: shopWrites,
     trees: [categoryTree],
   );
   ```

   The endpoint keeps its own permission gate and returns `engine.dispatch`.

6. Boot the panel with `runServerpodBeakAdmin` (see
   `docs/serverpod/admin-app/setup.md`), then run `beak doctor`.

## Every later model

Change the `.spy.yaml`, create and apply the Serverpod migration, add the
inventory entry, and run `beak generate`. If the model has a business rule or a
command, add it to the definitions package; if it writes through a use case,
use the `beak-serverpod-bind-write` skill.

## Examples

- `examples/serverpod/bookshop_admin` is the reference workspace.

## Example prompt

```text
Use the beak-serverpod-setup skill to set up the admin for our Serverpod workspace: a generated schema package for the catalog models, a generated definitions package with one product price rule, and the gated endpoint.
```
