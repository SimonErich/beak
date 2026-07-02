---
title: Security
description: How worm prevents injection, guards mass assignment, and what you still have to secure yourself.
---

This page maps worm's security surfaces: where the ORM protects you automatically, where you take over responsibility, and which defaults you should tighten before going live. It builds on [mass assignment](../models/mass-assignment.md) and [validation](../models/validation.md).

## The injection model

Typed queries cannot inject. Every query you build with typed fields compiles to an immutable descriptor first. The driver's compiler then turns that descriptor into SQL with positional placeholders and a separate parameter list:

- PostgreSQL binds values as `$1`, `$2`, and so on.
- MySQL and SQLite bind values as `?` placeholders.
- MongoDB receives structured filter maps, never concatenated strings.

Values from the descriptor never become part of the statement text. This holds for `where` predicates, `insert` and `update` values, `inList` items, and `between` bounds. `orderBy` and `select` accept typed fields, not strings, so they carry identifiers only.

```dart
// userInput came from a request. It is bound as a parameter,
// never spliced into the SQL text.
final users = await User.query()
    .where(User$.email.eq(userInput))
    .get();
```

One debugging caveat: `toSql()` inlines literal values so you can read the query. That string is for your eyes only. Worm never executes it, and you should never execute it either.

## Raw escape hatches: the only developer-trusted surfaces

Four surfaces accept text or maps that worm passes through verbatim. These are the only places where injection is possible, and all of them treat the string as code you wrote, not data:

| Surface | What is trusted | What is still bound |
| --- | --- | --- |
| `whereRaw(sql, parameters:, allowRaw: true)` | The SQL fragment | Every value in `parameters` |
| `.sql((q) => q.having(expression, operator, value))` | The aggregate expression string | The comparison `value` |
| `.mongo((m) => m.withRawFilter(...))` and `withPipeline(...)` | The whole filter map / pipeline stages | Nothing |
| `adapter.rawQuery(sql, params)` / `rawExecute(sql, params)` | The SQL statement | Every value in `params` |

`whereRaw` refuses to run without `allowRaw: true` and throws a `ConfigurationException` otherwise. That flag exists to make the trust decision visible at the call site:

```dart
// Correct: the fragment is a constant you wrote.
// The value still travels as a bound parameter.
final rows = await User.query()
    .whereRaw(
      'LOWER(email) = ?',
      parameters: [input.toLowerCase()],
      allowRaw: true,
    )
    .get();
```

```dart
// NEVER do this. The input becomes part of the SQL text
// and can rewrite the query.
final rows = await User.query()
    .whereRaw("email = '$input'", allowRaw: true)
    .get();
```

The rule is short: raw strings must be constants or come from your own code. Anything a user typed goes through `parameters` or a typed predicate.

## Mass assignment

`fill()` and `update()` apply request-shaped maps to a model. Without guards, a request body containing `{"role": "admin"}` writes straight into the `role` attribute. Declare what is assignable on the model:

```dart title="lib/models/user.dart"
final class User extends Model {
  // ...columns and required overrides...

  @override
  List<String> get fillable => const ['name', 'email'];

  @override
  List<String> get guarded => const ['role'];
}
```

By default, offending keys are silently skipped. Silence hides bugs and probing attempts, so turn on strict mode in production:

```dart
await Worm.initialize(
  config: const WormConfig(
    strictness: StrictnessConfig(preventSilentMassAssignment: true),
  ),
  adapters: {'default': adapter},
);
```

With the flag on, `fill()` throws a `MassAssignmentException` listing every offending key in `.fields` (`.field` holds only the first one). A single model can opt in on its own by overriding `strictMassAssignment` to `true`. Full details live on [mass assignment](../models/mass-assignment.md); the flag reference lives on [strict mode](./strict-mode.md).

## Validation as boundary defense

Rules run automatically on `save()` and throw a `ValidationException` before anything reaches the database. Use `Unique` with `exceptId:` so update paths do not collide with the row being updated:

```dart
@override
Map<Field<Object?>, List<ValidationRule>> get updateRules => {
  User$.email: [
    Unique(
      adapter: Worm.adapter(),
      table: 'users',
      column: 'email',
      exceptId: id,
    ),
  ],
};
```

