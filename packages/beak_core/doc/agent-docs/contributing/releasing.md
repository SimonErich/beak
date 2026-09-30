# Releasing

> Cut a Beak release in order: lockstep versions, changelogs, the obers_ui pin, the docs ratchet, the agent bundle and the git tag.

Beak is not on pub.dev. It ships as a git tag, and `beak create` pins every new project to it. A release is therefore the moment `v<version>` exists on GitHub and everything that mentions the version agrees. This page is the checklist, in the order that works.

Nothing here is automated. No workflow bumps a version, creates a tag or publishes a package, and every package is `publish_to: none`. There has been no tagged release yet, so the list below is derived from what the tools check and what reads the version, not from a previous run. The upside: the whole release is a list you can read in a minute.

## At a glance

| Step | What | Command |
| --- | --- | --- |
| 1 | Branch the release | `git switch -c release/0.9` |
| 2 | Bump the version in every place it lives | see [Versions move together](#versions-move-together) |
| 3 | Replace `Unreleased` in the `## [0.9.0] - Unreleased` heading of `CHANGELOG.md` with the release date, and do the same in the `## 0.9.0 - Unreleased` heading of each package's `CHANGELOG.md` | edit |
| 4 | Pin an obers_ui commit that is pushed and compiles, and drop any local link | `melos run unlink-obers-ui` |
| 5 | Make every docs page `stable` or `preview` | `dart run tool/check_docs.dart --release` |
| 6 | List the newly published pages in the URL manifest | edit `docs/_internal/url-manifest.txt` |
| 7 | Regenerate and check the agent docs bundle | `melos run agent-docs`, then `melos run check-agent-docs` |
| 8 | Check the published skills | `dart run tool/published_skills.dart` |
| 9 | Run the gate, the service suites and the worm suites | see [The gate](index.md#the-gate) |
| 10 | Tag the release commit and push the tag | `git tag -a v0.9.0`, `git push origin v0.9.0` |
| 11 | Scaffold a project from the tag | `beak create demo`, then `flutter pub get` |

## Versions move together

The `beak*` packages share one version. Their changelogs say so: "The `beak_*` packages are versioned in lockstep." The vendored `worm*` packages keep their own `0.1.0` line and are not part of a Beak release.

```bash
grep -H '^version:' packages/beak*/pubspec.yaml
```

```text
packages/beak/pubspec.yaml:version: 0.9.0
packages/beak_backend/pubspec.yaml:version: 0.9.0
packages/beak_cli/pubspec.yaml:version: 0.9.0
packages/beak_core/pubspec.yaml:version: 0.9.0
...
```

Thirteen files print a line, all of them equal. The pubspecs are not the only place, because the version is also a constant in code:

| Where | What to change | Guarded by |
| --- | --- | --- |
| `packages/beak*/pubspec.yaml`, thirteen files | `version:` | nothing; compare them with the command above |
| `packages/beak_core/lib/beak_core.dart`, `beak_backend.dart`, `beak_frontend.dart`, `beak_image.dart`, `beak_storage_s3.dart`, `beak_storage_ftp.dart` | `beak<Package>Version` | a smoke test, except `beak_image` |
| `packages/beak_cli/lib/src/version.dart` | `beakCliVersion`, which also sets the tag `beakReleaseRef` | `version_test.dart`, which compares it with the pubspec |
| `test/smoke_test.dart` in `beak_core`, `beak_backend`, `beak_frontend`, `beak_storage_s3`, `beak_storage_ftp` | the literal the constant is compared with | they fail until it matches |

Do not run a blanket search and replace on `0.9.0`. The CLI's agent tests spell it as fixture data, and doc comments use it as an example.

## The tag is the release

`beak create` writes a git dependency on this repository, pinned to `v` plus `beakCliVersion`:

```yaml
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak
```

Until that tag exists on GitHub, a freshly created project cannot resolve. This is what `flutter pub get` says today, because the remote has no tags:

```text
Because demo2 depends on beak from git which doesn't exist (Could not find git ref 'v0.9.0' ...), version solving failed.
```

The agent docs bundle depends on the tag too. It rewrites every link to a file outside `docs/` so that it points at `blob/v<version>` or `tree/v<version>` on GitHub, and takes the version from `packages/beak_core/pubspec.yaml`.

Tag the commit that carries the bump, the regenerated bundle and the changelog, and push the tag:

```bash
git tag -a v0.9.0 -m "Beak 0.9.0"
git push origin v0.9.0
```

You can rehearse before the tag exists. `--beak-path` depends on a local checkout, and `--beak-ref` on any branch or commit that is on GitHub. Create the project in a scratch directory, not in the repo:

```bash
BEAK="$PWD"
cd "$(mktemp -d)"
dart run "$BEAK/packages/beak_cli/bin/beak.dart" create demo --beak-path "$BEAK"
dart run "$BEAK/packages/beak_cli/bin/beak.dart" create demo2 --beak-ref release/0.9
```

## The obers_ui pin

Users get obers_ui from the commit the pubspecs pin, so the release must pin one that GitHub can serve. Before you tag:

- Check the three refs in `packages/beak_frontend/pubspec.yaml` and the three in `packages/beak/pubspec.yaml` name the same commit. `test/obers_ui_pin_test.dart` fails the tree if they diverge.
- Check that commit is pushed to the obers_ui repository. A SHA that exists only in your local checkout resolves for nobody else.
- Check that commit is new enough for `beak_frontend` to compile. A pin that resolves but lacks APIs the panel calls passes `pub get` and fails every panel build, so a release cut on it hands users a project that does not compile. `CHANGELOG.md` records whether the current pin has this gap, and the comment at the top of `.github/workflows/ci.yaml` lists the CI jobs that stay red until it is fixed: `static`, `test`, `web`, `showcase-web`, `foodio-web` and `serverpod-admin`. Move the SHA in every pubspec that pins it, and let `test/obers_ui_pin_test.dart` confirm the copies match.
- Run `melos run unlink-obers-ui`, which unlinks and then bootstraps. The lockfiles of the examples are tracked, and `pub get` writes whatever it resolved into them. A lockfile that records a path into a sibling checkout does not belong in the release commit, and `git grep -ln 'path: "../../../obers_ui' -- '*pubspec.lock'` prints nothing when none does.

[Working with obers_ui](working-with-obers-ui.md) covers the pin and the link tool.

## Docs at release time

Day to day, a `draft` page is allowed on `main`. A release is where that stops:

```bash
dart run tool/check_docs.dart --release
```

It fails while any page is `draft`, and the docs workflow runs it on every `release/**` branch and every `v*` tag. Set finished pages to `stable`, and pages for something not shipped to `preview`.

`docs/_internal/url-manifest.txt` lists every path the site has ever served, so a moved page can never break a bookmark. Add a line for every page the release publishes for the first time, and never remove one. This lists the pages that are not in the manifest yet:

```bash
cd docs
find . -name '*.md' -not -path './_internal/*' -not -path './_agents/*' | sed 's#^\./##' | LC_ALL=C sort > /tmp/pages.txt
grep -v '^#' _internal/url-manifest.txt | LC_ALL=C sort > /tmp/listed.txt
LC_ALL=C comm -23 /tmp/pages.txt /tmp/listed.txt
```

Then regenerate the agent docs bundle. It copies `docs/`, the changelog and the version into `packages/beak_core/doc/agent-docs`, so run it after every edit above, and commit the result:

```bash
melos run agent-docs
melos run check-agent-docs
```

The check builds in memory and fails on any difference from disk. It also verifies the corrections table on the AI directory page. The column heading comes from the `beak_core` version (`Beak 0.9 does` for any 0.9.x), and a page without that table fails, so a bump to 0.10 fails until the heading reads `Beak 0.10 does`; the message names the words to write. Every backticked symbol in the column must appear in some `packages/*/lib`. Every symbol in a row marked `(removed)` must be declared in no Beak package: a doc comment, a message string, a local variable, a private helper or a vendored `worm*` package that happens to use the word does not keep it alive.

## Skills

The workflows that ship inside packages live in `packages/beak/skills`, `packages/beak_frontend/skills` and `packages/beak_serverpod/skills`. The check enforces the naming, size and link rules, and that every `beak` command a skill names is registered:

```bash
dart run tool/published_skills.dart
```

```text
Published skills check passed.
```

## Rules and limits

- Nothing verifies lockstep. A package left on the old version passes every check except your eyes. Run the `grep` above after the bump.
- A stale bundle fails `analyze`. `check-agent-docs` is part of `melos run analyze` and of the docs workflow, so a bump, a `CHANGELOG.md` edit or a docs change turns both red until `melos run agent-docs` has regenerated the bundle and you have committed it.
- The pre-1.0 promise. The package changelogs say the API is not frozen and the wire format is. Breaking an API is allowed, and it goes in `CHANGELOG.md` under the release. Changing the wire format is not.
- The root changelog names the version in prose too. Its opening notes say the packages share `0.9.0` and that nothing is tagged yet. Update both sentences when you tag.
- Every package has a changelog. All thirteen `packages/beak*/CHANGELOG.md` files point back to the root one, so step 3 touches fourteen files.
- No pub.dev. Every package is `publish_to: none`, so there is no publish step, dry run or score to check.

## Verify it

Every version agrees, and the CLI reports the same one the tag will name:

```bash
grep -H '^version:' packages/beak*/pubspec.yaml
dart run packages/beak_cli/bin/beak.dart --version
```

```text
beak 0.9.0
```

The docs are complete, the bundle is current and the skills pass:

```bash
dart run tool/check_docs.dart --release
dart run tool/build_agent_docs.dart --check
dart run tool/published_skills.dart
```

After the push, the remote answers for the tag. An empty answer means it is not there yet:

```bash
git ls-remote --tags origin v0.9.0
```

Last, prove a stranger's first minute works. From a scratch directory, create a project with no flags, so it pins the default tag, and resolve it:

```bash
cd "$(mktemp -d)"
dart run "$BEAK/packages/beak_cli/bin/beak.dart" create demo
cd demo
flutter pub get
```

`flutter pub get` ends without a version-solving error once the tag is on GitHub.

## Reference

| Thing | Where |
| --- | --- |
| Package versions | `packages/beak*/pubspec.yaml` |
| Version constants | `packages/beak_core/lib/beak_core.dart` and the six siblings named above |
| The tag a scaffold pins | `beakReleaseRef` in `packages/beak_cli/lib/src/version.dart` |
| Release notes | `CHANGELOG.md` at the root, one `CHANGELOG.md` per package |
| The obers_ui pin test | `test/obers_ui_pin_test.dart` |
| The docs ratchet | `tool/check_docs.dart --release`, `melos run check-docs-release` |
| The URL manifest | `docs/_internal/url-manifest.txt` |
| The agent bundle | `packages/beak_core/doc/agent-docs`, built by `tool/build_agent_docs.dart` |
| Published skills | `packages/*/skills`, checked by `tool/published_skills.dart` |
| Release-branch CI | `.github/workflows/docs.yml`, which adds the ratchet on `release/**` |

## Continue reading

- [Working with obers_ui](working-with-obers-ui.md) the pin and the local link.
- [Writing docs](writing-docs.md) the page types the ratchet counts.
- [Upgrading](../start-here/upgrading.md) what users read when a release breaks something.
- [Machine-readable docs](../ai/machine-readable-docs.md) what the bundle gives agents.
