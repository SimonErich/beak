# Beak docs style guide (writers read this first)

This file is not published (it lives under `docs/_internal/`, excluded from the
build). It is the contract every docs page follows so the whole site reads like
one person wrote it: a very good developer explaining their own library to a
friend. Friendly, professional, approachable, a little cheeky. Never sloppy.

## Voice

- **Second person.** "You define a model", not "one defines a model".
- **Short, declarative sentences.** One idea per sentence. Cut every word that
  does not earn its place.
- **Concrete before abstract.** Show the thing, then explain it. Lead a concept
  with the plain-English idea, then the code, then the edge cases.
- **Two audiences, one page.** Beginners read top to bottom. Experts scan for the
  table or the signature. Put the "just tell me the fields" material in tables and
  in the Reference section so nobody has to read prose to find a parameter name.
- **Cheeky, lightly.** A dry aside or a bird pun is welcome when it lands. It is
  seasoning, not the meal. If a joke makes a sentence longer or less clear, cut it.

## The bird thing

Flutter's mascot is a bird. Birds have beaks. Beak is the toolbox for the
dashboard or admin panel that almost every app grows eventually. Its ORM sibling
is `worm` ("the bird has to eat something"). You may lean on this once or twice
per page for warmth or a metaphor, never as filler. Good metaphors earn their
keep: "a `BeakColumn` is declared once and feeds six mouths — the table cell, the
form field, the detail row, the filter, the API validator, and the CSV column."

## Banned (a reviewer greps for these)

- **Em-dashes (`—`).** Use a period, a comma, a colon, or parentheses. Hyphens in
  compound words are fine.
- **Rhetorical questions as headings.** Write "What a column is", not "What is a
  column?". (Exception: the deliberate page titles "What is Beak?" and "Why
  Beak?" already exist in the nav. Do not invent new ones.)
- **Marketing words:** seamless, effortless, powerful, blazing, robust, simply,
  just (as in "just call"), unlock, supercharge, delightful, magic, revolutionary.
- **Over-enthusiasm.** No exclamation-point storms, no "you're going to love
  this". State what it does; the reader decides how they feel.
- **The word "UseCase".** Beak's frontend has no UseCase layer (see Invariants).
  If you are tempted to write it, you have the architecture wrong.

## Page structure (every page)

1. **Front matter** (Material reads both keys):

   ```yaml
   ---
   title: Defining models
   description: One sentence a search result can show. What the page gives you.
   ---
   ```

2. **One `#` H1** matching the title.
3. **A one or two sentence opener** telling the reader what they will be able to
   do after this page. No preamble like "In this guide we will".
4. **Body**: prose + worked code + tables. Use `##`/`###` for structure.
5. **A "Continue reading" footer** with two or more links to related pages:

   ```markdown
   ## Continue reading

   - [Column types](column-types.md) every built-in column and its options.
   - [Validation rules](validation-rules.md) the rules you attach to a column.
   ```

## Formatting tools

- **Admonitions** for callouts (Material):
  `!!! note`, `!!! tip`, `!!! warning`, `!!! danger`, `!!! example`. Collapsible
  ones use `??? note`.
- **The tutorial rhythm**: after a runnable code block, add a short
  `!!! note "What just happened"` and, where useful, a
  `!!! question "What this skipped"` (the `question` admonition renders as a "?"
  box) pointing at the page that covers the skipped part. Borrowed from the worm
  docs; keep it to a few bullet points.
- **Mermaid** for flows and graphs, via the configured fence:

  ````markdown
  ```mermaid
  flowchart LR
    A --> B
  ```
  ````

