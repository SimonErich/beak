---
title: Beak
description: Beak builds an admin panel, a REST API and migrations for Dart and Flutter from annotated schema classes and declarative resources you write once.
type: index
audience: [beginner, expert, agent]
status: stable
---

# Beak

Beak is the toolbox for the admin panel that almost every Dart or Flutter app grows sooner or later. You declare a model once, as an annotated Dart class, and `beak prepare` generates the typed field references, the migration, a Shelf REST API and a Flutter panel with the table, the form, the detail page, the filters and the CSV export. The panel is built on obers_ui with no Material, and nobody writes an endpoint, a string field reference or a `dynamic`.

Flutter's mascot is a bird, and a bird with a beak is good at picking through data. That is the whole joke, and the framework does not depend on it.

## One definition, three files

The smallest project has a schema class. Add a resource class to shape how the panel shows it, and a `main.dart` that lists the resources. These are real files: the schema is what `beak create` writes, the other two are from the shop example.

=== "Schema"

    ```dart title="examples/quickstart/lib/resources/notes/models/note.dart"
    --8<-- "examples/quickstart/lib/resources/notes/models/note.dart"
    ```

=== "Resource"

    ```dart title="examples/clean_beak_config/lib/resources/categories/category_resource.dart"
    --8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategoryResource"
    ```

=== "main.dart"

    ```dart title="examples/clean_beak_config/lib/main.dart"
    --8<-- "examples/clean_beak_config/lib/main.dart:shopMain"
    ```

The field's type picks the column, its nullability decides whether it is required, and `rules` add validation that runs in the form and again on the server. Change one line, run `beak prepare`, and the table, the form and the API follow. The migration for a changed column is one `beak make:migration --from-drift` away, and you read it before you apply it. Nothing is copied, so nothing drifts.

```bash
beak create acme_admin
cd acme_admin
beak migrate   # create the tables, in a SQLite file
beak dev       # serve the API and print the line that starts the panel
```

!!! warning "Pre-release"
    Beak `0.9.0` is not tagged yet, and the obers_ui commit it pins is older than the code. Until both are fixed, create projects with `--beak-path` and give the panel a `pubspec_overrides.yaml`. [Installation](start-here/installation.md) has the exact steps, and [Upgrading](start-here/upgrading.md) lists what changed from the previous line.

## Three doors

<div class="grid cards" markdown>

- **New to Beak**

    ---

    Read [What is Beak?](start-here/what-is-beak.md), install the command, then run the [Quickstart](start-here/quickstart.md) and grow it in the [Tutorial](tutorial/index.md), a shop built chapter by chapter.

- **You know your way around**

    ---

    Start at the [Cheatsheet](reference/cheatsheet.md) and the [Reference](reference/index.md), then [The four layers](concepts/the-four-layers.md) and [Architecture](architecture/index.md). Guide pages carry `Rules and limits` and `Verify it` for scanning.

- **A coding agent**

    ---

    Start at the [AI directory](ai/index.md). It has a task map, a source map and the rules. In a project, `beak agents` writes a managed block into `AGENTS.md` and `beak docs` copies the docs of the version the project resolved. The site also publishes `/llms.txt` and a Markdown twin of every page.

</div>

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Try Beak on a new project | [Installation](start-here/installation.md), then [Quickstart](start-here/quickstart.md) | The `beak` command, a running panel, a first migration |
| Learn Beak one chapter at a time | [Tutorial](tutorial/index.md) | A shop from empty folder to shipped |
| Decide whether Beak fits | [What is Beak?](start-here/what-is-beak.md), [Why Beak?](start-here/why-beak.md) and [Examples](examples/index.md) | What you write, what Beak writes, when to skip it |
| See where every file lives | [Project structure](start-here/project-structure.md), [Two ways to boot a panel](start-here/generated-or-authored.md) | The layout, and generated versus authored entrypoints |
| Start from something that already exists | [Choose your path](start-here/paths/index.md) | A database, a Flutter app, a Serverpod project or a backend |
| Move from an older version | [Upgrading](start-here/upgrading.md) | An old-to-new table of every break in 0.9.0 |
| Use Beak with Serverpod | [Serverpod](serverpod/index.md) | The admin app, the client bridge, versions |
| Build a specific thing | [Guides](guides/index.md) and [Recipes](recipes/index.md) | Models, the panel, forms, blocks, the backend |
| Look up an API | [Reference](reference/index.md) and [Cheatsheet](reference/cheatsheet.md) | Annotations, options, REST routes, CLI commands |
| Point a coding agent at Beak | [AI directory](ai/index.md) | Rules, task map, prompts |
| Change Beak itself | [Contributing](contributing/index.md) | Setup, the gate, guardrails |

## Continue reading

- [Quickstart](start-here/quickstart.md): generate and run the smallest project.
- [Tutorial](tutorial/index.md): the declarative resource model, through the shop example.
- [Choose your path](start-here/paths/index.md): start from a database, an app or a backend you already have.
- [Reference](reference/index.md): every annotation, field type, rule, block, option, REST route, CLI command and exception.
