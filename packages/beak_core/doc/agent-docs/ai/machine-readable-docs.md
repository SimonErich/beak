# Machine-readable docs

> Read Beak's docs as files, from llms.txt, llms-full.txt, Markdown twins or the version-matched bundle in beak_core, and know what each form promises.

For coding agents. Humans: see [Writing docs](../contributing/writing-docs.md). The docs exist in four machine-readable forms. Three are published with the site, and one ships inside the code you resolved. They hold the same pages; they differ in size, in what they are pinned to, and in how you find things in them.

## Rules

- MUST prefer the bundle in `.dart_tool/beak/docs/` when it exists. It documents the Beak version the project resolved. The site documents the state of `main`, which may be newer or older than that.
- MUST start at `ai-index.md` in the bundle, or at `/ai/index.md` on the site. Do not start from a search result.
- NEVER load `llms-full.txt` into a context window. It is about 3.6 MB. Search it, or fetch the twin of one page.
- MUST fetch a twin instead of scraping the HTML. A twin is the page as Markdown, with code included from the source files.
- MUST read the version from `manifest.json` (`beak`) before you trust a signature, and MUST compare it with the version in `pubspec.lock`. `beak doctor` does the comparison.
- NEVER edit anything under `.dart_tool/beak/docs/` or `packages/beak_core/doc/agent-docs/`. The first is overwritten by `beak docs`, the second by `melos run agent-docs`. Edit `docs/` and regenerate.
- MUST report a page that disagrees with the source. The source wins.

## The four forms

| Form | Where | What it is | Pinned to |
| --- | --- | --- | --- |
| The bundle | `.dart_tool/beak/docs/` in the project, from `doc/agent-docs/` in `beak_core` | Every page as plain Markdown, plus `SUMMARY.md`, `llms.txt`, `changelog.md`, `ai-index.md` and `manifest.json` | The resolved Beak version |
| `llms.txt` | `https://simonerich.github.io/beak/llms.txt` | The index: a title, a summary and one list of links per section | `main` at the last publish |
| `llms-full.txt` | `https://simonerich.github.io/beak/llms-full.txt` | Every page in one file, about 3.6 MB | `main` at the last publish |
| A Markdown twin | `https://simonerich.github.io/beak/<page path>/index.md` | One page as Markdown | `main` at the last publish |

The pages themselves are `docs/**/*.md` in the repository. Those files hold `--8<--` includes that are not expanded, so read the twin or the bundle instead when you need the code.

## llms.txt

The site builds `llms.txt` and `llms-full.txt` with the `llmstxt` plugin. The sections and their page globs are in `mkdocs.yml`, and `tool/check_docs.dart` fails when a page matches no glob or a glob matches no page, so every page is listed once. The bundle carries its own `llms.txt`, built from the same globs, with relative links and a one-line description after each link.

```console
$ head -7 llms.txt
# Beak

> Beak is a low-code, configuration-driven admin-panel framework for Dart and Flutter. Define a model once, get a whole dashboard.

Beak is a configuration-driven admin framework for Dart and Flutter. Annotated schema classes generate typed field references such as ProductModel.name, a Shelf REST API with graph commits, migrations and a Flutter panel built from BeakResource screens. Users never write string field references or touch dynamic.

## Start
$ grep '^## ' llms.txt
## Start
## Learn
## Guides
## Serverpod
## Reference
## AI directory
## Optional
```

`Optional` holds the contributing and architecture pages. Skip it unless the task is about Beak itself. `llms-full.txt` repeats the sections as `#` headings and each page keeps its own `#` title under its section.

## Twin URLs

A page's twin is its site address with `index.md` appended. The rule has no exceptions: `docs/<path>.md` is served at `<site>/<path>/index.md`, and a folder's `index.md` at `<site>/<folder>/index.md`.

| Page file | Twin |
| --- | --- |
| `docs/index.md` | `https://simonerich.github.io/beak/index.md` |
| `docs/ai/index.md` | `https://simonerich.github.io/beak/ai/index.md` |
| `docs/ai/setup.md` | `https://simonerich.github.io/beak/ai/setup/index.md` |
| `docs/panel/resources.md` | `https://simonerich.github.io/beak/panel/resources/index.md` |

Links inside a twin are absolute twin URLs, so an agent can follow them without resolving anything. Every page also has its own twin address in `llms.txt`.

## The bundle

