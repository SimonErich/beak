# beak

The one dependency a Beak app adds. It brings the panel, the Shelf server, the
schema annotations, the migration DSL, the testing toolkit and obers_ui, so a
project never has to keep several Beak version constraints in step by hand.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter.

## Install

`beak create` writes this dependency for you. To add it by hand:

```yaml
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      path: packages/beak
```

## Libraries

Import only the library a file needs. The split keeps Flutter out of the server
and `dart:io` out of the panel.

| Library | What it is for |
| --- | --- |
| `package:beak/beak.dart` | The shared core (columns, models, relationships, the query spec, storage), free of Flutter and `dart:io`. |
| `package:beak/schema.dart` | The annotations a model file is written with: `@Resource`, `@Column`, `@BelongsTo`, `@HasMany` and the rest. |
| `package:beak/panel.dart` | The Flutter panel: shell, tables, forms, screens, actions and blocks; re-exports `beak.dart`. |
| `package:beak/server.dart` | The Shelf host with its configuration, storage wiring, auth and row policies; never import it from a panel file. |
| `package:beak/migrations.dart` | worm's migration and schema DSL plus `BeakBlueprint`, for migrations and seeders. |
| `package:beak/testing.dart` | The `beak_test` toolkit: in-memory data source, data-source contract, record factories and schema parity. |
| `package:beak/ui.dart` | The obers_ui and obers_ui_autoforms widgets, for screens you compose yourself. |
| `package:beak/charts.dart` | The obers_ui_charts widgets, kept apart from `ui.dart` because both declare `OiAnnotationType`. |

A model file imports `beak.dart` and `schema.dart`. `lib/main.dart`, resources
and screens import `panel.dart`. `server.dart` is imported by the generated
`lib/beak/server.g.dart` host that `bin/serve.dart` starts, and by
`lib/server.dart` when a project adds its own policies.
