# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it
reaches `1.0.0`.

Until then, all packages share the pre-release `0.0.x` line and the API may
change without notice.

## [Unreleased]

### Added

- Per-package `README.md`s, workspace `LICENSE` (Apache-2.0), `NOTICE`,
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, and
  `docs/architecture.md`.
- `public_member_api_docs` lint enabled workspace-wide; every public API now
  carries dartdoc, with usage examples on the primary user-facing types.
- `BeakPolicy.canDeleteUpload` — a dedicated authorization hook for upload
  removal, so the file's storage key is no longer passed to `canDelete`'s
  record-id parameter.

### Fixed

- **Eager loading:** nested relation loads that share a head (e.g.
  `items.product` + `items.tax`) no longer clobber each other — the head is
  loaded once and every sibling nested relation is attached to the same records.
- **Backend:** malformed `POST /query` and `/aggregate` spec bodies now return
  `422` instead of an opaque `500`; an explicit `null` primary key on create
  still mints a uuid (and `null` timestamp fields still stamp); CSV export runs
  its first page inside the request so query failures map through the error
  boundary instead of streaming a `200` with a truncated body.
- **Frontend:** the filter bar and in-table column filters now AND-merge instead
  of clobbering; `BeakDecimalColumn` cells honor their precision in the table
  (matching CSV export); a rejected many-to-many detach reverts the optimistic
  selection; concurrent table refetches resolve latest-wins; built-in
  View/Edit row actions navigate without a wasted `getOne`; client-side content
  rules validate submitted whitespace strings exactly as the server does.
- **CLI:** `beak` misuse now prints the usage message and exits `64` instead of
  dumping a stack trace.
- **Storage (FTP):** MKD directory-creation paths share the transfer path's
  rooting, so relative `baseDir`s work on non-chrooted servers.
- **Core:** `BeakJsonColumn`'s contract now matches its behavior — it carries
  its JSON document as text (`valueType` is `String`), with `BeakJson`
  documented as the typed tree you decode that text into.

### Changed

- Extracted the malformed-spec decode-and-map-to-422 logic into a shared
  `readBeakSpec` helper, reused by the query, aggregate, and export handlers.
