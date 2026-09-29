# Beak docs style guide (writers read this first)

This file is not published (it lives under `docs/_internal/`, excluded from the
build). It is the contract every docs page follows, so the whole site reads like
one person wrote it: a working engineer explaining their own library to a
colleague. Direct, funny, precise, never salesy. Load the `simon-voice` skill
before you write a page; this file translates it to documentation.

## Voice

The person on the page argues with evidence, not adjectives. They tell you the
cheaper option exists, they tell you which part of Beak is rough and why, and
they tell you what they do not know yet. Warmth is real but never performed.

**The bar for every sentence: does the reader lose information if it goes?**
If not, delete it. Nothing that performs understanding: no "As you can see", no
"This makes X much cleaner", no closing sentence that praises or re-explains what
the code above just did. Say what it does. Stop.

**Non-negotiables**

- No em-dashes (`—`). Comma, period, colon or parentheses.
- No rhetorical questions to the reader, anywhere on the page (not only in
  headings). A question is fine only when it is a real one the page then answers
  with a decision table.
- No adjective chains. One adjective, or a number, or a fact.
- No "not only X, but also Y", no "it is not just X, it is Y".
- No hype: revolutionary, innovative, cutting-edge, state-of-the-art, game-changer,
  seamless, effortless, powerful, blazing, robust (as filler), supercharge,
  delightful, magic, unlock, elevate, empower, leverage (as a verb), "just" before
  a verb ("just call"), "simply". The gate greps for a subset of these.
- No superlative self-praise. State the fact that happens to be impressive
  ("one definition feeds six surfaces"), let it do the work.
- No urgency theatre, no engagement bait, no exclamation-point storms.
- No bold-carpeting. Bold is for a term being defined, a filename, or a label.
  Two or three per page is plenty.

**Structural moves (these matter more than word choice)**

1. **Context before content.** Open with where the reader stands or what changes,
   then the new thing. "You have a `Product` schema and no screen for it yet.
   Here is the smallest resource that gives you one."
2. **Pre-emptive honesty.** Name the flaw or limit early, with its reason and what
   it buys: flaw, because, what you get. "Related rows on the default show page are
   read-only. That keeps the page to one query; edit them in the form." Never flaw,
   then apology.
3. **Mechanism before recommendation.** Explain the cost dynamics, then the
   recommendation falls out: short-term effect, mid-term effect, why, therefore.
4. **Name the option you argue against, fairly.** Generated panel or authored
   panel, Beak API in Serverpod or the frontend-only bridge: show what each buys
   before you pick.
5. **Ownership transfer.** Tell the reader what they do not have to do. "Beak
   writes the migration. You never touch a column name."
6. **Bullets only where the reader chooses, checks or acts.** Prose for reasoning,
   bullets and tables for options, requirements, steps and homework.
