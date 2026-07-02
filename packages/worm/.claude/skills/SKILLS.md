# Claude Skills Catalog

This repository keeps Claude-oriented skills under `.claude/skills/`.

For any agent that supports project instructions, treat the following files as
authoritative in this order:

1. `CLAUDE.md`
2. `.claude/skills/SKILLS.md`
3. The specific `SKILL.md` files relevant to the task
4. `.claude/agents/*.md`
5. `.claude/rules/**/*.md`

## Routing Rules

1. Start with `CLAUDE.md` for non-negotiable repo rules.
2. Pick the closest matching skill before making changes.
3. Read companion skills when the chosen skill points to related concerns.
4. Prefer existing patterns and existing abstractions.
5. When finishing behavior changes, validate with formatting, analysis, and tests.

## Available Skill Groups

### Core

- `code-quality`
- `fix-all-issues`
- `tdd-setup`
- `tdd-workflow`

### Dart

- `add-custom-lint`
- `cleanup-dart-codebase`
- `declarative-api`
- `flutter-dart-official-rules`
- `flutter-dart-refactor`
- `init-marqably-dart-qa-rules`

### Patterns And Rules

- `patterns-and-rules/create-reusable-helpers`
- `patterns-and-rules/error-handling`
- `patterns-and-rules/project-patterns`
- `patterns-and-rules/typed-exceptions`

### QA

- `qa-checks`
- `qa-core`
- `qa-requirements-audit`
- `qa-review`
- `qa-run-checks`
- `verify-implementation`

### Configuration

- `project-configuration`

## Agent Definitions

Sub-agent definitions live under `.claude/agents/`:

- `default.md`
- `qa-agent.md`
- `tdd-planning-agent.md`