`ValidationException.errors` exposes a `Map<String, List<String>>` of field names to messages, safe to return to clients. Database-level `UniqueConstraintException`s can be converted to the same shape with `ValidationException.fromUniqueConstraint`. See [validation](../models/validation.md) for the full rule catalog.

## Hiding fields in serialization

`hiddenFromSerialization` removes keys from `toMap()` and `toJson()` output:

```dart
@override
Set<String> get hiddenFromSerialization => const {'password_hash'};
```

Two caveats:

- Serialization is not a redaction boundary for identifiers. When the cycle-aware serializer collapses a repeated node it emits `{type, id, ref: true}`, so primary keys appear in output by design.
- Per-call `toMap(hidden: ...)` and `toMap(only: ...)` refine one call; they do not change the model's default shape.

See [serialization](../models/serialization.md) for the pipeline.

## Field-level encryption and its limits

`EncryptedCast` is an abstract skeleton. It handles null passthrough and type checks; you implement `encryptString` and `decryptString` with your own primitive (AES-GCM, libsodium, a KMS call). Worm ships no cipher, no key management, and no default format.

Be clear about what does not exist:

- Worm has no encryption-at-rest. There is no SQLCipher option and no encrypted database file support in any shipped driver.
- Encrypted columns are opaque to the database. You cannot filter, sort, or index on their plaintext.

If you need whole-database encryption, solve it at the infrastructure layer (encrypted volumes, managed database encryption).

## Query log redaction

Query logs include bound parameters by default, which means user data lands in your log files. Redact them in production:

```dart
final logger = QueryLogger.fromConfig(
  const LogConfig(
    file: '/var/log/worm.log',
    logQueryParameters: false,
  ),
);
```

With `logQueryParameters: false` every log line prints `params: [REDACTED]` instead of the values. Wiring the `LoggingAdapter` is covered in [logging and debugging](./logging-and-debugging.md).

## Transport security

:::caution[MySQL accepts bad certificates by default under fromUri]
`MysqlConnectionPool.fromUri` with `?ssl=true` installs a permissive certificate callback so self-signed development servers connect. In production this accepts any certificate, including a man-in-the-middle's. Pass your own `onBadCertificate` (or use `fromConfig`, which installs no permissive default) and verify the chain.
:::

For PostgreSQL, `ConnectionConfig(useSsl: true)` maps to the driver's `SslMode.require`; `false` disables TLS entirely. Details per driver: [MySQL](../drivers/mysql.md), [PostgreSQL](../drivers/postgresql.md).

## Credentials

`ConnectionConfig` carries `username` and `password` as plain metadata. Worm never persists or logs them, but the config object is only as safe as its source. Read credentials from the process environment at startup; never commit them:

```dart
final config = ConnectionConfig(
  driver: 'postgres',
  host: Platform.environment['DB_HOST'] ?? 'localhost',
  database: 'app',
  username: Platform.environment['DB_USER'],
  password: Platform.environment['DB_PASSWORD'],
  useSsl: true,
);
```

## Destructive operation gates

The CLI refuses `migrate:fresh` and `migrate:refresh` in production unless you pass `--force`, and `schema:dump --prune` requires `--force` in every environment. These gates protect data, not secrets, but they belong in the same review: see [production](./production.md).

## Gotchas

- `toSql()` output inlines literals. It exists for debugging and must never be executed.
- `db:seed --force` bypasses environment filtering, not production safety. It is not a security gate.
- `MassAssignmentException.field` contains only the first offending key. Use `.fields` for the complete list.
- `Worm.unsafe` bypasses the global `preventSilentMassAssignment` flag inside its zone. Audit every `unsafe` block in review.
- Guarded attributes are still writable through `setAttribute` and direct field assignment. `fillable`/`guarded` only govern `fill()` and `update()` maps.
- Serialized output can contain `{type, id, ref: true}` stubs for cycle references. Primary keys are not secret in worm's model.

## Continue reading

- [Mass assignment](../models/mass-assignment.md) for the full `fill()` contract and override reference.
- [Strict mode](./strict-mode.md) for every guardrail flag and the exception each one throws.
- [Production](./production.md) for the deploy checklist that pairs with this page.
- [MySQL driver](../drivers/mysql.md) for the TLS callout in context.
