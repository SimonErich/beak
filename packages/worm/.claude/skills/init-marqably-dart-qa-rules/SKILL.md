---
name: init-marqably-dart-qa-rules
description: Initialize marqably clean code QA rules in a target project. Auto-detects project type (Flutter, Dart CLI, Serverpod monorepo), configures lint dependency, copies skills, and merges CLAUDE.md interactively. Re-runnable with diff detection.
role: manual_execution
scope: general
trigger: direct_match
pairs_with:
  - cleanup-dart-codebase
  - add-custom-lint
  - qa-core
---

# Initialize Marqably Dart QA Rules

Sets up the complete marqably clean-code stack in a target project: lint rules via pub dependency, strict analysis options, 65 Claude skills, and CLAUDE.md coding standards.

## When to Use

- A new or existing Flutter, Dart, or Serverpod project needs the marqably QA setup.
- The user has added `marqably_dart_qa_rules` as a dev dependency and run `dart run marqably_dart_qa_rules:init`.
- The user wants to update an existing setup after pulling new package changes.

## When NOT to Use

| Need | Use instead |
|------|-------------|
| Audit an already-configured codebase | `cleanup-dart-codebase` |
| Add a single custom lint rule | `add-custom-lint` |
| Quick static check | `code-quality` |

---

## Prerequisites

The `marqably_dart_qa_rules` package must be installed as a dev dependency. Verify:

```bash
grep -l marqably_dart_qa_rules .dart_tool/package_config.json
```

If not found, tell the user to add the dependency first:

```bash
dart pub add --dev marqably_dart_qa_rules \
  --git-url=git@git.duko.at:flutter/dart-flutter-qa-rules.git
dart run marqably_dart_qa_rules:init
```

## How Lints Work as a Pub Dependency

The `marqably_dart_qa_rules` package IS the lint plugin. It uses Dart's first-party `analysis_server_plugin` and runs natively through `dart analyze` and your IDE — no separate `dart run custom_lint` step needed. There is **no need to copy lint source files** into the target project. The target project just needs:

1. `marqably_dart_qa_rules` as a dev dependency (provides the lint rules)
2. `very_good_analysis` as a dev dependency (base analysis options)
3. A top-level `plugins:` section in `analysis_options.yaml` (not nested under `analyzer:`)

The lint rules run directly from the pub cache / git dependency path.

---

## Phase 0: Pre-flight & Re-run Detection

1. Resolve the `marqably_dart_qa_rules` package location from `.dart_tool/package_config.json`. Set `BOILERPLATE_DIR` to the resolved path.

   ```bash
   python3 -c "
   import json, sys
   cfg = json.load(open('.dart_tool/package_config.json'))
   pkg = next(p for p in cfg['packages'] if p['name'] == 'marqably_dart_qa_rules')
   print(pkg['rootUri'])
   "
   ```

   If the package is not found, stop and tell the user to add the dependency:
   ```bash
   dart pub add --dev marqably_dart_qa_rules \
     --git-url=git@git.duko.at:flutter/dart-flutter-qa-rules.git
   dart run marqably_dart_qa_rules:init
   ```

2. Check for marker file `.marqably_qa_config.json` at the project root.
3. **If marker exists** (re-run):
   - Load the config and display the current setup to the user.
   - Ask: "Re-run detected. What would you like to do?"
     - (a) **Update rules** — re-copy skills from latest boilerplate, keep existing folder config
     - (b) **Re-detect and reconfigure** — re-scan folder structure, re-adapt rules
     - (c) **Full re-init** — start from scratch
   - Option (a): skip to Phase 4 using stored config values.
   - Option (b): run Phases 1-3, then Phase 4+.
   - Option (c): full flow.
4. **If no marker** (first run): proceed to Phase 1.

---

## Phase 1: Project Type Detection

Determine the target project type automatically.

### Detection Algorithm

1. **Serverpod monorepo**: look for directories matching `*_server/`, `*_client/`, `*_flutter/` at the project root. Confirm by checking if `*_server/pubspec.yaml` contains `serverpod` as a dependency.
2. **Flutter app**: root `pubspec.yaml` has a `flutter` SDK dependency (`flutter: sdk: flutter`).
3. **Dart CLI/package**: none of the above.

### Output

Announce:
```
Project type detected: [Flutter | Dart CLI/package | Serverpod monorepo]
Project name: <name from pubspec.yaml>
Packages to configure: [list of packages]
```