`melos run agent-docs` runs `dart run tool/build_agent_docs.dart` and writes `packages/beak_core/doc/agent-docs/`. `beak_core` carries it because it is the one package every project type resolves, a Serverpod workspace included. `beak docs`, `beak prepare` and `beak agents` copy it into the workspace, after checking every file against its sha256.

```text
.dart_tool/beak/docs/
  ai-index.md          the router: this directory's index page
  SUMMARY.md           the nav as a nested list of links
  llms.txt             the site's llms.txt, with relative links
  changelog.md         the repository CHANGELOG.md
  manifest.json        format, version, page count, sha256 per file
  _agents/blocks/      the four AGENTS.md block templates
  index.md, ai/, models/, panel/, forms/, backend/, reference/, ...
                       every published page, at its path under docs/
```

`manifest.json` is the contract for tools (the `files` map is trimmed here; it lists every file with its sha256):

```json
{
  "format": 1,
  "beak": "0.9.0",
  "index": "ai-index.md",
  "pages": 186,
  "files": { "SUMMARY.md": "<sha256>", "ai-index.md": "<sha256>", "...": "..." }
}
```

`beak docs --json` prints the resolved values (paths trimmed to a home directory; `source` is the `beak_core` the project resolved):

```console
$ beak docs --json
{
  "version": "0.9.0",
  "path": "/home/me/acme/.dart_tool/beak/docs",
  "index": "/home/me/acme/.dart_tool/beak/docs/ai-index.md",
  "source": "/home/me/beak/packages/beak_core",
  "pages": 186
}
```

What the conversion does to a page:

| In the source page | In the bundle |
| --- | --- |
| Front matter | Removed. The `description` becomes a `>` line under the `#` title |
| `--8<--` includes | Expanded, as the site build does |
| Admonitions (`!!! note`) | Blockquotes with a bold label |
| Content tabs | Bold labels over the tab bodies |
| `attr_list` and `md_in_html` markup | Removed |
| A link to another page | Kept relative, and it resolves because the bundle mirrors `docs/` |
| A link to a repository file | The GitHub URL of that file at the release tag, `v<version>` |
| A link to `github.com/.../blob/main/...` | The same URL at the release tag |

The output is deterministic: no timestamps, sorted keys. A build that produces a different file than the committed one is a stale bundle, and `melos run check-agent-docs` (`dart run tool/build_agent_docs.dart --check`) fails on it. It also fails when the corrections table in the [AI directory](index.md) names a symbol that does not exist, or a removed one that still does.

Search the bundle by path and text, not by guessing:

```bash
grep -rl "BeakOutboxSchedule" .dart_tool/beak/docs | sort
grep -n "graphOnly" .dart_tool/beak/docs/backend/graph-business-rules.md
sed -n 1,40p .dart_tool/beak/docs/ai-index.md
```

The first command lists the pages that mention a symbol, the second shows the lines, the third reads the router.

## Versioning and stability

| What | Promise | Not promised |
| --- | --- | --- |
| The bundle in `beak_core` X | Documents Beak X. Its `manifest.json` names X, and `beak doctor` warns when the copy in `.dart_tool` is another version | That X's pages have no mistakes. The source wins |
| Bundle format | `format` is `1`. A tool reads `format`, then finds the entry page through the `index` key of `manifest.json` | The same layout under another `format` number |
| A published page address | Never stops working. A moved page keeps its old address through a redirect, and `tool/check_docs.dart` fails when one of the addresses in `docs/_internal/url-manifest.txt` disappears | That the page at an address keeps its content |
| The site | Rebuilt and published on every push to `main` | That it matches your version. Use the bundle |
| The Beak API | Not frozen before 1.0. A change to the query spec, the commit and receipt JSON or the Serverpod tunnel envelope counts as a breaking release | Any deprecation period. Removed APIs are gone |
| `llms.txt` sections | Every page appears once | The section names staying the same |

`docs/` is written for humans first. An agent gets the same words, so the statements about what is missing or open are in the pages too: see [Known traps](rules.md#known-traps).

## Machine-readable twin

This page as Markdown: `https://simonerich.github.io/beak/ai/machine-readable-docs/index.md`. In a project that ran `beak docs`: `.dart_tool/beak/docs/ai/machine-readable-docs.md`.

## Continue reading

- [Set up your agent](setup.md): the command that copies the bundle and writes the block that points at it.
- [Prompt recipes](prompts.md): prompts that send an agent to `ai-index.md` first.
- [Contributing](../contributing/index.md): change the docs and regenerate the bundle.
- [CLI commands](../reference/cli-commands.md#beak-docs): every flag of `beak docs`.
