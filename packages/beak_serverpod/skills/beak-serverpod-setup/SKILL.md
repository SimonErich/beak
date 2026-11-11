---
name: beak-serverpod-setup
description: Set up the Beak admin for a Serverpod 4 workspace, and add a model later. The server keeps its models, migrations, sessions and use cases; each exposed model is a definition class checked against Serverpod, and every write runs through Beak's admitted engine and the generated handlers.
---

# Beak admin on Serverpod

Beak's API runs inside the Serverpod server behind one gated endpoint, on
Serverpod's database, sessions and transactions. Each exposed model is one
definition class in a pure-Dart package; `beak generate` checks it against
Serverpod and writes the typed model under its `generated/models/` folder.

| Package | What it is | You edit |
| --- | --- | --- |
| `server` | `.spy.yaml` models, migrations, the Beak endpoint and use cases | yes |
| `server/.../generated` | handler base classes written by `beak generate` | never; extend them |
| `apps/<name>_admin` | Flutter panel: `beak.yaml`, `lib/l10n/models/`, `lib/l10n/app/`, `lib/` | yes |
| `apps/<name>_admin/definitions` | one definition class per model, behavior and rules | the classes, yes |

Never edit a `*.beak.dart` part, `definitions/lib/src/generated/`, the
generated handler folder, the Serverpod client or `*.g.dart`.

Read first: the workspace `AGENTS.md`, the installed Serverpod skills, and by
path `.dart_tool/beak/docs/serverpod/admin-app/index.md`, then its setup,
how-it-works, generate and write-bindings pages. Folder missing? Run
`beak docs` after the first `dart pub get`.

## Set up

1. In the panel's `beak.yaml`, point at the server and the definitions:

   ```yaml
   serverpod:
     server: ../../server
     models: [lib/src]
     migrations: migrations
   generate:
     definitions: definitions
     handlers: ../../server/lib/src/admin/generated
     prefix: Shop
     areas:
       catalog: {read: readCatalog, write: writeCatalog}
   ```

2. Create `definitions/` as a pure-Dart workspace package depending on
   `beak_core` and `beak_serverpod`. Its barrel exports
   `src/generated/models.dart`. The panel and the server depend on it.

3. Write one class per exposed model, named and typed as Serverpod declares
   it (`UuidValue` as `String`, JSON as `BeakJson`):

   ```dart
   import 'package:beak_core/beak_core.dart';
   import 'package:beak_serverpod/schema.dart';
   import 'package:shop_definitions/src/generated/definitions_support.dart';

   part 'package:shop_definitions/src/generated/models/catalog/product.beak.dart';

   /// A sellable product.
   @Resource()
   @ServerpodAdminModel.editable(area: 'catalog')
   final class Product extends BeakSchema {
     /// Unique stock keeping unit.
     @Display()
     late final String sku;
   }
   ```

   A field the class leaves out is never read or written. A read-only model
   names its `reason:`.

4. Generate: `beak generate --project apps/shop_admin`. `--check` is the CI
   gate. Fix every reported mismatch in the class, never in generated code.

5. Compose the engine in the endpoint:

   ```dart
   final engine = BeakServerpodEngine.admitted(
     models: shopModels,
     handlers: const ShopHandlers(),
     principal: resolveShopPrincipal,
     trees: [categoryTree],
   );
   ```

   The endpoint keeps its own permission gate and returns `engine.dispatch`.
   A model that runs custom code adds a required handler to `ShopHandlers`
   (the `beak-serverpod-bind-write` skill).

6. Boot the panel with `runServerpodBeakAdmin` (see
   `docs/serverpod/admin-app/setup.md`), then run `beak doctor`.

## Every later model

Change the `.spy.yaml`, create and apply the Serverpod migration, write the
definition class (the `beak-serverpod-add-model` skill) and run
`beak generate`. A rule or command goes on the class as `static get
validationRules` or `static get behavior`.

## Examples

- `examples/serverpod/bookshop_admin` is the reference workspace.

## Example prompt

```text
Use the beak-serverpod-setup skill to set up the admin for our Serverpod workspace: a definitions package with classes for the catalog models, one product price rule on the Product class, and the gated endpoint.
```
