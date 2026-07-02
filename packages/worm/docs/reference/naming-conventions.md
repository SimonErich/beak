---
title: Naming conventions
description: How worm derives snake_case columns, plural table names, pivot tables, foreign keys, and morph columns, and every escape hatch to override them.
---

This page is the complete reference for `NamingConvention`, the pure-function naming utilities worm and `worm_generator` use to derive database names from Dart identifiers. It also covers the derived defaults for foreign keys, pivot keys, and morph columns, plus every override point.

## Mini-index

| Symbol | One-liner |
| --- | --- |
| [`NamingConvention.toSnakeCase`](#namingconventiontosnakecase) | camelCase or PascalCase to snake_case, acronym-aware |
| [`NamingConvention.toCamelCase`](#namingconventiontocamelcase) | snake_case to camelCase |
| [`NamingConvention.tableName`](#namingconventiontablename) | PascalCase class name to plural snake_case table name |
| [`NamingConvention.pivotTableName`](#namingconventionpivottablename) | Alphabetical singular pivot table name for many-to-many |
| [Derived column names](#derived-column-names) | Default foreign key, pivot key, and morph column names |
| [Escape hatches](#escape-hatches) | Every place you can override a derived name |
| [CLI naming helpers](#cli-naming-helpers) | `pascalToSnake`, `tableNameFor`, `snakeToPascal`, `migrationTimestamp` |

`NamingConvention` is a `final class` with a private constructor. All methods are static; you never instantiate it.

### NamingConvention.toSnakeCase

```dart
static String toSnakeCase(String input)
```

Converts camelCase or PascalCase to snake_case. Consecutive uppercase letters are treated as an acronym and kept together; a boundary is inserted before the last uppercase letter when a lowercase letter follows it. The function is idempotent: applying it twice gives the same result.

```dart
NamingConvention.toSnakeCase('userId');           // 'user_id'
NamingConvention.toSnakeCase('createdAt');        // 'created_at'
NamingConvention.toSnakeCase('HTMLContent');      // 'html_content'
NamingConvention.toSnakeCase('parseHTMLContent'); // 'parse_html_content'
NamingConvention.toSnakeCase('URLParser');        // 'url_parser'
NamingConvention.toSnakeCase('URL');              // 'url'
NamingConvention.toSnakeCase('already_snake');    // 'already_snake'
```

This is what the code generator uses to turn a `@Column` field name into its column name when you do not pass `@Column(name: ...)`.

### NamingConvention.toCamelCase

```dart
static String toCamelCase(String input)
```

Converts snake_case back to camelCase. Empty segments between underscores are skipped.

```dart
NamingConvention.toCamelCase('user_id');    // 'userId'
NamingConvention.toCamelCase('created_at'); // 'createdAt'
NamingConvention.toCamelCase('id');         // 'id'
```

### NamingConvention.tableName

```dart
static String tableName(String input)
```

Converts a PascalCase model class name to a plural snake_case table name: first `toSnakeCase`, then pluralization of the last snake segment only.

```dart
NamingConvention.tableName('User');         // 'users'
NamingConvention.tableName('BlogPost');     // 'blog_posts'
NamingConvention.tableName('BlogCategory'); // 'blog_categories'
```

The pluralizer applies these rules, in order:

| Rule | Example |
| --- | --- |
| Uncountable words stay unchanged | `Series` becomes `series`, `Sheep` becomes `sheep` |
| Irregular forms map directly | `Person` becomes `people`, `Child` becomes `children` |
| `-y` after a consonant becomes `-ies` | `Category` becomes `categories` |
| `-y` after a vowel adds `-s` | `Day` becomes `days` |
| `-s`, `-x`, `-z`, `-ch`, `-sh` add `-es` | `Box` becomes `boxes`, `Match` becomes `matches` |
| `-f` or `-fe` becomes `-ves` | `Wolf` becomes `wolves`, `Knife` becomes `knives` |
| Everything else adds `-s` | `User` becomes `users` |

Complete irregulars table (singular to plural): person/people, child/children, man/men, woman/women, tooth/teeth, foot/feet, mouse/mice, goose/geese, index/indices, matrix/matrices, vertex/vertices.

Complete uncountables set: data, equipment, information, series, species, fish, sheep, deer.

:::note[English only]
The pluralizer knows English rules and the fixed lists above, nothing else. If your model names are in another language, or you hit a word the rules mangle, override the table name explicitly (see [escape hatches](#escape-hatches)).
:::

### NamingConvention.pivotTableName

```dart
static String pivotTableName(String a, String b)
```

Conventional pivot table name for a many-to-many relation: the singular snake_case of both class names, sorted alphabetically, joined with `_`. Note the singular: pivot names are not pluralized.

```dart
NamingConvention.pivotTableName('User', 'Role');    // 'role_user'
NamingConvention.pivotTableName('Role', 'User');    // 'role_user' (order-independent)
NamingConvention.pivotTableName('BlogPost', 'Tag'); // 'blog_post_tag'
```

## Derived column names

Beyond `NamingConvention` itself, the code generator and relation layer derive these defaults:

| Name | Default derivation | Example |
| --- | --- | --- |
| Table name | `NamingConvention.tableName(className)` unless `@Table(name:)` is set | `User` maps to `users` |
| Column name | `NamingConvention.toSnakeCase(fieldName)` unless `@Column(name:)` is set | `createdAt` maps to `created_at` |
| Foreign key (has-one / has-many) | `toSnakeCase(parentClassName) + '_id'` | `User` has many `Post`: FK is `user_id` on `posts` |
| Pivot table (belongs-to-many) | `pivotTableName(a, b)` | `User` and `Role`: `role_user` |
| Pivot keys (belongs-to-many) | `toSnakeCase(className) + '_id'` for each side | `user_id` and `role_id` on `role_user` |
| Morph columns | `<morphName>_type` and `<morphName>_id` | morph name `commentable`: `commentable_type`, `commentable_id` |
| Morph name | `ModelRegistration.effectiveMorphName`, which is `morphName ?? tableName` | `User` defaults to `users` |

At runtime, table-name resolution for a model instance follows a chain: the model's own `tableName` override wins, then the `ModelRegistration.tableName` from the registry, and if neither resolves, worm throws `ConfigurationException` with key `model.tableName.missing` (see [exceptions](./exceptions.md#configurationexception)).

## Escape hatches

Every derived name can be overridden at the point where it is declared:

```dart title="lib/models/user.dart"
@Table(name: 'app_users')                 // table name override
class User extends Model {
  User({required this.email, this.posts = const [], this.roles = const []});

  @Column(name: 'email_address')          // column name override
  final String email;

  @HasMany(Post, foreignKey: 'author_id') // FK override
  final List<Post> posts;

  @BelongsToMany(
    Role,
    pivotTable: 'user_permissions',       // pivot table override
    foreignPivotKey: 'member_id',         // this side's pivot key
    relatedPivotKey: 'permission_id',     // other side's pivot key
  )
  final List<Role> roles;

  // id, toRow, and the generated part file are omitted here;
  // see the defining-models guide for the full model shape.
}
```

- `@Table(name:, connection:)` overrides the table name and target connection.
- `@Column(name:)` overrides a single column name.
- `@HasOne` / `@HasMany` take `foreignKey:` and `localKey:`; `@BelongsTo` takes `foreignKey:` and `ownerKey:`.
- `@BelongsToMany` takes `pivotTable:`, `foreignPivotKey:`, and `relatedPivotKey:`.
- `@MorphToMany` takes `morphName:` and `pivotTable:`.
- `ModelRegistration(tableName:, primaryKeyColumn:, morphName:)` sets the same facts for the runtime registry when you register models with `Worm.initialize`.

## CLI naming helpers

The `make:*` CLI commands use their own lightweight helpers (exported from `package:worm/worm.dart`) to render scaffolding templates:

| Function | Signature | Behavior |
| --- | --- | --- |
| `pascalToSnake` | `String pascalToSnake(String input)` | `BlogPost` to `blog_post`. Inserts `_` before every uppercase letter; not acronym-aware. |
| `tableNameFor` | `String tableNameFor(String className)` | `BlogPost` to `blog_posts`. Naive pluralization: names already ending in `s` pass through, `-y` always becomes `-ies`, everything else adds `-s`. |
| `snakeToPascal` | `String snakeToPascal(String input)` | `blog_post` to `BlogPost`. |
| `migrationTimestamp` | `String migrationTimestamp(DateTime now)` | `YYYYMMDD_HHMMSS` migration filename prefix, always normalized to UTC. |

See [CLI commands](./cli-commands.md) for the commands that call these.

## Gotchas

- The CLI's `tableNameFor` is deliberately naive and diverges from `NamingConvention.tableName`: it knows no irregulars or uncountables, and it turns every trailing `-y` into `-ies` (even after a vowel). For a model named `Person` the scaffolded table name is `persons`, while the code generator resolves `people`. Check scaffolded names before you migrate.
- `pascalToSnake` (CLI) is not acronym-aware; `NamingConvention.toSnakeCase` is. `HTMLContent` yields `h_t_m_l_content` from the former and `html_content` from the latter.
- `pivotTableName` never pluralizes: `role_user`, not `roles_users`.
- Only the last snake segment of a class name is pluralized: `BlogCategory` becomes `blog_categories`, never `blogs_categories`.
- `toSnakeCase` only recognizes ASCII letters (`A-Z`, `a-z`) for case boundaries.
- The pluralizer is English-only. Use `@Table(name:)` for anything it gets wrong.

## Continue reading

- [Defining models](../models/defining-models.md): where table and column names actually get declared and overridden.
- [Defining relations](../relations/defining-relations.md): how foreign keys and pivot tables come into play.
- [CLI commands](./cli-commands.md): the `make:*` commands that consume the CLI naming helpers.
- [Exceptions](./exceptions.md): the `ConfigurationException` you see when a table name cannot be resolved.