Store:
- `project_type`: `"flutter"` | `"dart"` | `"serverpod_monorepo"`
- `project_name`: from pubspec.yaml `name` field
- `packages`: list of packages that need analysis_options.yaml and dev dependencies

---

## Phase 2: Folder Structure Detection

Scan the target project's `lib/` directory to detect actual folder names. This determines how the analysis_options and skill documentation are adapted.

### Detection Table

For each variable, check these paths in order. Use the first match.

| Variable | Check (in order) | Default |
|----------|-----------------|---------|
| `features_folder` | `lib/features/`, `lib/modules/`, `lib/screens/`, `lib/pages/` | `features` |
| `core_folder` | `lib/core/`, `lib/shared/`, `lib/common/` | `core` |
| `uikit_folder` | `lib/uikit/`, `lib/ui_kit/`, `lib/design_system/`, `lib/theme/` | `uikit` |
| `routing_folder` | `lib/routing/`, `lib/navigation/`, `lib/router/`, `lib/core/routing/`, `lib/core/navigation/` | `navigation` |

### Layer Detection

Look inside a detected feature folder for subdirectories:
- Standard: `presentation/`, `domain/`, `data/`
- Alternative: `view/` or `ui/`, `model/`, `repository/`

If non-standard layers are found, ask the user to map them:
> "Your feature layers appear to be: X, Y, Z. Please map them to: presentation, domain, data."

Store as `layer_mapping`: e.g., `{"presentation": "ui", "domain": "model", "data": "repository"}`

### Confirm with User

Show detected structure and ask for confirmation:
```
Detected folder structure:
  Features: lib/<features_folder>/
  Core:     lib/<core_folder>/
  UIKit:    lib/<uikit_folder>/
  Routing:  lib/<routing_folder>/
  Layers:   <presentation> / <domain> / <data>

Is this correct? (y/n)
```

If any folder was not found, inform the user which defaults will be used.

---

## Phase 3: UI Library Detection

1. Search all `pubspec.yaml` files for UI library dependencies.
2. Check for known packages: `obers_ui`, `shadcn_flutter`, `fluent_ui`, `macos_ui`, etc.
3. **If `obers_ui` found**: keep rules as-is. Set `ui_library = "obers_ui"`.
4. **If different UI library found**: confirm with user, set `ui_library` to that package name.
5. **If no UI library found**: ask the user:
   > "No UI component library detected. Options: (a) Provide package name to enforce, (b) Disable UI library rules (set `ui_library = "none"`)."

---

## Phase 4: Configure Dependencies

The lint rules live inside `marqably_dart_qa_rules` which is already a dev dependency. Add the remaining required dev dependencies.

### 4A: Add Dev Dependencies

For each package in `packages`, ensure its `pubspec.yaml` has under `dev_dependencies`:

```yaml
dev_dependencies:
  very_good_analysis: ^10.0.0
  marqably_dart_qa_rules:
    git:
      url: git@git.duko.at:flutter/dart-flutter-qa-rules.git
```

The `marqably_dart_qa_rules` entry should already exist (prerequisite). If not, add it. Also ensure `very_good_analysis` is present.

If these dependencies already exist, update them. Do not duplicate.

For Serverpod monorepo: add to each sub-package that needs linting (`*_flutter/`, `*_server/`, `*_client/`, `*_shared/`).

### 4B: Copy Analysis Options

For each package:
- **Flutter packages**: copy content of `$BOILERPLATE_DIR/flutter_analysis_options.yaml` to `<package>/analysis_options.yaml`
- **Dart/server packages**: copy content of `$BOILERPLATE_DIR/dart_analysis_options.yaml` to `<package>/analysis_options.yaml`
- **Serverpod monorepo**:
  - `*_flutter/` gets Flutter variant
  - `*_server/`, `*_client/`, `*_shared/` get Dart variant

**If `analysis_options.yaml` already exists**, ask:
> "analysis_options.yaml already exists in `<package>`. Options: (a) Replace with marqably version, (b) Merge (add missing settings), (c) Skip"

### 4C: Run pub get

```bash
cd <each_package> && dart pub get  # or flutter pub get for Flutter packages
```

---

## Phase 5: Skills, CLAUDE.md & Config

### 5A: Copy Skills

1. Copy all skill directories from `$BOILERPLATE_DIR/.claude/skills/` to `<project_root>/.claude/skills/`.
2. Copy `SKILLS.md` from the boilerplate.
3. Copy `$BOILERPLATE_DIR/.claude/agents/` to `<project_root>/.claude/agents/`.
4. **On re-run**: do NOT overwrite existing skills that have the same directory name. Only add new ones. For `SKILLS.md`, always update.

