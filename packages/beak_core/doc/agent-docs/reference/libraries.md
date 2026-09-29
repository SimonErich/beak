# Libraries

> Look up the libraries of package:beak, what each is for and what it may import.

Beak is one dependency:

```yaml
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      path: packages/beak
```

which is what `beak create` writes until Beak is on pub.dev. Eight libraries
come with it. Which one you import says what a file is: a model, a
screen, a server, a test.

| Import | What it holds | Reaches |
| --- | --- | --- |
| `package:beak/beak.dart` | columns, models, relationships, the query spec, `BeakClient`, storage abstractions | nothing platform-specific |
| `package:beak/schema.dart` | the annotations a schema class carries | nothing |
| `package:beak/panel.dart` | the panel: `BeakPanel`, resources, blocks, tables, forms | Flutter |
| `package:beak/server.dart` | the Shelf host, config, storage wiring, auth, policy | `dart:io`, a database driver |
| `package:beak/migrations.dart` | worm's `Migration`, `Schema`, `Seeder`, and `BeakBlueprint` | `dart:io` |
| `package:beak/testing.dart` | `InMemoryBeakDataSource`, `BeakRecordingDataSource`, fixtures | nothing |
| `package:beak/ui.dart` | obers_ui, for a screen that draws its own widgets | Flutter |
| `package:beak/charts.dart` | obers_ui_charts | Flutter |

`panel.dart`, `server.dart` and `migrations.dart` re-export `beak.dart`, so a
file rarely needs two imports. A model file needs `beak.dart` and
`schema.dart`; the part file Beak generates beside it needs nothing.

## Why the split is not tidiness

`bin/serve.dart` imports `server.g.dart`, which imports `registry.g.dart`,
which imports your models. If anything on that path pulled in Flutter, the
server would stop compiling ahead of time: `dart compile exe` cannot build
against `dart:ui`.

That is why `beak.dart` holds no widgets, and why a model file must not import
`panel.dart`. The rule is checked, not trusted: `melos run guard-web` walks the
import graph from every panel and server entrypoint and fails the build if a
`dart:io` or `dart:ui` import appears where it must not.

The practical version is short:

- A file under `lib/models/` imports `beak.dart` and `schema.dart`. Nothing else.
- A file under `lib/screens/` or `lib/resources/` imports `panel.dart`, and
  `ui.dart` when it draws its own widgets.
- `lib/server.dart` imports `server.dart`.
- A migration or seeder imports `migrations.dart`.
- A test imports `testing.dart`, plus whichever of the above it exercises.

## Continue reading

- [Project structure](../start-here/project-structure.md) which file goes where.
- [Packages](packages.md) the packages behind these libraries, for contributors.
- [Annotations](annotations.md) what a schema class can say.
