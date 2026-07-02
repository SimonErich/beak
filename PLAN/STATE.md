# PLAN/STATE.md — Beak build ledger

This is the single source of truth for build progress. The loop reads it to find the
next phase, and updates it after finishing one. Status legend:

- `⬜ TODO` — not started
- `🔶 IN-PROGRESS` — started this phase; see the "resume" note
- `✅ DONE` — gate fully green, committed (SHA recorded)

**Do the first phase that is not `✅ DONE`.** When all are `✅ DONE`, run the full gate
once more and, if green, create the `BUILD_COMPLETE` sentinel and stop.

| # | Phase | Status | Commit | Notes |
|---|-------|--------|--------|-------|
| 00 | Foundation & guardrails | ✅ DONE | d2f4d96 | Full gate green 2026-07-02 22:43 UTC. Melos pinned to 6.3.3 (last melos.yaml-based line; 7+ moved config into pubspec). Vendored worm* excluded from melos scope (consumed as path deps; their mysql/mongo suites need unprovisioned services). obers_ui present, all path deps resolve. Docker host ports remapped to 25432/29000/29001/28081 (defaults occupied on this host); createbuckets one-shot profiled so `--wait` stays green. Vendored drop had an embedded git repo at packages/.git (worm dev history, no remotes) — preserved as packages/.worm-repo.git (gitignored) so beak can track the files. |
| 01 | beak_core: types, enums, errors | ✅ DONE | 4367f33 | Full gate green 2026-07-02 22:54 UTC. BeakContext/BeakRenderIntent/BeakColor/BeakOperator enums, sealed BeakException (6 subclasses) and BeakResult<T> landed, 100% coverage enforced (threshold raised in tool/check_coverage.dart + root test updated). Note: phase text says "18" operators but its own contract enumerates 17 — implemented the contract's list; exhaustive-switch tests break the build if a value is added unhandled. Substring ops (contains/startsWith/endsWith) documented as worm `Operator.ilike` + wildcard pattern. |
| 02 | beak_core: column system + rules | ✅ DONE | 22f57af | Full gate green 2026-07-02 23:16 UTC. Sealed `BeakColumn` (13 variants) + sealed `BeakRule` (11 rules) as part-files (sealed requires same library); `BeakRenderConfig` maps context→intent; `BeakFileType`/`BeakDimensions`/`BeakImageTransform` forward-declared in columns/file_support.dart for Phase 05; sealed `BeakJson` tree with deep equality + encode/decode. beak_core 100% coverage (273/273). Registry tests pin exhaustive switches over both sealed families. Decisions: decimal→currency intent iff prefix/suffix set; relative dates only in table/detail (form/filter stay date pickers); image filter intent = custom; enum badgeColors default `const <Never, BeakColor>{}` (const default can't use type param). |
| 03 | beak_core: model + relationships | ⬜ TODO | — | — |
| 04 | beak_core: serializable query spec | ⬜ TODO | — | — |
| 05 | beak_core: storage abstraction + file rules | ⬜ TODO | — | — |
| 06 | beak_storage_s3 + beak_storage_ftp | ⬜ TODO | — | — |
| 07 | beak_backend: Shelf foundation + DataSource | ⬜ TODO | — | — |
| 08 | beak_backend: auto CRUD endpoints | ⬜ TODO | — | — |
| 09 | beak_backend: file upload endpoints | ⬜ TODO | — | — |
| 10 | beak_backend: auth + search + export | ⬜ TODO | — | — |
| 11 | beak_frontend: panel foundation + client | ⬜ TODO | — | — |
| 12 | beak_frontend: BeakDataTable | ⬜ TODO | — | — |
| 13 | beak_frontend: BeakDataForm + DetailView | ⬜ TODO | — | — |
| 14 | beak_frontend: actions + filters + dashboard | ⬜ TODO | — | — |
| 15 | reference app + beak_cli + E2E | ⬜ TODO | — | — |

## Resume notes

<!-- The loop appends per-phase running notes here when a phase is IN-PROGRESS, so a
     fresh invocation can continue exactly where the previous one stopped. Format:

### Phase NN — IN-PROGRESS (updated <UTC timestamp>)
- done: <what's finished + which tests pass>
- next: <the exact next step to resume>
-->
