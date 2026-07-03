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
| 03 | beak_core: model + relationships | ✅ DONE | 097204c | Full gate green 2026-07-02 23:26 UTC. `abstract base` `BeakModel` (metadata only: table, displayColumnKey, columns, relationships, softDeletes, default `primaryKey` = first `'id'` column else `BeakConfigurationException`); sealed `BeakRelationship` (BelongsTo/HasOne/HasMany/BelongsToMany as part-files) reusing `BeakRenderConfig` — cardinality `one` → uniform `relationLink` intent, `many` → uniform `relationBadges` (form nuances like single/multi-select are the frontend's per-type mapping; intent enum unchanged from Phase 01). `BeakOnDelete` mirrors worm `OnDelete` 1:1 (mapping pinned by exhaustive test, no worm import). `BeakModelRegistry` throws `BeakConfigurationException` on duplicate table + unknown `byTableOrThrow`; `all` unmodifiable, registration order. Defaults: HasMany onDelete=restrict, BelongsToMany onDelete=cascade (pivot rows are join data). beak_core 100% coverage (313/313). |
| 04 | beak_core: serializable query spec | ✅ DONE | 22cb8cc | Full gate green 2026-07-03 05:54 UTC. Sealed `BeakValue` (7 variants): primitives serialize raw, DateTime as tagged `{"type":"dateTime","value":<ISO-8601>}` (only map-shaped value — keeps strings/timestamps unambiguous and leaves the tag namespace open); `BeakValue.of` passes existing BeakValues through. Sealed `BeakFilter` (field/and/or; field's default ctor takes a `BeakColumn`, `.forKey` is the deserialization path). `BeakSort`/`BeakPagination` (asserts page/perPage ≥ 1)/`BeakRelationLoad`/`BeakSearch`/`BeakQuerySpec` with immutable copy-builders — `withFilter` AND-merges flat (appends to an existing `BeakAndFilter` instead of nesting); `paginate({int? page, int? perPage})` keeps the omitted half. `BeakPage<T>` round-trips via caller-supplied item (de)serializers. All `fromJson` are strict (every key required; toJson always writes all keys) via shared internal `json_support.dart` helpers throwing `BeakConfigurationException`. Golden `test/golden/rich_query_spec.json` pinned structurally AND byte-exact (JsonEncoder.withIndent('  ') + trailing newline). beak_core 100% coverage (678/678). |
| 05 | beak_core: storage abstraction + file rules | ✅ DONE | edab92e | Full gate green 2026-07-03 06:27 UTC. Phase-02 stubs moved from columns/file_support.dart into the target layout (storage/file_rules + storage/transforms) and finalized: `BeakResizeTransform` gained `fit` (new `BeakImageFit`, default contain), `BeakWebpTransform` generalized to `BeakFormatTransform(format, quality)` (new `BeakImageFormat` with `fileType` mapping; `.webp()` factory kept via named ctor), `BeakThumbnailTransform` gained `name` (default 'thumbnail'); all transforms got ==/hashCode + strict tagged JSON. Sealed `BeakStorageConfig` (memory/local/s3/ftp as part-files); S3 `toString` redacts accessKey+secretKey, FTP redacts password. `BeakStorageRegistry()` pre-registers memory+local; drivers expose registry-compatible `fromConfig` factories (pattern-matched, mismatch throws — keeps the throw branch publicly testable). `BeakStorageKeys.join/validate` rejects traversal/absolute/backslash keys; both drivers validate every key. Local-disk publicBaseUrl is required non-null (url() depends on it). `BeakUploadValidator` aggregates errors under keys size/type/dimensions/aspectRatio; ±0.01 aspect tolerance; dimension rules without decoded dims → 'could not be determined'. `BeakTransformRunner`+`BeakTransformedImage` interface only (impl Phase 06). json_support.dart moved query/→common/ (+requireJsonIntOrNull/requireJsonMap). beak_core 100% coverage (925/925). |
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
