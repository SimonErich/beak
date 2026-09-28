## Unreleased

- Added `CurrentReadCapable` for explicit current/locking reads. MySQL supplies
  parameterized `SELECT ... FOR UPDATE` on its pooled and transaction adapters.
- Added `SchemaResetCapable`, an explicit transaction boundary for destructive
  migration rebuilds. SQLite defers foreign-key checks until reset commit while
  retaining enforcement; failures roll back schema and data. Ordinary
  transactions continue checking foreign keys immediately.

## 1.0.0

- Initial version.