- **Tabs** for "SQLite vs Postgres" style alternatives (`=== "Tab"`).
- **Code fences** always carry a language (` ```dart `, ` ```bash `, ` ```yaml `).
  Add `title="path/to/file.dart"` when the snippet is lifted from a real file.

## Code blocks (the accuracy rule)

- **Every Dart snippet is copied from a real, compiling source file.** Never
  invent an API. If you need an example the codebase does not have, pick the
  closest real one and trim it, keeping the real names and signatures.
- **Trace every snippet to `EXAMPLE_MAP.md`.** That file maps each page slug to
  the exact source file(s) and symbol you quote. If your page needs a snippet not
  listed there, read the source yourself and quote it verbatim, then note it.
- **Quote signatures verbatim** in the Reference section. Do not paraphrase a
  constructor's parameters; copy them.
- Trim aggressively (drop imports and unrelated members) but never rename or
  restructure. A reader should be able to open the cited file and find your lines.

## The two-app rule (do not mix them up)

Beak ships two demo apps. They use **different models**. Never put a column
constant from one app into a snippet themed around the other.

- **`apps/reference_admin*`** is the clean teaching store (a small coffee
  roastery: Products, Categories, Tags, Users, Orders). Use it for the **Tutorial
  ("First Flight")** and **Core concepts**. Its server runs on **port 8080**
  (`apiBaseUrl: 'http://localhost:8080'`).
- **`apps/beak_superdashboard`** is the kitchen-sink showcase (49 models, every
  block, every view mode, custom screens). Use it for **feature, blocks, charts,
  and reference** pages. Its server runs on **port 8180**
  (`apiBaseUrl: 'http://localhost:8180'`). Match the port to the app in every
  snippet or a reader hits connection-refused.
- `hasOne` only exists in the superdashboard's `order.dart`. When you need a
  `BeakHasOne` example, take it from there and say which app it is from.

## Invariants writers must get right (these are Beak's laws)

- **No Material.** Beak's UI is `obers_ui` only. Never show
  `package:flutter/material.dart` or `cupertino.dart`. Widgets are `HookWidget`
  (never `StatefulWidget`). State is Signals, DI is GetIt (a package-scoped
  `beakLocator`), routing is go_router. App authors rarely touch these directly;
  Beak wires them from config.
- **The four layers, no UseCase.**
  - Backend: `Handler (Shelf) -> Service -> DataSource`. The error-mapping
    middleware is the single catch boundary; it maps the sealed `BeakException`
    family to HTTP status + JSON.
  - Frontend: `Widget -> ViewModel -> Repository -> DataSource`. ViewModels expose
    `ReadonlySignal`s and never `try/catch`; the Repository is the catch boundary
    and returns `BeakResult<T>`.
- **The one-definition promise.** One typed `const BeakColumn` drives the table
  cell, the form field (with client validation that mirrors the server), the
  detail row, the filter, the REST validation, and the CSV export column. Users
  never write a string field reference and never touch `dynamic`.
- **Dual-mode record blocks.** The same block tree
  (`BeakFieldBlock`/`BeakFieldGroupBlock`/`BeakRelationBlock`) renders read-only
  values inside a `BeakRecordScope` (a resource's `detail`) and editable inputs
  inside a `BeakFormScope` (a resource's `formLayout`). One layout, two surfaces.
- **Source-agnostic data.** `BeakDataSource` (in `beak_core`) is the interface.
  `WormDataSource` (backend, over the worm ORM) and `HttpBeakDataSource`
  (frontend, over REST) both implement it. A future `beak_serverpod` can add a
  `ServerpodDataSource` without touching `beak_core` or `beak_backend`. worm types
  never leak past `beak_backend`.
- **Storage is pluggable.** `BeakStorageConfig` (memory/local/s3/ftp) resolves to
  a `BeakStorageDriver` via a registry. File rules live on the column and run on
  both client and server.

## Cross-linking

- Link with **relative paths to the `.md` file**: `[Columns](column-types.md)`,
  `[The panel](../panel/index.md)`. MkDocs rewrites these to site URLs and
  `--strict` fails the build on any broken one, so links are checked for you.
- Every page's "Continue reading" should point forward and sideways so the whole
  site forms a connected graph. Section index pages link down into their section.
- Use the exact slugs from the frozen nav (see `mkdocs.yml`). Do not invent slugs.

## Length and pacing

- Concept and feature pages: aim for something a reader finishes in one sitting.
  Depth over padding. If a page wants to be huge, it is probably two pages.
- Reference pages are exhaustive by design: every public member documented, in
  tables. That is the one place completeness beats brevity.
- Tutorial chapters end with a command the reader runs and the output they should
  see, then a short "what just happened".