### 5B: Filter Skills by Project Type

After copying, remove skills that don't apply:

| Project Type | Delete these skill directories |
|-------------|-------------------------------|
| Dart-only | All `flutter-*`, `serverpod-*`, `patrol-*`, `create-visual-ui/`, `uikit/`, `refactor-provider/`, `getit-dependency-injection/`, `getting-started/`, `docker-services/`, `migrate-database/`, `seed-database/`, `run-server/` |
| Flutter-only | All `serverpod-*`, `getting-started/`, `docker-services/`, `migrate-database/`, `seed-database/`, `run-server/` |
| Serverpod monorepo | Keep everything |

### 5C: Interactive CLAUDE.md Merge

**If no existing CLAUDE.md** at project root:
- Copy `$BOILERPLATE_DIR/CLAUDE.md` to the project root.
- Tell the user: "CLAUDE.md created. Please customize the 'Project Overview' section for your project."

**If CLAUDE.md already exists**:
- Parse both files into sections (split by `## ` headings).
- For each section in the boilerplate CLAUDE.md:
  - **Same heading, different content**: show the diff to the user. Ask: "Keep yours / Use boilerplate / Skip (merge manually later)"
  - **Only in boilerplate**: ask "Section '## X' is new. Add it?"
  - **Only in target**: always keep (never remove user content).
- Priority sections that should always be offered for merge:
  - `## Non-Negotiable Rules`
  - `## Core Architecture`
  - `## Use Skills For Details`
  - `## MCP Servers`

### 5D: .mcp.json

- **If no existing `.mcp.json`**: copy from boilerplate.
- **If exists**: merge -- add any MCP server entries from the boilerplate that are missing in the target. Keep existing entries. Ask before overwriting any server with the same key.

---

## Phase 6: Verification & Marker

### 6A: Verify

Run these checks and report results:

```bash
# 1. Each target package resolves deps
cd <package> && dart pub get  # or flutter pub get

# 2. Analysis is clean (analysis_server_plugin will load marqably_dart_qa_rules rules)
cd <package> && dart analyze
```

### 6B: Write Marker File

Write `.marqably_qa_config.json` at the project root:

```json
{
  "version": "1.0.0",
  "initialized_at": "<ISO 8601 timestamp>",
  "project_type": "<detected type>",
  "project_name": "<name>",
  "features_folder": "<detected value>",
  "core_folder": "<detected value>",
  "uikit_folder": "<detected value>",
  "routing_folder": "<detected value>",
  "layer_mapping": {
    "presentation": "<detected value>",
    "domain": "<detected value>",
    "data": "<detected value>"
  },
  "ui_library": "<detected value>",
  "packages_configured": ["<list of package names>"]
}
```

### 6C: Final Report

```
## Marqably QA Rules -- Initialization Complete

Project: <project_name> (<project_type>)
Packages configured: <list>

Lint rules: loaded from marqably_dart_qa_rules (pub dependency)
  Core: 9, Flutter: 18, Serverpod: 9
Skills installed: <count>
Analysis options: <list of packages>

Folder mapping:
  features -> <features_folder>
  core -> <core_folder>
  uikit -> <uikit_folder>
  routing -> <routing_folder>
  layers -> <presentation>/<domain>/<data>
  UI library -> <ui_library>

Verification:
  dart pub get: [pass/fail]
  dart analyze: [pass/fail]

Next steps:
  - [ ] Customize the 'Project Overview' section in CLAUDE.md
  - [ ] Review .mcp.json and set any required API keys
  - [ ] Run `dart analyze` to see current lint violations
  - [ ] Consider running /cleanup-dart-codebase for a full compliance audit
```

---

## Checklist

- [ ] Package location resolved from `.dart_tool/package_config.json`
- [ ] Project type detected and announced
- [ ] Folder structure detected and confirmed with user
- [ ] UI library detected or user-specified
- [ ] Dev dependencies added to all target packages (`very_good_analysis`, `marqably_dart_qa_rules`)
- [ ] Analysis options copied/merged for all packages
- [ ] `dart pub get` succeeds in all packages
- [ ] Skills copied and filtered by project type
- [ ] CLAUDE.md merged interactively
- [ ] .mcp.json merged
- [ ] Marker file `.marqably_qa_config.json` written
- [ ] Final report shown to user
