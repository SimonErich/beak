# Libraries

> Look up the eight libraries of package:beak, what each exports, what it may reach, which file imports it, and the guards that keep the split honest.

An app depends on one package, `beak`, and picks from eight libraries inside it. The library a file imports says what the file is (a model, a screen, a server, a test), and the split keeps Flutter out of the server and the server out of the browser.

## Import

`beak create` writes the dependency; nothing else has to be added, because `beak` carries `beak_core`, `beak_frontend`, `beak_backend`, `beak_test`, `worm` and the three obers_ui packages.

```yaml title="shop_admin/pubspec.yaml"
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak
  flutter:
    sdk: flutter
```

The ref is the release tag of the CLI that wrote the file (`beak create --beak-ref <ref>` pins another, `--beak-path <path>` points at a local checkout, see [CLI commands](cli-commands.md)). Then import the library a file needs:

```dart
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';
import 'package:beak/panel.dart';
import 'package:beak/server.dart';
import 'package:beak/migrations.dart';
import 'package:beak/testing.dart';
import 'package:beak/ui.dart';
import 'package:beak/charts.dart';
```

## Summary

| Import | Exports | Reaches | In the panel's import graph |
| --- | --- | --- | --- |
| `package:beak/beak.dart` | `beak_core` | nothing platform specific | allowed |
| `package:beak/schema.dart` | `beak_core/schema.dart`: annotations, `BeakSchema`, authoring types | nothing | allowed |
| `package:beak/panel.dart` | `beak_frontend` and `beak.dart` | Flutter, obers_ui | allowed |
| `package:beak/server.dart` | `beak.dart`, `beak_backend`, `beak_core/io.dart` | `dart:io`, Shelf, worm, worm_postgres, worm_sqlite | forbidden |
| `package:beak/migrations.dart` | `worm/worm.dart` and `server.dart` | as `server.dart` | forbidden |
| `package:beak/testing.dart` | `beak_test` | the `test` package | tests only |
| `package:beak/ui.dart` | `obers_ui`, `obers_ui_autoforms` | Flutter | allowed |
| `package:beak/charts.dart` | `obers_ui_charts` | Flutter | allowed |

