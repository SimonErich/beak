## Unreleased

- Added `DataException`, thrown when the database refuses a value for its size,
  range or format (PostgreSQL SQLSTATE class `22`, MySQL "data too long" and
  "out of range"). `CheckConstraintException` is now thrown for CHECK and NOT
  NULL violations by the PostgreSQL (`23514`, `23502`), SQLite (`275`, `1299`)
  and MySQL (`3819`, `4025`, `1048`) drivers; they used to surface as a plain
  `QueryException`.
- SQLite binds every `DateTime` as the text of its UTC instant. A local time
  used to be written without its offset, so it sorted away from the UTC value
  naming the same moment.
- The in-memory adapter's `like`, `notLike` and `ilike` let `%` and `_` match a
  line break, as SQL does.
- Added `Predicate.escape`: the escape character of a `like`, `notLike` or
  `ilike` pattern. The SQL compilers state it as `ESCAPE '<char>'` (SQLite has
  no default escape character; PostgreSQL and MySQL disagree on theirs), the
  in-memory evaluator and the Mongo compiler honour it.
- Added `CurrentReadCapable` for explicit current/locking reads. MySQL supplies
  parameterized `SELECT ... FOR UPDATE` on its pooled and transaction adapters.
- Added `SchemaResetCapable`, an explicit transaction boundary for destructive
  migration rebuilds. SQLite defers foreign-key checks until reset commit while
  retaining enforcement; failures roll back schema and data. Ordinary
  transactions continue checking foreign keys immediately.

## 1.0.0

- Initial version.
