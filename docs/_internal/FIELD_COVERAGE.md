# Field system coverage map

This map records supported contracts and the regression suites that exercise them.
It is deliberately organized by behavior, not a claim that every imaginable
industry-specific input is built in.

| Family | Generated/default/null | Editor and parsing | Shared validation | Persistence / query | Display / export |
| --- | --- | --- | --- | --- | --- |
| Text, email, URL, phone, slug, UUID | Typed String; scalar defaults; nullable stays null | Model-selected text keyboard/preset | Syntax, required, max length | Canonical String; typed equality/search | Semantic formatter; locale policy |
| Password | Secret form field; unsafe display/search rejected | Obscured input | Declared length/pattern rules | String; host auth owns hashing | Masked, including raw CSV mode |
| Integer/decimal | Existing numeric types and defaults | Strict locale parser; incomplete text remains an error | Finite, min/max, precision | Numeric storage and range queries | Grouping and explicit precision |
| Exact decimal/money | `BeakDecimal`, explicit scale and currency member | Exact locale parsing without float conversion | Scale and portable exact-integer bounds | Integer units; typed comparisons compile to units | Exact major-unit text, fixed/per-record currency; explicit raw units |
| Percent/quantity/file size | Explicit percentage scale and unit metadata | Percent UI conversion; typed numeric values | Numeric constraints; nonnegative bytes | Original numeric representation | Shared percent/unit/byte formatting |
| Date/time/duration/instant | Typed calendar date/time/duration/DateTime | Date picker, time/duration parser, ranges | Valid calendar/time syntax and shared comparisons | ISO date/time, integer microseconds, timestamp | Calendar fields do not shift timezone; explicit instant timezone policy |
| Boolean/enum | Nullable bool is tri-state in forms and DDL; enum defaults | Toggle/unset, radio/select | Required/in-list/type checks | Null/true/false retained; enum names | Labels, badges, empty value policy |
| Tags/primitive lists | Four primitive list types with typed helpers | Tags, multi-select, checkbox groups, repeaters | Item type, item rules, count/distinct constraints | Valid JSON round trip | Structured format and CSV cell quoting |
| JSON/embedded object | Typed JSON AST and reusable declared object schemas | Recursive child editors or raw JSON text | Parse errors, child rules, unknown properties | Structured values preserved | Shared structured serialization |
| Dynamic product attributes | Existing String storage remains compatible | Editor follows selected category definition | UI parsing plus authoritative shop definition checks | Canonical text/number/bool representation | Existing catalog presentation |
| Image/file/gallery | Typed owned relationship fields | Native picker, local preview, descriptions, ordering | Size/MIME locally; image dimensions/server transforms | Save-time upload; graph-owned rows; recovery-aware cleanup | Stored URL resolution, loading/failure fallback |
| Conditional/cross-field/collection | Model `validationRules` delegated by generator | Local and async pending/error state | requiredIf, sameAs, before/after, count/distinct/sum, unique/exists | Merged updates; final graph validation; transactional rollback | Field errors and pending submission |

## Regression suites

- `packages/beak_core/test/src/columns/beak_semantic_test.dart`: semantic codecs,
  exact arithmetic, dates/times, lists, structured values and boundary rejection.
- `packages/beak_core/test/src/columns/beak_format_policy_test.dart`: exact money,
  locale, units, date/time policy and formatter wire round trips.
- `packages/beak_core/test/src/validation/beak_validation_test.dart`: shared scalar,
  metadata and record constraints.
- `packages/beak_cli/test/src/schema/beak_semantic_schema_test.dart`: generated
  types/defaults/member references, strict generated-project analysis and executable
  read/write/filter proof.
- `packages/beak_backend/test/src/service/shared_validation_test.dart`: trusted
  async checks, edit identity exclusion and graph authority.
- `packages/beak_backend/test/src/data/worm/beak_blueprint_test.dart`: nullable DDL,
  scalar/enum/exact defaults and schema behavior.
- `packages/beak_frontend/test/src/form/semantic_inputs_test.dart`: typed editor
  values, parser errors, nullability and async/stale state.
- `packages/beak_frontend/test/src/form/beak_gallery_test.dart`: owned rows,
  ordering, persistence and removal.
- `packages/beak_frontend/test/src/form/beak_draft_uploads_test.dart`: delayed
  uploads, reuse, cancellation, unknown receipts and closing during save, recovery or upload preparation.
- `packages/beak_backend/test/src/uploads/`: URL authorization/path validation,
  MIME/size/dimensions, rendition cleanup and existing storage-driver integration.
- `examples/clean_beak_config/test/shop_api_test.dart`: generated semantic fields
  across real HTTP + SQLite and direct API constraint rejection.
- `examples/clean_beak_config/test/shop_widget_test.dart`: structured policy and
  product tab layouts at narrow and desktop widths, retaining the typed draft.
- `examples/clean_beak_config/test/shop_migration_test.dart`: additive upgrades,
  complete relationship schema and idempotent seeding preserving user edits.

## Deliberate boundaries

Database indexes provide the final uniqueness guarantee under concurrency.
Async preflight is advisory and writes repeat authoritative checks. UI-only
callbacks cannot become server rules by serialization. Password semantics do not
replace authentication/hashing. Storage cleanup after crashes or deletion of
shared existing file keys requires a reference-aware host storage policy. Custom
widgets, columns, rules and transports remain the escape hatch for specialized
workflows.
