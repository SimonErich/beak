# Beak Build Kit

An autonomous, test-driven build system that turns an empty folder into the **Beak**
framework — a low-code, configuration-driven admin-panel framework for Dart/Flutter
(FilamentPHP × Shadcn Admin Kit, built on `worm` + `obers_ui`) — plus a working reference
admin app, running against Postgres + MinIO.

You hand this kit to **Claude Code** and it builds the whole thing across 16 phases,
**one phase per invocation, unattended**, surviving timeouts and rate limits, never asking
you to click continue.

---

## What's in here

```
run_beak_build.sh     # the autonomous loop harness (re-invokes Claude Code until done)
PROMPT.md             # the engineered loop prompt (one phase per invocation)
CLAUDE.md             # persistent guardrails: rules, repo map, the gate, conventions
.claude/skills/       # worm-usage, obers-ui-usage, beak-conventions, tdd-loop
PLAN/
  STATE.md            # the progress ledger (the loop reads + updates this)
  PHASES.md           # dependency graph + overview of all phases
  phase-00.md … 15.md # one self-contained, test-first build phase each
```

The 16 phases (bottom-up):

| # | Phase |
|---|-------|
| 00 | Monorepo foundation, Docker (Postgres+MinIO), strict lints, CI, skeletons |
| 01–05 | `beak_core` — types → columns+rules → model+relations → query spec → storage abstraction |
| 06 | `beak_storage_s3` + `beak_storage_ftp` + image transforms |
| 07–10 | `beak_backend` — Shelf + DataSource → CRUD → uploads → auth/search/export |
| 11–14 | `beak_frontend` — panel+client → table → form+detail → actions/dashboard/pages |
| 15 | Reference app + `beak_cli` + full end-to-end acceptance → `BUILD_COMPLETE` |

Every phase ends at a **green gate**: `analyze` (0 issues) · `test` (all pass) ·
`coverage` (≥85%, 100% for `beak_core`) · `format-check` · phase-specific proofs.

---

## Prerequisites (before you launch)

1. **Claude Code** installed, authenticated, on `PATH`. Confirm the headless flags for
   your version once: `claude --help` (the harness uses `--print --permission-mode
   bypassPermissions --model …`; older/newer builds may use `--dangerously-skip-permissions`
   — adjust `CLAUDE_FLAGS` in `run_beak_build.sh` if needed).
2. **`./packages/worm`** — vendor the `worm` packages (`worm`, `worm_postgres`,
   `worm_generator`, `worm_lints`) under `packages/worm/*` in the target repo.
3. **`~/Flutters/obers_ui`** — the `obers_ui` monorepo (with `obers_ui_autoforms`,
   `obers_ui_charts`) at that path; docs at `~/Flutters/obers_ui/doc`.
4. **Toolchain:** Dart `^3.11`, Flutter stable, `docker` + `docker compose`, and Melos
   (`dart pub global activate melos`).

## Launch

```bash
# 1. Create an empty project folder and drop this kit's contents into it:
mkdir beak && cd beak
cp -R /path/to/beak-build-kit/. .

# 2. Make sure ./packages/worm exists and ~/Flutters/obers_ui exists (see prerequisites).

# 3. Go:
chmod +x run_beak_build.sh
./run_beak_build.sh            # unattended; runs to completion
#   TAIL=1 ./run_beak_build.sh # also stream Claude's output to your terminal
```

The harness loops: each invocation Claude reads `PLAN/STATE.md`, does the next unfinished
phase test-first, runs the gate, marks it done, commits, and exits; the harness relaunches
it for the next phase. It stops when `BUILD_COMPLETE` appears.

### Tunables (env vars)

| Var | Default | Meaning |
|-----|---------|---------|
| `BEAK_MODEL` | `claude-opus-4-8` | model id passed to `claude --model` |
| `BEAK_SLEEP` | `90` | seconds to wait between invocations / on retry (rate-limit cushion) |
| `BEAK_MAX_INVOCATIONS` | `500` | hard cap on total invocations |
| `BEAK_STALL_LIMIT` | `6` | if `STATE.md` doesn't advance this many times in a row, write `NEEDS_HUMAN.md` and stop |

## Monitoring & control

- **Progress:** `cat PLAN/STATE.md` (the ledger) and `git log --oneline` (one commit/phase).
- **Live logs:** `tail -f build.log`.
- **Pause:** Ctrl-C the harness. **Resume:** re-run `./run_beak_build.sh` — it continues
  from the ledger + git state (each phase is resumable).
- **If it stops early:** look for `NEEDS_HUMAN.md` (a genuine external blocker, e.g. a
  missing dependency or Docker down) — fix it and re-launch.

## How autonomy + resilience work

- **Context hygiene:** each invocation loads only the current phase file, not all 16.
- **Timeout-proof:** invocations are short and bounded; if one dies mid-phase, the next
  resumes from git + `STATE.md` "resume" notes.
- **Rate-limit-proof:** any non-completing exit → sleep `BEAK_SLEEP`s → retry, forever
  (up to the cap), with no human input.
- **Honest builds:** the loop is forbidden from weakening tests, skipping, or faking green;
  a phase isn't "done" until its full gate passes.

## After it finishes

`BUILD_COMPLETE` exists and every `PLAN/STATE.md` row is `✅ DONE`. You now have the Beak
framework packages, the two storage drivers, the CLI, and a reference admin app that boots
against Postgres + MinIO with working CRUD, validated file uploads + image transforms,
relationships, search, and CSV export — all Material-free, fully type-safe, and test-driven.

See the generated `README.md` at the repo root for how to define your own resources and
configure storage drivers, and note the `beak_serverpod` seam (a future package that lets
you reuse generated Serverpod classes as Beak models without duplication).