7. **Ranges, never fake precision** for anything estimated ("about 2 - 3 seconds
   for 10,000 rows", "6 to 8 weeks"). One number only when it is a guarantee.
8. **Caveats as confidence.** "This is checked at boot, not per request" reads as
   strength.
9. **Soft landing.** End on the door that opens next (`## Continue reading`), not
   on a push or a summary of the page you just read.
10. **Say it once.** Each angle earns one paragraph. When two paragraphs make the
    same point, keep the one with the concrete detail.

**Sentence mechanics.** Long-ish but flat: median about 18 words, comma chains
instead of nested clauses, few semicolons. Short fragment openers are welcome
("Done.", "That is all it takes.", "Same file, no regeneration."). Colon then
payoff: "The rule is simple: a field's Dart type picks the column." Parenthetical
asides carry the real detail, often the caveat. Paragraphs are 1 - 4 lines; a wall
of text is out of character. Contractions are fine ("don't", "it's").

**Funny, and cheeky.** The humour is dry, specific and about the situation, never
about the reader: understatement, honest self-deprecation about the framework
("this part is not pretty, and it is like this on purpose"), a parenthetical
aside that lands, the occasional `;)` after a deliberate exaggeration. Budget:
one or two jokes per page, at most one smiley per page, zero in reference pages,
security and upgrade guides. If a joke makes a sentence longer or the fact harder
to find, cut the joke. Acknowledgements stay flat and repeated ("True.", "Makes
sense."); a different colourful reaction each time is the tell.

**Register by page type.** Tutorials and concepts get the full voice. Guides and
recipes get most of it. Reference pages are dry: tables, signatures, no jokes.
`ai/` pages are plain, imperative and prescriptive for a machine reader: rules,
task tables, commands. No humour there.

## The bird thing

Flutter's mascot is a bird. Birds have beaks. Beak is the toolbox for the
dashboard or admin panel that almost every app grows eventually. Its ORM sibling
is `worm` ("the bird has to eat something"). Lean on it once or twice per page for
warmth or a metaphor, never as filler. Good metaphors earn their keep: "a schema
field is declared once and feeds six mouths: the table cell, the form input, the
detail row, the filter, the API validator and the CSV column."

## Banned (the gate greps for these; the voice rules above go further)

- Em-dashes; question headings (except the titles "What is Beak?" and "Why
  Beak?"); the words seamless, effortless, powerful, blazing, robust, simply,
  supercharge, delightful, magic, revolutionary (and forms such as "magically");
  "just" before a verb; two exclamation marks on one line; "unlock" plus power,
  potential, value, magic, full, true, hidden or insights; the word "UseCase"
  (Beak has no UseCase layer; only the pages that explain that may name it).
- Nothing else is machine-checked, but reviewers hold the whole voice list to the
  same standard. A page that passes the gate and reads like a brochure fails
  review.

## Page structure (every page)

1. **Front matter** (Material reads `title`, `description` and `search`; the
   docs gate, `dart run tool/check_docs.dart`, reads the rest):

   ```yaml
   ---
   title: Defining models          # equals the nav label; unique site-wide
   description: One sentence a search result can show, 160 characters at most.
   type: guide                     # index|tutorial|guide|concept|reference|recipe|example|ai
   audience: [beginner, expert]    # beginner|expert|agent|contributor
   status: draft                   # draft|preview|stable
   search: {boost: 2}              # reference and ai pages only
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

## Page types and status

Every page has a `type`, and a page marked `status: stable` carries the
headings its type promises. The gate enforces this for stable pages only, so a
stub or a page awaiting its rewrite stays `status: draft`. `dart run
tool/check_docs.dart --release` fails while any page is still a draft; that is
the completeness ratchet the release branch runs.

| Type | Headings a stable page carries |
| --- | --- |
| `index` | `## Which page to read`, a table with the columns You want to..., Read, For that links every page of the section |
| `tutorial` | `## What you'll build`, `## Before you start`, `## Run it`, `## Checkpoint` |
| `guide` | `## At a glance`, `## Rules and limits`, `## Verify it`, `## Reference` |
| `concept` | `## The idea in one picture`, `## How it works`, `## Why it is shaped this way`, `## What it means for you` |
| `reference` | `## Import`, `## Summary`, `## Source` |
| `recipe` | `## Recipe`, `## How it works`, `## Variations`, `## Verify` |
| `example` | `## At a glance`, `## Run it`, `## Tour`, `## Where things are`, `## Features shown`, `## Tests`, `## Limits` |
| `ai` | `## Rules`, `## Machine-readable twin` |

Other rules the gate enforces: a nav label equals the page title (the home page
is exempt), every nav section opens on an `index.md` that links all of its
children, backticked `packages/`, `examples/`, `tool/` and `deploy/` paths in
prose exist, and every path listed in `docs/_internal/url-manifest.txt` is still
a page or a `redirect_maps` key in `mkdocs.yml`. Move a page with `git mv` and
add a redirect for the old path; never delete a published path.

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

## Canonical example sources

Every snippet comes from a real file that compiles and is tested. Prefer
`--8<-- "path:Symbol"` section includes (`// --8<-- [start:Symbol]` markers in the
source) over pasted code: they cannot drift. Titled fences must quote their file
verbatim (the gate checks them chunk by chunk).

| Example | Use it for |
| --- | --- |
| `examples/quickstart` | The scaffold `beak create` writes; the first resource. Byte-identical to the generator output. |
| `examples/clean_beak_config` | The complete shop and the primary teaching source: schemas with semantic fields and exact money, resources, form screens and sections, named invoice actions, dynamic attributes and variants, media, imports, graph preparer, custom screens and widgets. API on port 8080, no login. |
| `examples/foodio-adminpanel` | High-fidelity app: composed lists with presets and saved views, a wizard with named steps, record templates and presentations, summaries, printable documents, durable effects, custom navigation and theme. API on port 8081. |
| `examples/showcase` | Everything the others do not use: every block type, every column kind and relation kind, soft deletes. API on port 8082. |
| `examples/serverpod` | A Beak admin inside a Serverpod 4 workspace (Author and Book). |

Do not invent a feature in an example when it only exists in the framework. Use a
focused package test or implementation excerpt and say where it comes from.
Application schemas use generated `Model.field` helpers. Keep runtime and policy
code in the domain layer and screen files focused on presentation.

## Facts writers verify before writing them down

A page is not done until every claim has been checked against the working tree:

- Every class, parameter, annotation and enum value exists (`codegraph explore`
  or `grep` the source). Quote signatures verbatim in reference pages.
- Every CLI command and flag is run once (`dart run packages/beak_cli/bin/beak.dart
  <command> --help`, plus the command itself in a scratch project when the page
  shows its output). Paste real output, trimmed.
- Every file path exists. Every default value is read from the source, not
  remembered.
- If code and an older page disagree, the code wins, and you fix the page.
- Say what is not covered. A limitation you know about belongs on the page.

## Invariants writers must get right (these are Beak's laws)

- **No Material.** Beak's UI is `obers_ui` only. Never show
  `package:flutter/material.dart` or `cupertino.dart`. Widgets are `HookWidget`
  (never `StatefulWidget`). State is Signals, DI is GetIt, routing is go_router.
  Each `BeakPanel` builds its own GetIt scope and exposes it through
  `beakDependencies(context)`. App authors rarely touch these; Beak wires them.
- **The four layers, no UseCase.**
  - Backend: `Handler (Shelf) -> Service -> DataSource`. The error-mapping
    middleware is the single catch boundary; it maps the sealed `BeakException`
    family to HTTP status and JSON.
  - Frontend: `Widget -> ViewModel -> Repository -> DataSource`. ViewModels expose
    `ReadonlySignal`s and never `try/catch`; the Repository is the catch boundary
    and returns `BeakResult<T>`.
- **The one-definition promise.** An annotated schema class (`@Resource`, `@Column`,
  relationship annotations, optional `behavior` and `validationRules`) drives the
  table cell, the form input with client validation that mirrors the server, the
  detail row, the filter, the REST validation, the migration and the CSV column.
  Users never write a string field reference and never touch `dynamic`: they use
  generated `ProductModel.name` references.
- **Two ways to boot a panel, both supported.** The generated `BeakApp` (from
  `beak.yaml`, `lib/beak/app.g.dart`) and an authored `BeakPanel(resources: [...])`.
  `beak eject main` is the switch. Teach the authored form in the tutorial and
  the generated one in the quickstart, and always say which one a page assumes.
- **Shared form layouts.** A `BeakFormScreen` serves read, create and edit roles
  from the same typed field layout. `BeakFormSections` projects sections into
  forms, tabs or wizard steps. Record blocks read `BeakRecordScope`; custom form
  widgets edit the draft supplied by `BeakDraftScope`.
- **Writes are graph commits.** Form saves go through `POST /api/commits` with a
  receipt, so a save is atomic, idempotent and recoverable. Model behavior
  (`BeakModelBehavior`) and record rules re-run on the server.
- **Source-agnostic data.** `BeakDataSource` (in `beak_core`) is the interface.
  `WormDataSource` (backend, over the worm ORM) and `HttpBeakDataSource`
  (frontend, over REST) implement it. Serverpod has two supported paths: the
  admin app inside a Serverpod workspace (Beak's API runs in the Serverpod server
  behind one gated endpoint, over `ServerpodSessionAdapter`), and the frontend-only
  bridge (`ServerpodResource`). worm types never leak past `beak_backend`.
- **Storage is pluggable.** `BeakStorageConfig` (memory/local/s3/ftp) resolves to
  a `BeakStorageDriver` via a registry. File rules live on the column and run on
  both client and server.
- **Authorization is server-side.** Panel permissions only hide UI. `BeakPolicies`
  (deny by default) and the row, field and action policies enforce.

## Definition of done for a page

1. Front matter valid, `status: stable`, headings for its type present.
2. Every snippet is a section include or a verbatim titled fence; every claim
   verified (see above).
3. `dart run tool/check_docs.dart` passes and `mkdocs build --strict` is clean.
4. Voice pass: read it aloud once. Delete every clause the reader would not miss.
   Zero em-dashes, zero rhetorical questions, no hype, no bold-carpeting.
5. The `## Continue reading` links go forward and sideways, never in a circle
   back to the page you came from.

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
