---
title: Writing docs
description: Write a docs page that passes the gate, quote code so it cannot drift, and preview and ship the site.
type: guide
audience: [contributor, agent]
status: stable
---

# Writing docs

A page on this site is checked by a machine before a person reads it. This page is the contract: which page types exist, how to quote code so it cannot drift from the source, what `tool/check_docs.dart` refuses, and how to preview and ship the result.

The voice and the invariants live in the style guide, `docs/_internal/STYLE_GUIDE.md` ([on GitHub](https://github.com/SimonErich/beak/blob/main/docs/_internal/STYLE_GUIDE.md)). It is not published on the site. This page is the part of it you need on the day you write.

## At a glance

| Step | Do this | Tool |
| --- | --- | --- |
| 1 | Pick the page in the nav. Do not rename or move it. | `mkdocs.yml` |
| 2 | Find real source to quote. Prefer a section include. | `docs/_internal/EXAMPLE_MAP.md`, the `--8<--` markers in the source |
| 3 | Write the page with the headings its `type` requires. | `docs/<section>/<slug>.md` |
| 4 | Run the structural check. | `dart run tool/check_docs.dart` |
| 5 | Build with warnings as errors. | `mkdocs build --strict` |
| 6 | Set `status: stable`, then refresh the agent bundle. | `melos run agent-docs` |

## The shape of a page

Every page opens with front matter. Material reads `title`, `description` and `search`; the gate reads the rest.

```yaml
---
title: Writing docs
description: One sentence a search result can show, 160 characters at most.
type: guide
audience: [contributor, agent]
status: draft
---
```

The `title` equals the nav label and is unique on the site. The H1 repeats it. A one or two sentence opener says what the reader can do after the page. The page ends with `## Continue reading` and two or more relative links to pages that exist. Reference and AI pages add `search: {boost: 2}`.

`type` picks the headings a stable page must carry:

| Type | Headings a stable page carries |
| --- | --- |
| `index` | `## Which page to read`, a table with the columns You want to..., Read, For that, linking every page of the section |
| `tutorial` | `## What you'll build`, `## Before you start`, `## Run it`, `## Checkpoint` |
| `guide` | `## At a glance`, `## Rules and limits`, `## Verify it`, `## Reference` |
| `concept` | `## The idea in one picture`, `## How it works`, `## Why it is shaped this way`, `## What it means for you` |
| `reference` | `## Import`, `## Summary`, `## Source` |
| `recipe` | `## Recipe`, `## How it works`, `## Variations`, `## Verify` |
| `example` | `## At a glance`, `## Run it`, `## Tour`, `## Where things are`, `## Features shown`, `## Tests`, `## Limits` |
| `ai` | `## Rules`, `## Machine-readable twin` |

`audience` takes `beginner`, `expert`, `agent` and `contributor`, one or more. The tab you write in sets the register: tutorials and concepts get the full voice, guides most of it, reference pages are dry, and `ai/` pages are plain and imperative.

## The voice in six rules

1. No em-dashes. Use a comma, a period, a colon or parentheses.
2. No rhetorical questions, and no heading written as a question. The two titles "What is Beak?" and "Why Beak?" are the exceptions.
3. Open with where the reader stands, then the new thing. Name a flaw early, with its reason and what it buys.
4. One adjective, or a number, or a fact. Give ranges for anything estimated.
5. Bold is for a term being defined, a file name or a label. Two or three per page.
   In a bullet list where more than three bullets start with a bold label, remove the bold and keep the label text with its period or colon.
6. Delete every clause the reader would not miss, including a closing sentence that praises the code above it.

The gate also greps prose for these words: `seamless`, `effortless`, `powerful`, `blazing`, `robust`, `simply`, `supercharge`, `delightful`, `magic`, `revolutionary` and their forms, `just` before a verb (`just call`), two exclamation marks on a line, "unlock" plus `power`, `potential`, `value`, `magic`, `full`, `true`, `hidden` or `insights`, and the word `UseCase`, which names a layer Beak does not have. Inline code and fenced code are skipped, so a symbol that contains one of them is safe, and console output copied from a real error keeps its em-dash. Do not reword real output to satisfy the gate.

Beak's mascot is a bird, and its ORM sibling is `worm`. Use the bird once or twice per page where it carries a metaphor, and not at all in reference pages.

## Quote code, never paste it

Every Dart snippet comes from a real file that compiles. There are three ways to show it, in order of preference.

**A section include.** The source file carries a pair of line comments around the symbol. The start marker is `--8<--`, one space, then `[start:Name]`, and the end marker is the same with `[end:Name]`. `packages/beak_frontend/lib/src/data/beak_run.dart` has such a pair around `beakRun`; open it to see the shape. The page then holds one line inside a code fence, alone on its line: `--8<-- "packages/beak_frontend/lib/src/data/beak_run.dart:beakRun"`. MkDocs reads the file at build time and replaces that line with the section, dedented, so the snippet cannot drift. Here is that include, rendered:

```dart title="packages/beak_frontend/lib/src/data/beak_run.dart"
--8<-- "packages/beak_frontend/lib/src/data/beak_run.dart:beakRun"
```

Conventions:

- Put the markers around the declaration, not around its doc comment.
- A name uses letters, digits, `_` and `-`, and the end marker comes after the start marker.
- Add markers with a targeted edit that only adds comment lines. Run `dart format --set-exit-if-changed` on the file afterwards, and re-read it first if someone else may be editing it.
- Whole-file includes (`--8<-- "path"`) work but tend to quote more than the page needs.
- Never use a line range such as `file.dart:12:20`. MkDocs reads it, but a rename moves the quoted lines without any check noticing, and the agent bundle build rejects it. `check_docs.dart` fails it too. Put start and end markers around the lines in the source and include the named section.
- Never write a marker inside a page. MkDocs deletes any line that contains one, in a fence or in inline code, and the rendered page loses the line without a warning. `check_docs.dart` fails such a line. A semicolon written directly before the marker escapes it: mkdocs keeps the line and removes the semicolon. The source of this page has one in front of the marker below, and the reader sees only the marker: `;--8<-- [start:Name]`. The semicolon has to touch the marker.

**A verbatim titled fence.** A fence with `title="packages/..."`, `examples/...`, `tool/...` or `deploy/...`, or titled with one of the root files `melos.yaml`, `mkdocs.yml`, `pubspec.yaml`, `analysis_options.yaml`, `docker-compose.yml`, `CONTRIBUTING.md` or `README.md`, claims to quote that file, and the gate compares it chunk by chunk. Trim as hard as you like, but keep names and order. Mark what you dropped with a line that starts with `// ...`, `# ...` or `...`. Indentation and blank lines do not count, and source comment lines may be left out. A fence in `bash`, `console`, `text`, `sh`, `shell`, `output` or `diff` is a transcript and is not compared.

**An untitled fence.** For illustrative code only, with real API names, and clearly labelled as illustrative. A fence titled with a file that belongs to the reader's project (`lib/main.dart`) is not compared either.

Run every command you document and paste the output, trimmed. A `bash` fence is never checked, so this is the only thing keeping it honest.

## What the gate refuses

`dart run tool/check_docs.dart` reads the tree, not the built site. It reports one line per problem and exits non-zero:

```text
Docs check failed:
  docs/index.md:11: style guide bans "powerful" (state what it does and show the code)
  docs/index.md:11: style guide bans the em-dash (a period, a comma, a colon, or parentheses)
  docs/index.md:17: style guide bans a heading written as a question (write "What a column is", not "What is a column?")
  docs/index.md:13: the fence titled "tool/a.dart" does not quote it: "const int answer = 43;" is not in that file. Correct the code, or drop the title if the block is illustrative.
  docs/index.md: status is stable, but a page of type "guide" needs the heading "## At a glance". Add it, or mark the page "status: draft"
```

| Check | Fails on |
| --- | --- |
| Front matter | no `title` or `description`, invalid YAML, a `type`, `audience` or `status` outside the allowed values, a description over 160 characters, an H1 that differs from the title |
| Footer | no `## Continue reading` |
| Fences | a titled fence whose file does not exist or does not contain the code |
| Includes | a missing file, a missing start or end marker, an end above the start, a line range (`file.dart:12:20`) |
| Markers on a page | a line holding a section marker that mkdocs would delete (not escaped with a leading semicolon) |
| Prose bans | the words and patterns listed above, checked outside code |
| Stable pages | a heading missing from the table above |
| Paths in prose | a backticked `packages/`, `examples/`, `tool/` or `deploy/` path that does not exist |
| Nav | a label that differs from the title, a duplicate title, a page missing from the nav, a section that does not open on an `index.md` whose `## Which page to read` section links every child |
| URL manifest | a path in `docs/_internal/url-manifest.txt` that is neither a page nor a `redirect_maps` key, a redirect to a page that does not exist |
| llms.txt | a page that no `llmstxt` glob matches, a glob that matches no page |

`mkdocs build --strict` covers what this cannot: broken relative links and anchors.

## Draft, preview and stable

`status` is a ratchet. A `draft` page is a stub or awaits its rewrite, and the gate checks it lightly. A `preview` page documents something that has not shipped. A `stable` page promises the headings of its type and holds every fact verified against the working tree.

`dart run tool/check_docs.dart --release` (or `melos run check-docs-release`) fails while any page is still `draft`, and passes `preview` and `stable`:

```text
Docs check failed:
  docs/ai/index.md: status is draft. A release needs every page stable or preview
```

The docs workflow runs it on every `release/**` branch and every `v*` tag. Day-to-day runs do not, which is why a half-written page can sit on `main`. [Releasing](releasing.md) covers when the ratchet bites.

## Add, move or remove a page

- **Add.** Put the file under the right section, add it to `nav:` in `mkdocs.yml` with a label equal to its title, and link it from that section's `index.md`. The section's `llmstxt` glob picks it up if it lives in an existing directory. A new directory needs a glob.
- **Move.** Use `git mv` and add the old path to `redirect_maps` in `mkdocs.yml`. The target may carry a `#fragment`.
- **Remove.** Do not. A published path stays a page or a redirect key. `docs/_internal/url-manifest.txt` lists every path the site has served, and each line must resolve. Add a line for every page a release publishes, and never remove one.

## Preview locally

The site is MkDocs with the Material theme and four plugins (search, `llmstxt`, `redirects`, `minify`), pinned in `docs/requirements.txt`. Install into a virtual environment outside the repo:

```bash
python3 -m venv ~/.venvs/beak-docs
~/.venvs/beak-docs/bin/pip install -r docs/requirements.txt
~/.venvs/beak-docs/bin/mkdocs serve
```

```text
INFO    -  Documentation built in 8.94 seconds
INFO    -  Serving on http://127.0.0.1:8000/beak/
```

The address carries `/beak/` because `site_url` in `mkdocs.yml` does. `serve` rebuilds on save. Material and the plugins print a MkDocs 2.0 warning banner on every run. It is harmless, and setting both `NO_MKDOCS_2_WARNING=true` and `DISABLE_MKDOCS_2_WARNING=true` silences it. CI sets both.

Before you push, run the same two checks CI runs:

```bash
dart run tool/check_docs.dart
~/.venvs/beak-docs/bin/mkdocs build --strict -d "$(mktemp -d)"
```

## How the site ships

`.github/workflows/docs.yml` runs on pushes to `main` and `release/**`, on `v*` tags, and on pull requests that touch `docs/`, `mkdocs.yml`, `CHANGELOG.md`, `examples/`, `packages/`, `tool/`, the docs tests or the workflow. It runs the tests of the checker and the bundle builder, `dart run tool/check_docs.dart` and `dart run tool/build_agent_docs.dart --check`, and on `release/**` and on tags also the `--release` ratchet, then installs the pinned requirements and builds with `mkdocs build --strict`. Only a push to `main` publishes to GitHub Pages. A pull request builds and stops.

Pages quote package and example source, so a change to `packages/` or `examples/` can break a docs build without touching `docs/`. That is the point of the trigger.

## The agent docs bundle

Coding agents read a copy of these pages that matches the Beak version their project resolved. `tool/build_agent_docs.dart` turns `docs/` into plain Markdown, expands the `--8<--` includes, and commits the result to `packages/beak_core/doc/agent-docs`. After any change to `docs/`, a file a page quotes, `mkdocs.yml`, `CHANGELOG.md` or `docs/_agents/blocks`, regenerate it:

```bash
melos run agent-docs
```

`melos run check-agent-docs` builds in memory and fails on any difference, listing the stale files. It is part of `melos run analyze` and of the docs workflow, so a docs change is not finished until the bundle is regenerated and committed. [Machine-readable docs](../ai/machine-readable-docs.md) describes what agents get.

## Rules and limits

- Voice is mostly a review matter. The gate knows the ban list and nothing else. A page that passes it and reads like a brochure fails review.
- The routing check reads one section. A link to each child has to sit between `## Which page to read` and the next `#` or `##` heading. It does not check that the links are in a table.
- Mermaid is not checked. The diagrams render in the browser, so a syntax error shows up as an error box on the published page and nowhere in the gate. `mkdocs serve` shows it. A real check needs a headless browser, which is why CI does not have one.
- Transcripts are not compared. Output pasted into a `bash` or `text` fence can go stale without a failure.
- The style guide is not on the site. Link it by its GitHub URL. A relative `.md` link into `docs/_internal` builds with a single INFO line, even under `--strict`, and leaves a dead link on the published page.
- Pages in `docs/_agents` are templates. They ship in the bundle, not on the site, and are checked by `build_agent_docs.dart`.
- `serve` is not the gate. It builds without `--strict`, so a broken link shows up as a warning in the terminal and nowhere else.

## Verify it

```bash
dart run tool/check_docs.dart
```

```text
Docs check passed.
```

Then build with warnings as errors. Under `--strict` any warning stops the build with a non-zero exit, and a clean run ends with `Documentation built in` and a time:

```bash
~/.venvs/beak-docs/bin/mkdocs build --strict -d "$(mktemp -d)"
```

If you touched `docs/`, a quoted file or the changelog, check the bundle:

```bash
dart run tool/build_agent_docs.dart --check
```

```text
stale: packages/beak_core/doc/agent-docs/contributing/writing-docs.md
run: melos run agent-docs
```

Run `melos run agent-docs` and the same check passes.

## Reference

| File | Role |
| --- | --- |
| `tool/check_docs.dart` | the structural and style gate; `--release` adds the draft ratchet |
| `test/check_docs_test.dart` | tests for the gate, run by CI before the gate itself |
| `test/build_agent_docs_test.dart` | tests for the bundle builder and the corrections-table check |
| `tool/src/docs_snippets.dart` | the `--8<--` include and marker syntax, shared by the gate and the bundle builder |
| `tool/build_agent_docs.dart` | builds and checks the agent bundle |
| `mkdocs.yml` | nav, plugins, redirects, `llmstxt` sections, snippet settings |
| `docs/requirements.txt` | the pinned MkDocs toolchain |
| `docs/_internal/STYLE_GUIDE.md` | the full style guide, unpublished |
| `docs/_internal/EXAMPLE_MAP.md` | which source file backs which topic, unpublished |
| `docs/_internal/url-manifest.txt` | every path the site has served |
| `.github/workflows/docs.yml` | the build, the ratchet and the Pages deploy |

## Continue reading

- [Releasing](releasing.md) the release-only docs gate and the bundle refresh.
- [Machine-readable docs](../ai/machine-readable-docs.md) what the bundle and `/llms.txt` give an agent.
- [Conventions](conventions.md) what to regenerate after a code change.