The last column is the web-safety rule: the graph a browser build compiles contains no `dart:io`, `dart:ffi`, `dart:mirrors` and no server package. See [Rules and limits](#rules-and-limits) for what checks it.

### Which library for which file

The right column is a real file, so the import lines can be checked against it.

| File | Imports | Example |
| --- | --- | --- |
| Schema class | `beak.dart`, `schema.dart` | `examples/clean_beak_config/lib/resources/products/models/product.dart` |
| Generated part `*.beak.dart` | none, it is `part of` its schema class | `examples/quickstart/lib/resources/notes/models/note.beak.dart` |
| `lib/beak/registry.g.dart` | `beak.dart` | `examples/quickstart/lib/beak/registry.g.dart` |
| `lib/beak/app.g.dart` | `panel.dart` | `examples/quickstart/lib/beak/app.g.dart` |
| `lib/beak/panel.g.dart` | `panel.dart`, and `ui.dart` when a default resource names an icon | `examples/quickstart/lib/beak/panel.g.dart` |
| `lib/beak/server.g.dart` | `server.dart` | `examples/quickstart/lib/beak/server.g.dart` |
| Domain code shared by server and panel | `beak.dart` | `examples/clean_beak_config/lib/domain/shop_totals.dart` |
| `BeakResource` class | `panel.dart`, `ui.dart` for icons | `examples/clean_beak_config/lib/resources/products/product_resource.dart` |
| Custom screen, form screen | `panel.dart`, plus `ui.dart` when it draws its own widgets | `examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart` |
| Authored `lib/main.dart` | `panel.dart`, `ui.dart`, `package:flutter/widgets.dart` | `examples/clean_beak_config/lib/main.dart` |
| `lib/server.dart` | `server.dart` | `examples/clean_beak_config/lib/server.dart` |
| Graph preparer, policy, effects | `server.dart` | `examples/clean_beak_config/lib/domain/shop_graph_preparer.dart` |
| Migration | `migrations.dart` | `examples/clean_beak_config/lib/migrations/create_products_table.dart` |
| Seeder | `migrations.dart` | `examples/clean_beak_config/lib/seeders/shop_seeder.dart` |
| Widget or resource test | `panel.dart`, `testing.dart` | `examples/clean_beak_config/test/shop_resource_test.dart` |
| API test over the real host | `migrations.dart`, `dart:io` | `examples/clean_beak_config/test/support/shop_test_api.dart` |
| Chart widget inside a `BeakWidgetBlock` | `panel.dart`, `charts.dart` | none of the maintained examples; `packages/beak/lib/charts.dart` shows one |

A file the panel reaches must not import `server.dart` or `migrations.dart`. The compiler does not object, `beak doctor` does (see [Rules and limits](#rules-and-limits)).

### Who re-exports whom

Rows export the columns they name. Because `panel.dart` and `server.dart` both carry `beak.dart`, a file that imports either needs no second import for the shared types.

| Library | `beak_core` | `beak_frontend` | `beak_backend` | `worm` | `beak_test` | obers_ui | obers_ui_charts |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `beak.dart` | yes | no | no | no | no | no | no |
| `schema.dart` | schema library only | no | no | no | no | no | no |
| `panel.dart` | yes | yes | no | no | no | no | no |
| `server.dart` | yes, plus `beak_core/io.dart` | no | yes | no | no | no | no |
| `migrations.dart` | yes | no | yes | yes | no | no | no |
| `testing.dart` | no | no | no | no | yes | no | no |
| `ui.dart` | no | no | no | no | no | `obers_ui`, `obers_ui_autoforms` | no |
| `charts.dart` | no | no | no | no | no | no | yes |

`panel.dart` does not re-export obers_ui. A screen that names `OiCard` or `OiIcons` imports `ui.dart` as well.

## `package:beak/beak.dart`

```dart title="packages/beak/lib/beak.dart"
export 'package:beak_core/beak_core.dart';
```

The vocabulary both halves speak. It depends on neither Flutter nor `dart:io`, so the registry, the models and `bin/serve.dart` can all import it.

| Group | Notable names |
| --- | --- |
| Models | `BeakModel`, `BeakModelRegistry`, `BeakFieldRef`, `BeakPermissions`, `BeakAttributeDefinition`, `BeakVariantMatrix` |
| Columns | `BeakColumn` and its leaves (`BeakStringColumn`, `BeakTextColumn`, `BeakIntColumn`, `BeakDecimalColumn`, `BeakBoolColumn`, `BeakDateTimeColumn`, `BeakEnumColumn`, `BeakImageColumn`, `BeakFileColumn`, `BeakJsonColumn`, `BeakCustomColumn`), `BeakSemantic`, semantic values such as `BeakDecimal` and `BeakDate` |
| Relationships | `BeakRelationship`, `BeakBelongsTo`, `BeakHasOne`, `BeakHasMany`, `BeakBelongsToMany`, `BeakOnDelete` |
| Rules | `BeakRule` and its leaves (`BeakMin`, `BeakMax`, `BeakMinLength`, `BeakMaxLength`, `BeakEmail`, `BeakPattern`, `BeakRequiredIf`, ...), `BeakRecordRule`, `BeakExists`, `BeakFieldMatch` |
| Queries | `BeakQuerySpec`, `BeakFilter`, `BeakOperator`, `BeakSort`, `BeakSearch`, `BeakPagination`, `BeakPage`, `BeakRelationLoad`, `BeakAggregateSpec`, `BeakSummarySpec` |
| Records and values | `BeakRecord`, `BeakValue` and its subtypes |
| Data | `BeakDataSource`, `BeakSavePlan`, `BeakSaveResult`, `BeakCandidateGraph`, `BeakModelBehavior`, `BeakModelAction`, `BeakDuplicationSpec` |
| Transport | `BeakClient`, `BeakSession`, `BeakUploadClient` |
| Errors | `BeakException` and its subtypes, `BeakResult`, `BeakOk`, `BeakErr` |
| Storage | `BeakStorageConfig` (`BeakS3Config`, `BeakFtpConfig`, `BeakLocalDiskStorageConfig`, `BeakMemoryStorageConfig`), `BeakStorageDriver`, `BeakStorageRegistry`, `BeakMemoryStorageDriver`, file rules, image transforms |
| Version | `beakCoreVersion` |

The local-disk driver imports `dart:io` and is not in this barrel. It lives in `package:beak_core/io.dart`, which `server.dart` re-exports.

## `package:beak/schema.dart`

```dart title="packages/beak/lib/schema.dart"
export 'package:beak_core/schema.dart';
```

| Group | Names |
| --- | --- |
| Base class | `BeakSchema` |
| Annotations | `Resource`, `Column`, `Display`, `Image`, `FileField`, `Badges`, `EnumLabels`, `Custom`, `BelongsTo`, `HasOne`, `HasMany`, `BelongsToMany` |
| Authoring types | `BeakText`, `BeakRichText`, `BeakHexColor`, `BeakImageRef`, `BeakFileRef` |

The annotations have short names on purpose, and `Column` and `Image` are also Flutter widgets. Only a schema class imports this library, and a schema class imports no Flutter. A screen that needs both `schema.dart` and `package:flutter/widgets.dart` gets an ambiguous name. Each annotation is documented in [Annotations](annotations.md).

## `package:beak/panel.dart`

```dart title="packages/beak/lib/panel.dart"
export 'package:beak_frontend/beak_frontend.dart';

export 'beak.dart';
```

The Flutter half. It runs in the browser and everything it imports must too.

| Group | Notable names |
| --- | --- |
| Shell | `BeakPanel`, `BeakPanelConfig`, `BeakResource`, `BeakScreen`, `BeakNavigation`, `BeakNavigationSection`, `BeakNavigationItem`, `BeakAuthConfig`, `BeakMaintenanceConfig`, `BeakThemeController`, `BeakFormatting` |
| Resource screens | `BeakResourceScreen`, `BeakFormScreen`, `BeakWizardScreen`, `BeakTableScreen`, `BeakCustomResourceScreen` |
| Forms | `BeakFormLayout`, `BeakFormSections`, `BeakFormSession`, `BeakDraftScope`, `BeakImportView`, `BeakImportDefinition` |
| Lists | `BeakListDefinition`, `BeakQueryController`, `BeakQueryPreset`, `BeakSavedViews`, `BeakDataTable` |
| Actions | `BeakAction`, `BeakRecordAction`, `BeakBulkAction`, `BeakGlobalAction`, `BeakActionPresentation`, `BeakModelActionRunner` |
| Blocks | `BeakBlock` and every `Beak*Block`, `BeakBlockHost`, `BeakRecordScope` |
| Data | `HttpBeakDataSource`, `BeakResourceRepository`, `BeakUploadRepository` |
| Services | `beakDependencies(context)`, `beakLocator` |
| Version | `beakFrontendVersion` |

## `package:beak/server.dart`

```dart title="packages/beak/lib/server.dart"
export 'beak.dart';
export 'package:beak_backend/beak_backend.dart';
export 'package:beak_core/io.dart';
```

The Shelf half. It reaches `dart:io` and database drivers, so no file the panel imports may import it.

| Group | Notable names |
| --- | --- |
| Host | `BeakServeHost`, `BeakServerDefaults`, `BeakServer`, `BeakBackendConfig`, `BeakEnv`, `BeakStorageSettings`, `createDefaultStorageRegistry` |
| Policy | `BeakPolicies`, `BeakModelRules`, `BeakAccess`, `BeakPolicy`, `BeakAllowAllPolicy`, `BeakRowPolicy`, `BeakFieldPolicy`, `BeakActionPolicy`, `BeakPrincipal` |
| Auth | `BeakAuthSessions`, `BeakAuthGuard`, `TokenSessionStore`, `InMemoryTokenSessionStore` |
| Writes | `BeakGraphCommitService`, `BeakSavePlanPreparer`, `BeakSavePlanFinalizer`, `BeakOutbox`, `BeakOutboxSchedule`, `BeakFrameworkTables` |
| Data | `WormDataSource`, `BeakBlueprint`, `BeakBaselineMigration`, `adapterFromUrl`, `initializeBeakDatabase` |
| Storage | `BeakLocalDiskStorageDriver` (from `beak_core/io.dart`) |
| Shelf | `Handler`, `Middleware`, `Pipeline`, `Request`, `Response`, `Router` |
| Version | `beakBackendVersion` |

A `lib/server.dart` that adds middleware or routes names the Shelf types through this library, so the project never depends on `shelf` itself.

## `package:beak/migrations.dart`

```dart title="packages/beak/lib/migrations.dart"
export 'package:worm/worm.dart';

export 'server.dart';
```

A migration and a seeder are worm's own classes, so this is the one library that hands worm types to application code: `Migration`, `Schema`, `Seeder`, `OnDelete` and the rest of `package:worm/worm.dart`, next to `BeakBlueprint`, which derives a table from a model. It re-exports `server.dart` as well, so a file in `lib/migrations/` never needs a second import. The same reach applies: `dart:io` and a database driver.

## `package:beak/testing.dart`

```dart title="packages/beak/lib/testing.dart"
export 'package:beak_test/beak_test.dart';
```

| Name | What it is |
| --- | --- |
| `InMemoryBeakDataSource` | A complete `BeakDataSource` over maps that honours the query spec |
| `BeakRecordingDataSource` | Wraps a data source and records the calls it receives |
| `runBeakDataSourceContract` | The executable `BeakDataSource` contract, for a custom data source |
| `beakFakeRecord`, `BeakRecordFactory` | Typed record factories |
| `expectSchemaParity`, `beakSchemaParityProblems`, `expectNoOrphanTables` | Model versus migration assertions |

The library pulls in the `test` package, which is why it belongs in `test/` and never in `lib/`.

## `package:beak/ui.dart` and `package:beak/charts.dart`

```dart title="packages/beak/lib/ui.dart"
export 'package:obers_ui/obers_ui.dart';
export 'package:obers_ui_autoforms/obers_ui_autoforms.dart';
```

```dart title="packages/beak/lib/charts.dart"
export 'package:obers_ui_charts/obers_ui_charts.dart';
```

`ui.dart` holds the widget kit Beak draws with (`OiCard`, `OiColumn`, `OiTable`, `OiIcons`, `OiThemeData`, the autoform widgets). `charts.dart` holds the chart widgets for a chart that goes beyond what a `BeakChartBlock` draws from a query. They are two libraries because `obers_ui` and `obers_ui_charts` each declare an `OiAnnotationType`, and one re-export would make the name ambiguous at every import site. An app that composes its own screens gets both without adding three dependencies and keeping their versions in step: all three are pinned to one commit (see [Packages](packages.md#the-obers_ui-pin)).

## Libraries of other packages

These are the imports that do not go through `package:beak`. An app rarely needs the first four; the Serverpod ones are the imports of the two Serverpod paths.

| Import | Package | Needs | Exports |
| --- | --- | --- | --- |
| `package:beak_core/beak_core.dart` | `beak_core` | pure Dart | The contents of `beak.dart`. For a models-only package shared by a server and an admin. |
| `package:beak_core/schema.dart` | `beak_core` | pure Dart | The contents of `schema.dart`. |
| `package:beak_core/io.dart` | `beak_core` | `dart:io` | `BeakLocalDiskStorageDriver` |
| `package:beak_backend/beak_backend.dart` | `beak_backend` | Dart VM | The server half without the umbrella. |
| `package:beak_frontend/beak_frontend.dart` | `beak_frontend` | Flutter | The panel half without the umbrella. |
| `package:beak_test/beak_test.dart` | `beak_test` | the `test` package | The contents of `testing.dart`. |
| `package:beak_storage_s3/beak_storage_s3.dart` | `beak_storage_s3` | `http`, `crypto` | `S3StorageDriver`, `S3ObjectClient`, `HttpS3ObjectClient`, `S3ResponseException`, `registerS3Storage`, `beakStorageS3Version` |
| `package:beak_storage_ftp/beak_storage_ftp.dart` | `beak_storage_ftp` | plain sockets | `FtpStorageDriver`, `FtpTransport`, `SocketFtpTransport`, `FtpProtocolException`, `registerFtpStorage`, `beakStorageFtpVersion` |
| `package:beak_image/beak_image.dart` | `beak_image` | `package:image` | `ImageTransformRunner`, `beakImageVersion` |
| `package:beak_serverpod/beak_serverpod.dart` | `beak_serverpod` | pure Dart | `ServerpodResource`, `ServerpodModel`, `ServerpodField`, `ServerpodDataSource`, the codecs and exception mapper |
| `package:beak_serverpod/wire.dart` | `beak_serverpod` | pure Dart | `BeakWireRequest`, `BeakWireResponse`, `BeakTunnelHttpClient`, `BeakTunnelDispatch`, the tunnel fault types |
| `package:beak_serverpod_flutter/beak_serverpod_flutter.dart` | `beak_serverpod_flutter` | Flutter, `serverpod_client` | `ServerpodAuthAdapter`, `serverpodBeakDataSource`, `ServerpodAuthExceptionMapper`, and everything in `tunnel.dart` |
| `package:beak_serverpod_flutter/tunnel.dart` | `beak_serverpod_flutter` | `serverpod_client`, no Flutter | `wire.dart` plus `ServerpodBeakHttpClient`, for Dart VM tools and tests |
| `package:beak_serverpod_server/beak_serverpod_server.dart` | `beak_serverpod_server` | `serverpod` `>=4.0.3 <5.0.0`, Dart ^3.12.2 | `BeakServerpodEngine`, `BeakAdminGate`, `BeakServerpod`, `ServerpodSessionAdapter`, `beakServerpodFrameworkTables` |
| `package:beak_serverpod_generator/beak_serverpod_generator.dart` | `beak_serverpod_generator` | `analyzer` | `generateServerpodCompanions`; the `bin/generate.dart` executable wraps it |
| `package:beak_cli/beak_cli.dart` | `beak_cli` | Dart VM | `createBeakRunner`, `BeakCliEnvironment`, `BeakPortProbe`, `BeakProcessRunner`; the `beak` executable is `bin/beak.dart` |

## Rules and limits

- **Model files stay pure.** A schema class and everything the registry imports may use `beak.dart` and `schema.dart` only. `bin/serve.dart` imports `server.g.dart`, which imports `registry.g.dart`, which imports your models. One import of `panel.dart` on that path stops `dart compile exe`.
- **`dart:io` compiles on the web and fails at run time.** dart2js and dartdevc ship a `dart:io` whose members throw, so a stray server import yields a green build and an `UnsupportedError` in the browser. Only an import-graph check catches it.
- **`melos run guard-web`** runs `tool/check_web_safe.dart`. It walks the import graph from twelve panel entrypoints: `packages/beak/lib/beak.dart`, `panel.dart`, `ui.dart`, `charts.dart` and `schema.dart`, `packages/beak_core/lib/beak_core.dart` and `schema.dart`, `packages/beak_frontend/lib/beak_frontend.dart`, and the four Serverpod panel libraries. The libraries that reach the server on purpose (`server.dart`, `migrations.dart`, `testing.dart`, `io.dart`) are listed separately, and a test fails on a public library that is in neither list. Beak's own packages (`beak` and every `beak_*`) are walked; other packages are checked by URI only. A hit prints the URI, the reason and the chain of files that reached it, and the exit code is 1.

  | Blocked | Why |
  | --- | --- |
  | `dart:io`, `dart:ffi`, `dart:mirrors` | Do not work in a browser |
  | `package:beak_backend`, `package:beak_image`, `package:beak_storage_*` | Server-side Beak packages |
  | `package:postgres`, `package:shelf`, `package:worm` (and `worm_*`) | Server-side third-party packages |

- **`beak doctor` runs the same rule on your project.** It follows the imports from the panel entrypoint (`lib/main.dart`, or `panel.entrypoint` in `beak.yaml`) and from `lib/beak/app.g.dart`, and fails on any file it reaches that imports `package:beak/server.dart` or `package:beak/migrations.dart`:

  ```console
  FAIL lib/resources/notes/note_resource.dart imports package:beak/server.dart, which cannot run on the web
       → move the server-side part to lib/server.dart, or import package:beak/beak.dart instead
  ```

- **`melos run guard-material`** runs `tool/check_no_material.dart`, which fails on any `package:flutter/material.dart` or `package:flutter/cupertino.dart` import under `packages/` and `examples/`. Beak's UI is obers_ui only. The guard reports the file and the URI, for example `Material-import guard passed (1150 Dart files scanned).` when clean.
- **`package:beak/testing.dart` is test code.** It depends on the `test` package. Import it from `test/` and from `lib/` of a test-support package, not from the app.
- **The umbrella is checked by a test.** `packages/beak/test/beak_libraries_test.dart` asserts what each library carries, and that `beak.dart` never mentions `beak_frontend`, `beak_backend`, `obers_ui` or `worm`.

## Source

- `packages/beak/lib/` holds the eight libraries; each file is a `library;` directive and its exports.
- `packages/beak/test/beak_libraries_test.dart` is the contract test of the split.
- `packages/beak_core/lib/beak_core.dart`, `schema.dart` and `io.dart` are the three core libraries.
- `packages/beak_frontend/lib/beak_frontend.dart` and `packages/beak_backend/lib/beak_backend.dart` are the two halves behind `panel.dart` and `server.dart`.
- `tool/check_web_safe.dart` and `tool/check_no_material.dart` are the guards.
- `packages/beak_cli/lib/src/commands/doctor_command.dart` holds the project-level web check (`serverImportChecks`).

## Continue reading

- [Packages](packages.md) the packages behind these libraries, their versions and dependencies.
- [Project structure](../start-here/project-structure.md) where each kind of file lives in a project.
- [The package graph](../architecture/package-graph.md) why the edges between packages are shaped this way.
- [Annotations](annotations.md) what a schema class can say once it imports `schema.dart`.
