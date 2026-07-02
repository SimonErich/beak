# Worm — The Definitive Dart ORM

## Technical Specification v1.0

---

## Table of Contents

1. [Vision & Philosophy](#1-vision--philosophy)
2. [Architecture & Package Structure](#2-architecture--package-structure)
3. [Configuration & Connection Management](#3-configuration--connection-management)
4. [Code Generation Strategy](#4-code-generation-strategy)
5. [Model System](#5-model-system)
6. [Type-Safe Query Builder](#6-type-safe-query-builder)
7. [Relationships](#7-relationships)
8. [Migration System](#8-migration-system)
9. [Seeder System](#9-seeder-system)
10. [Factory System](#10-factory-system)
11. [Database Adapters](#11-database-adapters)
12. [Events & Lifecycle Hooks](#12-events--lifecycle-hooks)
13. [Validation](#13-validation)
14. [Serialization](#14-serialization)
15. [Scopes](#15-scopes)
16. [Soft Deletes](#16-soft-deletes)
17. [Pagination & Chunking](#17-pagination--chunking)
18. [Transactions](#18-transactions)
19. [CLI Tool](#19-cli-tool)
20. [Logging & Debugging](#20-logging--debugging)
21. [Strictness Mode](#21-strictness-mode)
22. [Performance](#22-performance)
23. [Error Handling](#23-error-handling)
24. [Testing Strategy](#24-testing-strategy)
25. [Naming Conventions](#25-naming-conventions)

---

## 1. Vision & Philosophy

### 1.1 What Worm Is

Worm is a Dart-native ORM for **server-side Dart applications** that combines the expressiveness of Laravel's Eloquent with the type safety of Dart's static type system. It supports both SQL (PostgreSQL) and NoSQL (MongoDB) databases through a unified, adapter-based architecture.

### 1.2 Core Principles

1. **Type Safety Everywhere** — No string-based field references in queries. Every column, relationship, and scope is statically typed and IDE-completable. A typo is a compile-time error, not a runtime surprise.

2. **Expressive & Declarative** — Models are defined with annotations. Queries read like English. Relationships are one-line declarations. The developer writes *what* they want, not *how* to get it.

3. **Dart-Native** — camelCase everywhere. Null safety. `async`/`await`. Extensions. Dart macros (with `build_runner` fallback). No PHP patterns forced into Dart.

4. **Performance by Default** — Automatic N+1 prevention via batched eager loading. Connection pooling. Dirty tracking for minimal UPDATE statements. Prepared statement reuse. Query result streaming.

5. **Safety & Control** — Manual migration review before any schema change. Environment-typed seeders. Strictness modes for development. DB-level cascades by default with ORM-level override option.

6. **Dual Pattern Support** — Active Record as the default (simple, fast, expressive). Data Mapper as opt-in (testable, separation of concerns, complex business logic).

### 1.3 Target Runtime

Worm is designed exclusively for **server-side Dart** (Shelf, Dart Frog, custom servers). It is NOT designed for Flutter mobile/desktop. This means:

- Full `dart:io` access for file-based logging, CLI tools, and network connections
- No concerns about binary size or `dart:mirrors` restrictions
- Connection pooling with long-lived server processes in mind
- Isolate-safe connection management for multi-threaded servers

### 1.4 Supported Databases (V1)

- **PostgreSQL** (primary, full feature support) via `worm_postgres`
- **MongoDB** (first-class NoSQL support) via `worm_mongodb`
- Future: MySQL, SQLite, MSSQL via additional adapter packages

---

## 2. Architecture & Package Structure

### 2.1 Package Topology

```
worm (monolith core — published to pub.dev)
├── lib/
│   ├── worm.dart                    # Main barrel export
│   ├── src/
│   │   ├── model/                   # Base Model, ActiveRecord, Repository
│   │   ├── query/                   # QueryBuilder, Descriptor, PredicateTree
│   │   ├── schema/                  # Schema builder, Blueprint, ColumnDefinition
│   │   ├── migration/               # Migration base, Runner, DiffEngine
│   │   ├── seeder/                  # Seeder base, Runner, environment typing
│   │   ├── factory/                 # Factory base, FakerIntegration
│   │   ├── relation/                # Relationship types, EagerLoader
│   │   ├── scope/                   # GlobalScope, LocalScope, SoftDeleteScope
│   │   ├── event/                   # EventDispatcher, Observer, lifecycle
│   │   ├── validation/              # ValidationRule, Validator
│   │   ├── cast/                    # CastManager, built-in casts, Decimal
│   │   ├── serialization/           # Serializer, hidden/visible/appends
│   │   ├── pagination/              # Paginator, CursorPaginator
│   │   ├── transaction/             # TransactionManager, abstraction
│   │   ├── logging/                 # QueryLogger, FileLogger, ExplainRunner
│   │   ├── config/                  # WormConfig, ConnectionConfig, StrictnessConfig
│   │   ├── adapter/                 # DatabaseAdapter interface, AdapterCapabilities
│   │   ├── exception/               # All custom exception types
│   │   └── codegen/                 # Macro definitions, build_runner generators
│   └── annotations.dart             # All annotation classes (@Table, @Column, etc.)
├── bin/
│   └── worm.dart                    # CLI entry point (pub global activate)

worm_postgres (separate package)
├── lib/
│   ├── worm_postgres.dart
│   └── src/
│       ├── postgres_adapter.dart
│       ├── postgres_query_compiler.dart
│       ├── postgres_schema_compiler.dart
│       └── postgres_migration_compiler.dart

worm_mongodb (separate package)
├── lib/
│   ├── worm_mongodb.dart
│   └── src/
│       ├── mongo_adapter.dart
│       ├── mongo_query_compiler.dart
│       ├── mongo_schema_compiler.dart
│       └── mongo_migration_compiler.dart
```

### 2.2 Descriptor-First Architecture

Every operation in Worm follows a three-phase pipeline:

```
User API  →  Descriptor (immutable)  →  Adapter Compilation  →  Execution
```

1. **User API**: The developer calls fluent methods (e.g., `User.query().where(...)`)
2. **Descriptor**: The QueryBuilder produces an immutable `QueryDescriptor` — a data structure describing the intent (filters, sorts, joins, projections) with zero database-specific knowledge
3. **Adapter Compilation**: The active adapter (Postgres or Mongo) compiles the descriptor into native queries (SQL string or Mongo filter document)
4. **Execution**: The adapter executes against the database and returns raw results
5. **Hydration**: Raw results are mapped back into typed model instances

This architecture means:

- Descriptors are testable without a database (golden snapshot tests)
- Adapters are swappable without touching business logic
- Query analysis/optimization can happen at the descriptor level
- The same descriptor can produce SQL or Mongo queries

### 2.3 Model Registry

All models **must** be registered before use. This is enforced at startup:

```dart
void main() async {
  Worm.initialize(
    models: [User, Post, Comment, Profile, Role],
    adapters: {
      'default': PostgresAdapter(/* config */),
      'analytics': MongoAdapter(/* config */),
    },
  );
  
  // Start your server...
}
```

The registry provides:
- Morph type resolution (polymorphic relationships)
- Field validation (reject unknown field names at compile time via codegen)
- Relationship graph for eager loading optimization
- Schema metadata for migration auto-generation

---

## 3. Configuration & Connection Management

### 3.1 Configuration

Worm uses a programmatic configuration approach (no YAML/JSON files — Dart is expressive enough):

```dart
final config = WormConfig(
  defaultConnection: 'main',
  connections: {
    'main': PostgresConnectionConfig(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: 'app_db',
      username: 'dbuser',
      password: Platform.environment['DB_PASSWORD'] ?? '',
      poolSize: 10,
      sslMode: SslMode.prefer,
    ),
    'mongo': MongoConnectionConfig(
      uri: Platform.environment['MONGO_URI'] ?? 'mongodb://localhost:27017/app_db',
    ),
  },
  logging: LogConfig(
    enabled: true,
    level: LogLevel.info,
    file: 'logs/worm.log',     // File-based logging for all queries
    slowQueryThreshold: Duration(milliseconds: 200),
  ),
  strictness: StrictnessConfig(
    preventLazyLoading: true,       // Throws if lazy loading in strict mode
    preventFullTableScans: true,    // Throws on queries without WHERE
    preventSilentMassAssign: true,  // Throws on unguarded mass assignment
    logN1Warnings: true,            // Warns on potential N+1 patterns
  ),
);
```

### 3.2 Connection Manager

The `ConnectionManager` holds named connections and manages their lifecycle:

```dart
// Models default to the 'default' connection
@Table(name: 'users')
class User extends Model { ... }

// Override per model
@Table(name: 'analytics_events', connection: 'mongo')
class AnalyticsEvent extends Model { ... }
```

### 3.3 Connection Pooling

For PostgreSQL:
- Configurable pool size (default: 10)
- Connection health checking with configurable interval
- Automatic reconnection on connection loss
- Per-isolate pool instances for multi-isolate servers
- Idle connection timeout and cleanup

For MongoDB:
- Delegates to the Mongo driver's built-in connection management
- Configurable min/max pool size passed through to driver

---

## 4. Code Generation Strategy

### 4.1 Macro-First, build_runner Fallback

Worm uses Dart macros as the primary code generation mechanism. For environments where macros are not yet stable or available, `build_runner` serves as a fallback.

### 4.2 What Gets Generated

For each model annotated with `@Table`, the following is generated:

#### A) Field Metadata Class (`User$`)

```dart
// Generated: user.worm.dart (via macro or build_runner)

class User$ {
  static const table = 'users';
  
  // Type-safe field references for queries
  static const id = Field<String>('id', columnName: 'id');
  static const name = Field<String>('name', columnName: 'name');
  static const email = Field<String>('email', columnName: 'email');
  static const isActive = Field<bool>('is_active', columnName: 'is_active');
  static const createdAt = Field<DateTime>('created_at', columnName: 'created_at');
  static const updatedAt = Field<DateTime>('updated_at', columnName: 'updated_at');
  
  // All fields for introspection
  static const fields = [id, name, email, isActive, createdAt, updatedAt];
  
  // Relationship accessors (generated from @HasMany, @BelongsTo, etc.)
  static const posts = RelationField<List<Post>>('posts');
  static const profile = RelationField<Profile?>('profile');
  static const roles = RelationField<List<Role>>('roles');
}
```

#### B) Hydration Methods

```dart
extension UserHydration on User {
  /// Hydrate from raw DB row (adapter-returned Map)
  static User fromRow(Map<String, dynamic> row) {
    return User()
      .._id = row['id'] as String
      .._name = row['name'] as String
      .._email = row['email'] as String
      .._isActive = row['is_active'] as bool? ?? true
      .._createdAt = DateTime.parse(row['created_at'] as String)
      .._updatedAt = DateTime.parse(row['updated_at'] as String)
      .._exists = true
      .._original = Map.unmodifiable(row);
  }
  
  /// Dehydrate to DB-compatible Map (only dirty fields for UPDATE)
  Map<String, dynamic> toRow({bool onlyDirty = false}) {
    if (onlyDirty) {
      return _dirtyFields.map((f) => MapEntry(f.columnName, _getFieldValue(f)));
    }
    return {
      'id': _id,
      'name': _name,
      'email': _email,
      'is_active': _isActive,
      'created_at': _createdAt?.toIso8601String(),
      'updated_at': _updatedAt?.toIso8601String(),
    };
  }
}
```

#### C) Query Starter Extension

```dart
extension UserQuery on User {
  static QueryBuilder<User> query() => QueryBuilder<User>(User$);
  static Future<User?> find(String id) => query().where(User$.id, id).first();
  static Future<List<User>> all() => query().get();
}
```

#### D) Typed Scope Methods

```dart
// Generated from @Scope annotations on the model
extension UserScopes on QueryBuilder<User> {
  QueryBuilder<User> active() => where(User$.isActive, true);
  QueryBuilder<User> createdAfter(DateTime date) =>
      where(User$.createdAt, Operator.greaterThan, date);
}
```

### 4.3 Macro Definition (Primary)

```dart
// In worm/lib/src/codegen/worm_macro.dart
macro class WormModel implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const WormModel();
  
  @override
  void buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) {
    // Generates User$ companion class
    // Generates hydration extension
    // Generates query starter
    // Generates scope extensions
    // Generates factory definition skeleton
  }
}
```

Usage:

```dart
@WormModel()
@Table(name: 'users')
class User extends Model {
  @Column()
  String name;
  
  @Column(unique: true)
  String email;
  
  // ... macro generates everything else
}
```

### 4.4 build_runner Fallback

For projects that can't use macros yet:

```yaml
# pubspec.yaml
dev_dependencies:
  worm_generator: ^1.0.0
  build_runner: ^2.4.0
```

```bash
dart run build_runner build
```

Generates `*.worm.dart` files alongside model files with identical output to macros.

### 4.5 Naming Convention: Dart camelCase ↔ DB snake_case

Worm automatically converts between Dart's `camelCase` field names and database `snake_case` column names:

- Dart `userId` → DB `user_id`
- Dart `createdAt` → DB `created_at`
- Dart `isActive` → DB `is_active`

This conversion is applied:
- In generated `Field` references (the `columnName` parameter)
- In `toRow()` / `fromRow()` hydration
- In migration schema builders
- In relationship foreign key inference

Override with explicit column name when needed:

```dart
@Column(name: 'legacy_usr_name')
String userName;  // Maps to 'legacy_usr_name' instead of 'user_name'
```

---

## 5. Model System

### 5.1 Base Model Class

```dart
abstract class Model {
  // UUID primary key — auto-generated, default for all models
  @PrimaryKey(type: PrimaryKeyType.uuid)
  late final String id = Uuid().v7();  // UUIDv7 for sortable, indexed performance
  
  // Internal state
  bool _exists = false;              // Has this been persisted?
  Map<String, dynamic> _original = {};  // Original values from DB (for dirty checking)
  final Set<String> _dirty = {};     // Changed field names
  Map<String, dynamic> _relations = {};  // Loaded relationships cache
  
  // ─── Persistence ───
  
  /// Insert or update based on _exists state
  Future<void> save();
  
  /// Delete (or soft-delete if SoftDeletes mixin is applied)
  Future<void> delete();
  
  /// Force-delete even if soft-deletes are enabled
  Future<void> forceDelete();
  
  /// Reload from database, discarding unsaved changes
  Future<void> refresh();
  
  /// Create a copy with a new UUID (unsaved)
  Model replicate({List<String> except = const []});
  
  // ─── Dirty Tracking ───
  
  /// Whether any fields have been modified since last save/load
  bool get isDirty => _dirty.isNotEmpty;
  
  /// List of modified field names
  Set<String> get dirtyFields => Set.unmodifiable(_dirty);
  
  /// Whether a specific field has been modified
  bool isFieldDirty(Field field) => _dirty.contains(field.name);
  
  /// Original value of a field before modification
  T? getOriginal<T>(Field<T> field) => _original[field.columnName] as T?;
  
  // ─── Mass Assignment ───
  
  /// Fill fields from a map, respecting guarded/fillable rules
  void fill(Map<String, dynamic> data);
  
  /// Fill and immediately save
  Future<void> update(Map<String, dynamic> data);
  
  // ─── Timestamps ───
  // Enabled by default via @Table annotation, can be disabled
  
  @Column()
  DateTime? createdAt;
  
  @Column()
  DateTime? updatedAt;
}
```

### 5.2 Active Record Pattern (Default)

Models are self-persisting. This is the primary API:

```dart
@Table(name: 'users')
class User extends Model {
  @Column()
  String name;
  
  @Column(unique: true)
  String email;
  
  @Column(defaultValue: true)
  bool isActive;
  
  @Column(guarded: true)
  String? role;
  
  // ─── Getters / Setters (Accessors / Mutators) ───
  
  // Accessor: transform on read
  String get displayName => name.toUpperCase();
  
  // Mutator: transform on write
  set password(String plain) => passwordHash = _hashPassword(plain);
  
  @Column()
  String? passwordHash;
  
  // ─── Relationships ───
  
  @HasMany(() => Post, foreignKey: 'userId')
  List<Post>? posts;
  
  @HasOne(() => Profile, foreignKey: 'userId')
  Profile? profile;
  
  @BelongsToMany(() => Role, pivot: 'user_roles', foreignKey: 'userId', relatedKey: 'roleId')
  List<Role>? roles;
  
  // ─── Scopes ───
  
  @Scope()
  static QueryBuilder<User> active(QueryBuilder<User> q) =>
      q.where(User$.isActive, true);
  
  @Scope()
  static QueryBuilder<User> createdAfter(QueryBuilder<User> q, DateTime date) =>
      q.where(User$.createdAt, Operator.greaterThan, date);
  
  // ─── Validation ───
  
  @override
  Map<Field, List<ValidationRule>> get rules => {
    User$.name: [Required(), MinLength(2), MaxLength(100)],
    User$.email: [Required(), Email(), Unique()],
  };
}
```

Usage:

```dart
// Create
final user = User()
  ..name = 'Jane Doe'
  ..email = 'jane@example.com';
await user.save();  // INSERT

// Read
final found = await User.find('uuid-here');
final all = await User.query().active().get();

// Update
found!.name = 'Jane Smith';
await found.save();  // UPDATE (only 'name' column, via dirty tracking)

// Delete
await found.delete();
```

### 5.3 Data Mapper Pattern (Opt-In)

For complex projects that benefit from separating persistence logic:

```dart
// Repository definition
class UserRepository extends Repository<User> {
  UserRepository(DatabaseAdapter adapter) : super(adapter);
  
  Future<List<User>> findActiveByRole(String role) {
    return query()
        .where(User$.isActive, true)
        .where(User$.role, role)
        .orderBy(User$.createdAt, descending: true)
        .get();
  }
  
  Future<User?> findByEmail(String email) {
    return query().where(User$.email, email).first();
  }
}

// Usage
final repo = UserRepository(Worm.adapter('default'));
final admins = await repo.findActiveByRole('admin');

// Save via repository instead of model.save()
final user = User()..name = 'Test';
await repo.save(user);
```

The `Repository<T>` base class provides:
- `query()` → `QueryBuilder<T>`
- `save(T model)` → Insert or update
- `delete(T model)` → Delete
- `find(String id)` → Find by primary key
- `all()` → Get all records
- Transaction wrapping for complex operations

### 5.4 UUID-First Primary Keys

All models use UUIDv7 by default:

- **UUIDv7** (not v4) for lexicographic sortability → better B-tree index performance
- Auto-generated on model instantiation (not on DB insert)
- PostgreSQL: `uuid` column type with index
- MongoDB: stored as `_id` string field

Override to integer PKs when needed:

```dart
@Table(name: 'legacy_table')
class LegacyModel extends Model {
  @PrimaryKey(type: PrimaryKeyType.integer, autoIncrement: true)
  @override
  late final int id;
}
```

### 5.5 Timestamps

Enabled by default. Disable per-model:

```dart
@Table(name: 'cache_entries', timestamps: false)
class CacheEntry extends Model { ... }
```

Behavior:
- `createdAt` set on first `save()` (INSERT)
- `updatedAt` set on every `save()` (INSERT and UPDATE)
- Bypass timestamps for specific operations: `Model.withoutTimestamps(() => model.save())`

### 5.6 Attribute Casting

Worm auto-infers casts from Dart types. Custom casts are declarative:

```dart
@Column()
DateTime publishedAt;  // Auto: DateTime ↔ ISO timestamp string / native timestamp

@Column()
Map<String, dynamic> metadata;  // Auto: Map ↔ JSONB (Postgres) / document (Mongo)

@Column()
List<String> tags;  // Auto: List ↔ JSON array (Postgres) / array (Mongo)

@Column()
UserStatus status;  // Auto: enum ↔ string (stores enum name)

@Column(cast: DecimalCast(precision: 10, scale: 2))
Decimal price;  // Decimal ↔ NUMERIC(10,2) (Postgres) / Decimal128 (Mongo)

@Column(cast: EncryptedCast())
String ssn;  // Encrypted at rest, decrypted on hydration

@Column(cast: CustomCast<Color>(
  fromDb: (v) => Color.fromHex(v as String),
  toDb: (c) => c.toHex(),
))
Color themeColor;
```

Built-in cast types:
- `String`, `int`, `double`, `bool` → native types
- `DateTime` → timestamp / ISO string
- `Duration` → integer (milliseconds)
- `Map<String, dynamic>` → JSONB / document
- `List<T>` → JSON array / array
- `Enum` → string (enum name) or int (index, configurable)
- `Decimal` → NUMERIC / Decimal128 (via `decimal` package)
- `Uri` → string
- `BigInt` → BIGINT / Long

### 5.7 Mass Assignment Protection

```dart
// Option A: Guarded fields (blacklist — these fields CANNOT be mass-assigned)
@Column(guarded: true)
String role;

@Column(guarded: true)
bool isAdmin;

// Option B: Fillable fields (whitelist — ONLY these can be mass-assigned)
@override
List<Field> get fillable => [User$.name, User$.email];

// Usage
user.fill({
  'name': 'Jane',
  'email': 'jane@example.com',
  'role': 'admin',  // Silently ignored (guarded), or throws in strict mode
});
```

In strict mode (`preventSilentMassAssign: true`), attempting to fill a guarded field throws `MassAssignmentException`.

### 5.8 Default Values

```dart
@Column(defaultValue: true)
bool isActive;  // Defaults to true if not set

@Column(defaultValue: DefaultValue.now)
DateTime createdAt;  // Defaults to DateTime.now() on instantiation

@Column(defaultValue: DefaultValue.uuid)
String trackingId;  // Defaults to a new UUID

@Column(defaultValue: [])
List<String> tags;  // Defaults to empty list
```

Default values are applied:
1. On model instantiation (constructor)
2. On hydration from DB when the column value is null
3. In migration schema as DB-level defaults where applicable

---

## 6. Type-Safe Query Builder

### 6.1 Design Philosophy

Worm's query builder is **fully type-safe**. No string-based column references. Every field access is validated at compile time. The builder produces immutable `QueryDescriptor` objects that are then compiled by the active adapter.

### 6.2 Basic Query Syntax

```dart
// Simple equality
final users = await User.query()
    .where(User$.email, 'jane@example.com')
    .get();

// With operators
final adults = await User.query()
    .where(User$.age, Operator.greaterThanOrEqual, 18)
    .get();

// Shorthand operators via Field extensions
final adults = await User.query()
    .where(User$.age.gte(18))
    .get();

// Lambda-based (most expressive, fully type-safe)
final results = await User.query()
    .where((u) => u.email.equals('jane@example.com'))
    .where((u) => u.age.gte(18))
    .get();
```

### 6.3 Operator Enum & Field Extensions

```dart
enum Operator {
  equals,
  notEquals,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  like,
  iLike,    // Case-insensitive LIKE (Postgres), regex (Mongo)
  notLike,
}

// Generated on Field<T> for ergonomic chaining
extension FieldOperators<T> on Field<T> {
  Predicate eq(T value) => Predicate(this, Operator.equals, value);
  Predicate neq(T value) => Predicate(this, Operator.notEquals, value);
  Predicate isNull() => Predicate.isNull(this);
  Predicate isNotNull() => Predicate.isNotNull(this);
}

extension ComparableFieldOperators<T extends Comparable> on Field<T> {
  Predicate gt(T value) => Predicate(this, Operator.greaterThan, value);
  Predicate gte(T value) => Predicate(this, Operator.greaterThanOrEqual, value);
  Predicate lt(T value) => Predicate(this, Operator.lessThan, value);
  Predicate lte(T value) => Predicate(this, Operator.lessThanOrEqual, value);
  Predicate between(T lower, T upper) => Predicate.between(this, lower, upper);
  Predicate notBetween(T lower, T upper) => Predicate.notBetween(this, lower, upper);
}

extension StringFieldOperators on Field<String> {
  Predicate like(String pattern) => Predicate(this, Operator.like, pattern);
  Predicate iLike(String pattern) => Predicate(this, Operator.iLike, pattern);
  Predicate contains(String substring) => Predicate(this, Operator.like, '%$substring%');
  Predicate startsWith(String prefix) => Predicate(this, Operator.like, '$prefix%');
  Predicate endsWith(String suffix) => Predicate(this, Operator.like, '%$suffix');
}

extension IterableFieldOperators<T> on Field<T> {
  Predicate whereIn(List<T> values) => Predicate.whereIn(this, values);
  Predicate whereNotIn(List<T> values) => Predicate.whereNotIn(this, values);
}
```

### 6.4 Complex Queries

```dart
// Grouped OR conditions
final results = await Post.query()
    .where(Post$.status.whereIn(['published', 'draft']))
    .whereGroup((q) => q
        .where(Post$.title.like('%Flutter%'))
        .orWhere(Post$.content.like('%Dart%')))
    .orderBy(Post$.createdAt, descending: true)
    .limit(10)
    .get();

// Subquery-style (whereExists)
final usersWithPosts = await User.query()
    .whereExists<Post>((postQuery) => postQuery
        .whereColumn(Post$.userId, User$.id))
    .get();

// Select specific columns
final names = await User.query()
    .select([User$.name, User$.email])
    .get();  // Returns List<User> with only name and email populated

// Distinct
final uniqueRoles = await User.query()
    .select([User$.role])
    .distinct()
    .get();
```

### 6.5 Aggregations

```dart
final count = await User.query().where(User$.isActive, true).count();
final avgAge = await User.query().avg(User$.age);
final maxCreated = await User.query().max(User$.createdAt);
final minAge = await User.query().min(User$.age);
final totalRevenue = await Order.query().sum(Order$.amount);
```

### 6.6 Aggregate Subqueries (withCount, withSum, withExists)

```dart
// Count related records as a virtual column
final users = await User.query()
    .withCount(User$.posts)              // adds postsCount to each user
    .withCount(User$.posts, alias: 'publishedPostsCount',
        filter: (q) => q.where(Post$.status, 'published'))
    .withSum(User$.posts, Post$.views)   // adds postsViewsSum
    .withExists(User$.profile)           // adds profileExists (bool)
    .orderBy(Field<int>('postsCount'), descending: true)
    .get();

print(users.first.postsCount);          // int
print(users.first.publishedPostsCount); // int
print(users.first.profileExists);       // bool
```

### 6.7 Joins (SQL-Only, Explicit Guard)

Joins are SQL-specific. Using them requires an explicit `.sql()` context to prevent accidental backend coupling:

```dart
// This compiles only for SQL adapters
final results = await User.query().sql((q) => q
    .join(Post$.table, Post$.userId, User$.id)
    .leftJoin(Profile$.table, Profile$.userId, User$.id)
    .where(Post$.status, 'published')
    .select([User$.name, Post$.title, Profile$.bio])
).get();

// Attempting .join() without .sql() context throws at compile time
```

For MongoDB, equivalent functionality is achieved via relationships and eager loading (or raw aggregation pipelines via `.mongo()` context).

### 6.8 GroupBy and Having (SQL-Only)

```dart
final stats = await Post.query().sql((q) => q
    .select([Post$.userId])
    .groupBy(Post$.userId)
    .having(Aggregate.count(), Operator.greaterThan, 5)
    .withAggregate(Aggregate.count(), alias: 'postCount')
).get();
```

### 6.9 Raw Queries (Escape Hatch, Guarded)

Raw queries require explicit opt-in to prevent injection:

```dart
// SQL raw — requires allowRaw flag
final results = await User.query()
    .whereRaw('EXTRACT(YEAR FROM created_at) = ?', [2024], allowRaw: true)
    .get();

// Fully raw query execution
final rows = await Worm.adapter('default')
    .rawQuery('SELECT * FROM users WHERE id = \$1', ['uuid-here']);

// MongoDB raw — via .mongo() context
final results = await User.query().mongo((q) => q
    .rawFilter({'\$text': {'\$search': 'flutter dart'}})
).get();
```

### 6.10 Query Introspection

```dart
// Get the SQL without executing
final sql = User.query()
    .where(User$.isActive, true)
    .orderBy(User$.createdAt, descending: true)
    .toSql();
// Returns: 'SELECT * FROM "users" WHERE "is_active" = $1 ORDER BY "created_at" DESC'

// Get the MongoDB filter without executing
final mongoFilter = User.query()
    .where(User$.isActive, true)
    .toMongoFilter();
// Returns: {'is_active': true}

// Get the database execution plan
final plan = await User.query()
    .where(User$.email, 'jane@example.com')
    .explain();
// Returns: ExplainResult with parsed execution plan, cost, index usage, etc.
```

### 6.11 Terminal Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `.get()` | `Future<List<T>>` | Execute and return all matching records |
| `.first()` | `Future<T?>` | Return first matching record or null |
| `.firstOrFail()` | `Future<T>` | Return first or throw `ModelNotFoundException` |
| `.find(id)` | `Future<T?>` | Find by primary key |
| `.findOrFail(id)` | `Future<T>` | Find or throw `ModelNotFoundException` |
| `.count()` | `Future<int>` | Count matching records |
| `.exists()` | `Future<bool>` | Whether any records match |
| `.sum(field)` | `Future<num>` | Sum of field values |
| `.avg(field)` | `Future<double>` | Average of field values |
| `.min(field)` | `Future<T>` | Minimum value |
| `.max(field)` | `Future<T>` | Maximum value |
| `.pluck(field)` | `Future<List<T>>` | Extract single field from all records |
| `.update(data)` | `Future<int>` | Bulk update matching records, return count |
| `.delete()` | `Future<int>` | Bulk delete matching records, return count |
| `.paginate(...)` | `Future<Paginator<T>>` | Paginated results with metadata |
| `.chunk(...)` | `Future<void>` | Process results in batches |
| `.stream()` | `Stream<T>` | Streaming results (cursor-based) |
| `.toSql()` | `String` | SQL string (without executing) |
| `.explain()` | `Future<ExplainResult>` | Database execution plan |

---

## 7. Relationships

### 7.1 Supported Relationship Types

| Type | Annotation | Example |
|------|-----------|---------|
| One-to-One | `@HasOne` | User has one Profile |
| One-to-One (inverse) | `@BelongsTo` | Profile belongs to User |
| One-to-Many | `@HasMany` | User has many Posts |
| Many-to-One (inverse) | `@BelongsTo` | Post belongs to User |
| Many-to-Many | `@BelongsToMany` | User belongs to many Roles |
| Has One Through | `@HasOneThrough` | Country has one Capital through Province |
| Has Many Through | `@HasManyThrough` | Country has many Doctors through Hospitals |
| Polymorphic One-to-Many | `@MorphMany` | Post/Video has many Comments |
| Polymorphic One-to-One | `@MorphOne` | Post/Video has one Image |
| Polymorphic Inverse | `@MorphTo` | Comment belongs to commentable |
| Polymorphic Many-to-Many | `@MorphToMany` | Post has many Tags (taggables) |

### 7.2 Defining Relationships

```dart
@Table(name: 'users')
class User extends Model {
  @Column()
  String name;
  
  // One-to-One
  @HasOne(() => Profile, foreignKey: 'userId')
  Profile? profile;
  
  // One-to-Many
  @HasMany(() => Post, foreignKey: 'userId')
  List<Post>? posts;
  
  // Many-to-Many with pivot data
  @BelongsToMany(
    () => Role,
    pivot: 'user_roles',
    foreignKey: 'userId',
    relatedKey: 'roleId',
    withPivot: ['assignedAt', 'assignedBy'],  // Extra pivot columns
    timestamps: true,  // pivot has created_at / updated_at
  )
  List<Role>? roles;
  
  // Has Many Through
  @HasManyThrough(
    () => Doctor,
    through: () => Hospital,
    firstKey: 'countryId',    // Hospital.countryId
    secondKey: 'hospitalId',  // Doctor.hospitalId
  )
  List<Doctor>? doctors;
}

@Table(name: 'posts')
class Post extends Model {
  @Column()
  String title;
  
  @Column()
  String content;
  
  // Many-to-One (inverse)
  @BelongsTo(() => User, foreignKey: 'userId')
  User? author;
  
  // Polymorphic One-to-Many
  @MorphMany(() => Comment, morphType: 'commentable')
  List<Comment>? comments;
  
  // Polymorphic One-to-One
  @MorphOne(() => Image, morphType: 'imageable')
  Image? featuredImage;
  
  // Polymorphic Many-to-Many
  @MorphToMany(() => Tag, pivot: 'taggables', morphType: 'taggable')
  List<Tag>? tags;
}

@Table(name: 'comments')
class Comment extends Model {
  @Column()
  String body;
  
  // Polymorphic inverse
  @MorphTo(types: {'Post': Post, 'Video': Video})
  dynamic commentable;
  
  @BelongsTo(() => User, foreignKey: 'userId')
  User? commenter;
}
```

### 7.3 Eager Loading (Preventing N+1)

```dart
// Eager load specific relations
final users = await User.query()
    .withRelations([User$.posts, User$.profile])
    .get();

// Nested eager loading (dot notation via type-safe path)
final users = await User.query()
    .withRelations([
      User$.posts.include([Post$.comments.include([Comment$.commenter])]),
      User$.roles,
    ])
    .get();

// Constrained eager loading (filter/sort within the relation)
final users = await User.query()
    .withRelation(User$.posts, (postQuery) => postQuery
        .where(Post$.status, 'published')
        .orderBy(Post$.createdAt, descending: true)
        .limit(5))
    .get();
```

### 7.4 Eager Loading Strategy

The eager loader uses a **joinless batching strategy** by default (optimal for both SQL and Mongo):

1. Fetch parent records: `SELECT * FROM users WHERE ...`
2. Collect parent IDs: `[uuid-1, uuid-2, ..., uuid-50]`
3. Batch-fetch children: `SELECT * FROM posts WHERE user_id IN ($1, $2, ..., $50)`
4. Map children back to parents in memory

This executes exactly **2 queries** regardless of parent count (vs N+1 with lazy loading).

For very large `IN` lists (>1000 IDs), the loader automatically chunks:
- PostgreSQL: multiple `WHERE IN (...)` queries with 1000-ID batches
- MongoDB: single `$in` query (Mongo handles large arrays natively)

### 7.5 Lazy Loading

Lazy loading works but is **discouraged in strict mode**:

```dart
final user = await User.find('uuid-here');
final posts = await user!.posts;  // Triggers SELECT on access
// In strict mode (preventLazyLoading: true), this throws LazyLoadingException
```

### 7.6 Relationship Manipulation

```dart
// ─── HasMany / HasOne ───
final user = await User.find('uuid');

// Associate (set foreign key)
final post = Post()..title = 'New Post';
await user!.posts.add(post);  // Sets post.userId = user.id, saves post

// Dissociate
await post.author.dissociate();  // Sets post.userId = null, saves post

// ─── BelongsToMany (Pivot) ───

// Attach roles (insert into pivot table)
await user.roles.attach([adminRole.id, editorRole.id]);

// Attach with pivot data
await user.roles.attach(adminRole.id, pivot: {
  'assignedAt': DateTime.now(),
  'assignedBy': currentUser.id,
});

// Detach roles (remove from pivot table)
await user.roles.detach([adminRole.id]);

// Sync (make the pivot match exactly this list — adds missing, removes extra)
await user.roles.sync([adminRole.id, viewerRole.id]);

// Access pivot data on loaded relation
for (final role in user.roles!) {
  print(role.pivot['assignedAt']);  // Access pivot column
  print(role.pivot['assignedBy']);
}

// ─── Polymorphic ───
final comment = Comment()..body = 'Great post!';
await post.comments.add(comment);
// Sets comment.commentableType = 'Post', comment.commentableId = post.id
```

### 7.7 Cascade Deletes

Configurable per-relationship. Default is **database-level cascading**:

```dart
// DB-level cascade (default) — handled by ON DELETE CASCADE in migration
@HasMany(() => Post, foreignKey: 'userId', onDelete: OnDelete.cascade)
List<Post>? posts;

// ORM-level cascade — Worm deletes children in application code
// (triggers lifecycle hooks on each child)
@HasMany(() => Post, foreignKey: 'userId', onDelete: OnDelete.ormCascade)
List<Post>? posts;

// Set null — sets FK to null on parent deletion
@HasMany(() => Post, foreignKey: 'userId', onDelete: OnDelete.setNull)
List<Post>? posts;

// Restrict — prevent deletion if children exist
@HasMany(() => Post, foreignKey: 'userId', onDelete: OnDelete.restrict)
List<Post>? posts;

// No action
@HasMany(() => Post, foreignKey: 'userId', onDelete: OnDelete.noAction)
List<Post>? posts;
```

When `OnDelete.ormCascade` is used, deleting a parent:
1. Loads all children
2. Fires `beforeDelete` on each child
3. Deletes children
4. Fires `afterDelete` on each child
5. Then deletes the parent

When `OnDelete.cascade` (DB-level) is used, only the parent's lifecycle hooks fire. Children are deleted by the database without ORM involvement.

---

## 8. Migration System

### 8.1 Philosophy

Migrations are version-controlled Dart files that define schema changes using Worm's fluent Schema Builder. They are **always reviewed by a human** before being applied. Even auto-generated migrations produce readable Worm DSL code (not raw SQL), placed in the `migrations/` folder for inspection and commit.

### 8.2 Migration File Structure

```
project/
├── lib/
│   └── models/
│       ├── user.dart
│       └── post.dart
├── migrations/
│   ├── 20260412_100000_create_users_table.dart
│   ├── 20260412_100001_create_posts_table.dart
│   ├── 20260412_100002_create_comments_table.dart
│   ├── 20260412_100003_create_roles_table.dart
│   ├── 20260412_100004_create_user_roles_pivot.dart
│   └── 20260415_093000_add_bio_to_users.dart
└── seeds/
    ├── database_seeder.dart
    └── user_seeder.dart
```

### 8.3 Migration Class

```dart
class CreateUsersTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('users', (table) {
      table.id();                          // UUID primary key (default)
      table.string('name').notNull();
      table.string('email').notNull().unique();
      table.boolean('is_active').defaultValue(true);
      table.string('password_hash').nullable();
      table.string('role').nullable();
      table.decimal('balance', precision: 10, scale: 2).defaultValue(0);
      table.json('metadata').nullable();
      table.timestamps();                  // created_at + updated_at
      table.softDeletes();                 // deleted_at (nullable timestamp)
      
      // Indexes
      table.index(['email']);
      table.index(['is_active', 'role']);   // Composite index
    });
  }
  
  @override
  Future<void> down(Schema schema) async {
    await schema.drop('users');
  }
}
```

### 8.4 Schema Builder API

#### Column Types

| Method | PostgreSQL | MongoDB | Dart Type |
|--------|-----------|---------|-----------|
| `table.id()` | `uuid PRIMARY KEY` | `_id: String` | `String` |
| `table.intId()` | `SERIAL PRIMARY KEY` | `_id: int` | `int` |
| `table.uuid(name)` | `uuid` | `String` | `String` |
| `table.string(name)` | `VARCHAR(255)` | `String` | `String` |
| `table.string(name, length: 500)` | `VARCHAR(500)` | `String` | `String` |
| `table.text(name)` | `TEXT` | `String` | `String` |
| `table.integer(name)` | `INTEGER` | `int` | `int` |
| `table.bigInteger(name)` | `BIGINT` | `Long` | `int` |
| `table.decimal(name, precision, scale)` | `NUMERIC(p,s)` | `Decimal128` | `Decimal` |
| `table.float(name)` | `REAL` | `double` | `double` |
| `table.double(name)` | `DOUBLE PRECISION` | `double` | `double` |
| `table.boolean(name)` | `BOOLEAN` | `bool` | `bool` |
| `table.dateTime(name)` | `TIMESTAMP` | `ISODate` | `DateTime` |
| `table.date(name)` | `DATE` | `String` | `DateTime` |
| `table.time(name)` | `TIME` | `String` | `String` |
| `table.json(name)` | `JSONB` | `Object` | `Map<String, dynamic>` |
| `table.binary(name)` | `BYTEA` | `BinData` | `List<int>` |
| `table.enumField(name, values)` | `VARCHAR` + CHECK | `String` | `String` |
| `table.timestamps()` | Two `TIMESTAMP` cols | Two `ISODate` fields | `DateTime` |
| `table.softDeletes()` | Nullable `TIMESTAMP` | Nullable `ISODate` | `DateTime?` |

#### Column Modifiers

```dart
table.string('email')
    .notNull()                    // NOT NULL
    .unique()                     // UNIQUE constraint
    .defaultValue('default')      // DEFAULT value
    .nullable()                   // Allow NULL (default unless .notNull())
    .index()                      // Create index on this column
    .comment('User email')        // Column comment (Postgres only)
    .after('name')                // Position hint (ignored by Postgres, used by MySQL later)
    ;
```

#### Foreign Keys

```dart
// Short form
table.uuid('user_id').notNull().foreign('users', 'id');

// With cascade behavior
table.uuid('user_id').notNull().foreign(
  'users', 'id',
  onDelete: 'CASCADE',
  onUpdate: 'CASCADE',
);

// Explicit foreign key constraint
table.foreign('user_id').references('id').on('users')
    .onDelete('CASCADE')
    .onUpdate('CASCADE');

// Composite foreign key
table.foreign(['tenant_id', 'user_id'])
    .references(['tenant_id', 'id']).on('users');
```

#### Indexes

```dart
table.index(['email']);                    // Simple index
table.index(['status', 'created_at']);     // Composite index
table.unique(['email']);                   // Unique index
table.unique(['tenant_id', 'email']);      // Composite unique

// Partial index (Postgres only, guarded)
table.index(['email']).sql((idx) => idx
    .where('deleted_at IS NULL')
    .name('idx_users_email_active'));
```

### 8.5 Alter Table Migrations

```dart
class AddBioToUsers extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.table('users', (table) {
      table.text('bio').nullable();
      table.string('avatar_url').nullable();
      table.dropColumn('legacy_field');
      table.renameColumn('old_name', 'new_name');
    });
  }
  
  @override
  Future<void> down(Schema schema) async {
    await schema.table('users', (table) {
      table.dropColumn('bio');
      table.dropColumn('avatar_url');
      table.string('legacy_field').nullable();
      table.renameColumn('new_name', 'old_name');
    });
  }
}
```

### 8.6 Auto-Generated Migrations

Worm can diff your model annotations against the current database schema and generate a migration file using the Worm DSL (not raw SQL). The developer reviews and commits this file like any manual migration.

```bash
# Auto-generate migration from model changes
worm make:migration --auto

# With a custom name
worm make:migration --auto --name add_avatar_to_users
```

This produces a file like `migrations/20260415_093000_add_avatar_to_users.dart` with the exact same Worm Schema Builder syntax as a manually written migration. The developer can modify it before running.

**How the diff engine works:**

1. Reads all `@Table` / `@Column` annotations from registered models
2. Connects to the database and reads the current schema (via `information_schema` for Postgres, collection inspection for Mongo)
3. Computes a diff: new tables, dropped tables, new columns, dropped columns, type changes, index changes
4. Generates a Migration class with `up()` and `down()` methods using Worm's Schema Builder

**Safety rules:**
- Auto-generated migrations are **never auto-applied**. They are only written to disk for review.
- Destructive changes (drop column, drop table) include a comment: `// DESTRUCTIVE: This will permanently delete data`
- The diff engine refuses to auto-generate if it detects ambiguity (e.g., a column rename vs drop+add — it adds a `// TODO: Is this a rename? If so, use table.renameColumn()`)

### 8.7 Migration Runner

```bash
# Apply all pending migrations
worm migrate

# Rollback the last batch
worm migrate:rollback

# Rollback N steps
worm migrate:rollback --steps=3

# Rollback all and re-run
worm migrate:refresh

# Show migration status
worm migrate:status

# Preview SQL without executing
worm migrate --pretend

# Force in production (requires explicit flag)
worm migrate --force
```

### 8.8 Migration Tracking

Worm maintains a `_worm_migrations` table (Postgres) or `_worm_migrations` collection (MongoDB):

| Column | Type | Description |
|--------|------|-------------|
| `id` | `int` | Auto-increment |
| `migration` | `string` | Migration file name |
| `batch` | `int` | Batch number (for rollback grouping) |
| `executed_at` | `timestamp` | When migration was applied |

### 8.9 Migration Dependencies

```dart
class CreatePostsTable extends Migration {
  @override
  List<Type> get dependsOn => [CreateUsersTable];
  
  @override
  Future<void> up(Schema schema) async {
    await schema.create('posts', (table) {
      table.id();
      table.uuid('user_id').notNull().foreign('users', 'id', onDelete: 'CASCADE');
      table.string('title').notNull();
      table.text('content');
      table.timestamps();
      table.softDeletes();
    });
  }
  
  @override
  Future<void> down(Schema schema) async {
    await schema.drop('posts');
  }
}
```

### 8.10 Schema Squashing

For projects with many migrations, squash all into a single schema dump:

```bash
worm schema:dump
worm schema:dump --prune  # Also removes old migration files
```

This produces `schema/schema_dump.dart` — a single migration representing the entire current schema. Future migrations run after this baseline.

---

## 9. Seeder System

### 9.1 Seeder Class

```dart
class UserSeeder extends Seeder {
  @override
  Environment get environment => Environment.all;  // Run in all environments
  
  @override
  int get order => 1;  // Execution order (lower = first)
  
  @override
  Future<void> run() async {
    // Using model API (triggers events, validation)
    await User(name: 'Admin', email: 'admin@example.com', role: 'admin').save();
    await User(name: 'Editor', email: 'editor@example.com', role: 'editor').save();
    
    // Using factory for bulk data
    await UserFactory().count(50).create();
  }
}
```

### 9.2 Environment Typing

```dart
enum Environment {
  development,
  staging,
  production,
  testing,
  all,  // Runs in every environment
}

class DemoDataSeeder extends Seeder {
  @override
  Environment get environment => Environment.development;  // Only in dev
  
  @override
  Future<void> run() async {
    await UserFactory().count(100).withRelation(Post, count: 5).create();
  }
}

class ReferenceDataSeeder extends Seeder {
  @override
  Environment get environment => Environment.all;  // Always runs
  
  @override
  Future<void> run() async {
    for (final roleName in ['admin', 'editor', 'viewer']) {
      await Role(name: roleName).save();
    }
  }
}
```

### 9.3 Master Seeder

```dart
class DatabaseSeeder extends Seeder {
  @override
  List<Type> get call => [
    ReferenceDataSeeder,  // Runs first (roles, categories, etc.)
    UserSeeder,           // Runs second (depends on roles)
    PostSeeder,           // Runs third (depends on users)
    DemoDataSeeder,       // Only in development
  ];
}
```

### 9.4 Seeder Tracking

Seeders are tracked in a `_worm_seeders` table to prevent duplicate execution:

| Column | Type | Description |
|--------|------|-------------|
| `id` | `int` | Auto-increment |
| `seeder` | `string` | Seeder class name |
| `executed_at` | `timestamp` | When seeder was run |
| `environment` | `string` | Which environment it ran in |

### 9.5 Running Seeders

```bash
# Run all seeders for current environment
worm db:seed

# Run specific seeder
worm db:seed --class=UserSeeder

# Run with environment override
worm db:seed --env=development

# Force re-run (ignore tracking)
worm db:seed --force

# Fresh: drop all, migrate, seed
worm migrate:fresh --seed
```

### 9.6 Muting Events During Seeding

```dart
class BulkDataSeeder extends Seeder {
  @override
  bool get muteEvents => true;  // Skips lifecycle hooks for performance
  
  @override
  Future<void> run() async {
    // Bulk insert without triggering beforeCreate/afterCreate on each record
    await User.query().insertMany(
      List.generate(10000, (i) => {
        'name': 'User $i',
        'email': 'user$i@example.com',
      }),
    );
  }
}
```

---

## 10. Factory System

### 10.1 Factory Definition

```dart
class UserFactory extends Factory<User> {
  @override
  User definition() {
    return User()
      ..name = faker.person.name()
      ..email = faker.internet.email()
      ..isActive = true
      ..role = faker.randomGenerator.element(['admin', 'editor', 'viewer'])
      ..passwordHash = 'hashed_password_placeholder';
  }
  
  // Named states for variations
  Factory<User> admin() => state((user) => user..role = 'admin');
  Factory<User> inactive() => state((user) => user..isActive = false);
  Factory<User> withBio() => state((user) => user
      ..fill({'bio': faker.lorem.paragraph()}));
}
```

### 10.2 Factory Usage

```dart
// Create a single user (saved to DB)
final user = await UserFactory().create();

// Create without saving (in-memory only)
final user = UserFactory().make();

// Create multiple
final users = await UserFactory().count(50).create();

// With state variations
final admin = await UserFactory().admin().create();
final inactiveUsers = await UserFactory().inactive().count(10).create();

// With relationship graphs
final usersWithPosts = await UserFactory()
    .count(20)
    .has(PostFactory().count(3), 'posts')  // Each user gets 3 posts
    .create();

// Nested relationships
final usersWithPostsAndComments = await UserFactory()
    .count(5)
    .has(
      PostFactory().count(2).has(
        CommentFactory().count(5), 'comments',
      ),
      'posts',
    )
    .create();

// With specific overrides
final user = await UserFactory().create(overrides: {
  'name': 'Specific Name',
  'email': 'specific@example.com',
});

// BelongsTo / for
final posts = await PostFactory()
    .count(10)
    .for_(existingUser, 'author')  // All posts belong to this user
    .create();

// Sequence
final users = await UserFactory()
    .count(3)
    .sequence([
      {'role': 'admin'},
      {'role': 'editor'},
      {'role': 'viewer'},
    ])
    .create();
```

### 10.3 Faker Integration

Worm bundles a Dart faker utility (wrapping the `faker_dart` package or similar):

```dart
// Available via Factory base class as `faker`
faker.person.name()           // "Jane Doe"
faker.internet.email()        // "jane42@example.com"
faker.lorem.paragraph()       // "Lorem ipsum..."
faker.address.city()          // "Vienna"
faker.date.between(start, end)  // Random DateTime in range
faker.randomGenerator.integer(100)  // Random int 0-100
faker.company.name()          // "Acme Corp"
```

---

## 11. Database Adapters

### 11.1 Adapter Interface

```dart
abstract class DatabaseAdapter {
  // Connection lifecycle
  Future<void> connect();
  Future<void> disconnect();
  bool get isConnected;
  
  // Query execution
  Future<List<Map<String, dynamic>>> select(QueryDescriptor descriptor);
  Future<Map<String, dynamic>?> selectOne(QueryDescriptor descriptor);
  Future<String> insert(InsertDescriptor descriptor);        // Returns inserted ID
  Future<List<String>> insertMany(InsertManyDescriptor descriptor);
  Future<int> update(UpdateDescriptor descriptor);           // Returns affected count
  Future<int> delete(DeleteDescriptor descriptor);           // Returns affected count
  
  // Aggregation
  Future<int> count(QueryDescriptor descriptor);
  Future<num?> sum(QueryDescriptor descriptor, String column);
  Future<num?> avg(QueryDescriptor descriptor, String column);
  Future<dynamic> min(QueryDescriptor descriptor, String column);
  Future<dynamic> max(QueryDescriptor descriptor, String column);
  
  // Raw queries
  Future<List<Map<String, dynamic>>> rawQuery(String query, [List<dynamic>? params]);
  Future<int> rawExecute(String query, [List<dynamic>? params]);
  
  // Transactions
  Future<T> transaction<T>(Future<T> Function(TransactionContext txn) action);
  bool get supportsTransactions;
  
  // Schema operations
  Future<void> executeSchema(SchemaDescriptor descriptor);
  Future<DatabaseSchema> introspectSchema();  // For auto-migration diff
  
  // Streaming
  Stream<Map<String, dynamic>> stream(QueryDescriptor descriptor, {int batchSize = 100});
  
  // Query compilation (for .toSql() / .toMongoFilter())
  String compileToString(QueryDescriptor descriptor);
  
  // Explain
  Future<ExplainResult> explain(QueryDescriptor descriptor);
  
  // Capabilities
  AdapterCapabilities get capabilities;
}

class AdapterCapabilities {
  final bool supportsJoins;
  final bool supportsTransactions;
  final bool supportsReturning;        // INSERT ... RETURNING
  final bool supportsPartialIndexes;
  final bool supportsJsonOperations;
  final bool supportsFullTextSearch;
  final bool supportsCursorPagination;
  final bool supportsSchemaAlter;      // ALTER TABLE
  final bool supportsPreparedStatements;
}
```

### 11.2 PostgreSQL Adapter (`worm_postgres`)

- Built on top of the `postgres` Dart package
- Connection pooling with configurable size
- Prepared statement caching for frequently executed queries
- Full support for: JOINs, transactions (with savepoints), RETURNING, partial indexes, JSONB operations, EXPLAIN ANALYZE, CTE (Common Table Expressions)
- Parameterized queries to prevent SQL injection (`$1`, `$2` positional params)
- UUID extension auto-creation (`CREATE EXTENSION IF NOT EXISTS "pgcrypto"`)
- Snake_case column naming in generated SQL

### 11.3 MongoDB Adapter (`worm_mongodb`)

- Built on top of the `mongo_dart` package
- Document-to-model mapping with `_id` ↔ `id` alias
- Filter compilation: Worm predicates → MongoDB filter documents
- Aggregation pipeline support for complex queries (groupBy, having, withCount)
- Index management: creation, unique, partial, TTL indexes
- Bulk write operations (ordered and unordered)
- `$in` chunking for large ID lists (>10,000 items)
- Transaction support (only on replica sets — capability-gated)
- Cursor-based streaming
- Change streams for future reactive extensions

### 11.4 Adapter-Specific Contexts

```dart
// SQL-only operations
User.query().sql((q) => q
    .join(Post$.table, Post$.userId, User$.id)
    .having(...)
);

// Mongo-only operations
User.query().mongo((q) => q
    .rawFilter({'\$text': {'\$search': 'flutter'}})
    .pipeline([{'\$unwind': '\$tags'}])
);
```

Calling `.sql()` on a MongoDB connection or `.mongo()` on a PostgreSQL connection throws `AdapterMismatchException` at runtime.

---

## 12. Events & Lifecycle Hooks

### 12.1 Lifecycle Event Sequence

```
Creating:   beforeValidate → afterValidate → beforeSave → beforeCreate → [INSERT] → afterCreate → afterSave
Updating:   beforeValidate → afterValidate → beforeSave → beforeUpdate → [UPDATE] → afterUpdate → afterSave
Deleting:   beforeDelete → [DELETE] → afterDelete
SoftDelete: beforeDelete → [UPDATE deleted_at] → afterDelete → (trashed event)
Restoring:  beforeRestore → [UPDATE deleted_at = NULL] → afterRestore
Fetching:   [SELECT] → afterHydrate (called on each model instance after hydration)
```

### 12.2 Inline Hooks (Override Methods)

```dart
@Table(name: 'users')
class User extends Model {
  @override
  void beforeCreate() {
    // Set defaults, generate tokens, etc.
    id = Uuid().v7();
  }
  
  @override
  void beforeSave() {
    // Runs for both create and update
    updatedAt = DateTime.now();
  }
  
  @override
  void afterCreate() {
    // Send welcome email, log analytics, etc.
    EventBus.fire(UserCreatedEvent(this));
  }
  
  @override
  bool beforeDelete() {
    // Return false to cancel the delete
    if (role == 'admin' && User.query().where(User$.role, 'admin').count() <= 1) {
      return false;  // Cannot delete last admin
    }
    return true;
  }
}
```

### 12.3 Observer Classes (Separation of Concerns)

```dart
class UserObserver extends Observer<User> {
  @override
  void beforeCreate(User user) {
    log.info('Creating user: ${user.email}');
  }
  
  @override
  void afterCreate(User user) {
    emailService.sendWelcome(user);
    analytics.track('user_created', {'userId': user.id});
  }
  
  @override
  void afterUpdate(User user) {
    cacheService.invalidate('user:${user.id}');
  }
  
  @override
  void afterDelete(User user) {
    searchIndex.remove('user', user.id);
  }
}

// Register in initialization
Worm.initialize(
  observers: {
    User: [UserObserver()],
    Post: [PostObserver(), SearchIndexObserver()],
  },
);
```

### 12.4 afterCommit Hooks

For operations that should only execute after the transaction is committed:

```dart
@override
void afterCreate() {
  // This fires immediately after INSERT, even within a transaction
  log.info('User created');
  
  // This fires only after the wrapping transaction commits
  afterCommit(() {
    emailService.sendWelcome(this);
  });
}
```

### 12.5 Event Cancellation

`beforeCreate`, `beforeUpdate`, `beforeDelete` can return `false` (or throw) to cancel the operation:

```dart
@override
bool beforeDelete() {
  if (hasActiveSubscription) {
    throw OperationCancelledException('Cannot delete user with active subscription');
  }
  return true;
}
```

### 12.6 Muting Events

```dart
// Mute all events for a block of code
User.withoutEvents(() async {
  await User.query().where(User$.isActive, false).delete();
});

// Mute specific event types
User.withoutEvents([EventType.afterCreate], () async {
  await bulkImportUsers(data);
});
```

---

## 13. Validation

### 13.1 Model-Level Validation Rules

```dart
@Table(name: 'users')
class User extends Model {
  @Column()
  String name;
  
  @Column()
  String email;
  
  @Column()
  int? age;
  
  @override
  Map<Field, List<ValidationRule>> get rules => {
    User$.name: [Required(), MinLength(2), MaxLength(100)],
    User$.email: [Required(), Email(), Unique()],
    User$.age: [IntegerRule(), Min(0), Max(150)],
  };
  
  // Update-specific rules (only validate dirty fields)
  @override
  Map<Field, List<ValidationRule>> get updateRules => {
    User$.email: [Email(), Unique(ignoreId: id)],
  };
}
```

### 13.2 Built-In Validation Rules

| Rule | Description |
|------|-------------|
| `Required()` | Field must not be null or empty |
| `Email()` | Valid email format |
| `MinLength(n)` | Minimum string length |
| `MaxLength(n)` | Maximum string length |
| `Min(n)` | Minimum numeric value |
| `Max(n)` | Maximum numeric value |
| `IntegerRule()` | Must be an integer |
| `Numeric()` | Must be numeric |
| `Unique()` | Must be unique in database |
| `Unique(ignoreId: id)` | Unique, excluding current record |
| `In(values)` | Must be one of provided values |
| `NotIn(values)` | Must not be one of provided values |
| `Regex(pattern)` | Must match regex pattern |
| `Url()` | Valid URL format |
| `Uuid()` | Valid UUID format |
| `Date()` | Valid date |
| `After(date)` | Date must be after given date |
| `Before(date)` | Date must be before given date |
| `Confirmed(field)` | Must match another field (e.g., password confirmation) |
| `Custom(validator)` | Custom validation function |

### 13.3 Validation Execution

Validation runs automatically before `save()`, in the `beforeValidate` / `afterValidate` lifecycle phase:

```dart
try {
  final user = User()..name = ''..email = 'invalid';
  await user.save();  // Throws ValidationException
} on ValidationException catch (e) {
  print(e.errors);
  // {
  //   'name': ['Name is required', 'Name must be at least 2 characters'],
  //   'email': ['Email must be a valid email address'],
  // }
}
```

### 13.4 Manual Validation

```dart
final user = User()..name = 'Jane'..email = 'jane@example.com';
final result = user.validate();  // Returns ValidationResult

if (result.failed) {
  print(result.errors);  // Map<String, List<String>>
}
```

### 13.5 Unique Constraint Error Mapping

When a database-level unique constraint violation occurs (e.g., duplicate email), Worm maps it to a `ValidationException` with a human-readable message, rather than exposing a raw database error:

```dart
try {
  await User(email: 'existing@example.com').save();
} on ValidationException catch (e) {
  print(e.errors['email']);  // ['A user with this email already exists']
}
```

---

## 14. Serialization

### 14.1 toJson / toMap

```dart
@Table(name: 'users')
class User extends Model {
  @Column()
  String name;
  
  @Column()
  String email;
  
  @Column(hidden: true)    // Never included in serialization
  String? passwordHash;
  
  @Column(hidden: true)
  String? rememberToken;
  
  // Computed properties (appended to serialization)
  @Appended()
  String get fullName => '$name';
  
  @Appended()
  bool get hasProfile => _relations.containsKey('profile');
}
```

### 14.2 Controlling Serialization

```dart
final user = await User.find('uuid');

// Basic serialization (respects hidden/appended)
final map = user!.toMap();
// {'id': 'uuid', 'name': 'Jane', 'email': 'jane@...', 'fullName': 'Jane', 'hasProfile': true}
// Note: passwordHash and rememberToken are NOT included

final json = user.toJson();  // JSON string

// Include relations (only if loaded)
final map = user.toMap(includeRelations: true);
// {'id': '...', 'name': 'Jane', ..., 'posts': [{...}, {...}], 'profile': {...}}

// Override visibility for a specific call
final map = user.toMap(
  visible: [User$.name, User$.email],  // Whitelist: ONLY these fields
);

final map = user.toMap(
  hidden: [User$.email],  // Additional fields to hide
);

// Depth limiting for nested relations
final map = user.toMap(includeRelations: true, maxDepth: 2);
```

### 14.3 Cycle Prevention

When serializing models with circular relationships (User → Post → User), Worm detects cycles and replaces the circular reference with just the ID:

```dart
// User has Posts, Post has User (author)
final user = await User.query().withRelations([User$.posts]).first();
final map = user!.toMap(includeRelations: true);
// {
//   'id': 'user-uuid',
//   'name': 'Jane',
//   'posts': [
//     {'id': 'post-uuid', 'title': 'Hello', 'authorId': 'user-uuid'}  // No nested User object
//   ]
// }
```

---

## 15. Scopes

### 15.1 Local Scopes

Defined on the model as static methods with `@Scope()`:

```dart
@Table(name: 'posts')
class Post extends Model {
  @Scope()
  static QueryBuilder<Post> published(QueryBuilder<Post> q) =>
      q.where(Post$.status, 'published');
  
  @Scope()
  static QueryBuilder<Post> recent(QueryBuilder<Post> q, {int days = 7}) =>
      q.where(Post$.createdAt, Operator.greaterThan,
          DateTime.now().subtract(Duration(days: days)));
  
  @Scope()
  static QueryBuilder<Post> byAuthor(QueryBuilder<Post> q, String userId) =>
      q.where(Post$.userId, userId);
}

// Usage (generated as extensions on QueryBuilder<Post>)
final posts = await Post.query()
    .published()
    .recent(days: 30)
    .byAuthor(user.id)
    .get();
```

### 15.2 Global Scopes

Applied automatically to every query on a model:

```dart
@Table(name: 'posts')
@GlobalScope(ActiveScope)
@GlobalScope(TenantScope)
class Post extends Model { ... }

class ActiveScope extends GlobalScope<Post> {
  @override
  QueryBuilder<Post> apply(QueryBuilder<Post> query) {
    return query.where(Post$.status, Operator.notEquals, 'archived');
  }
}

class TenantScope extends GlobalScope<Post> {
  @override
  QueryBuilder<Post> apply(QueryBuilder<Post> query) {
    final tenantId = TenantContext.current;
    return query.where(Post$.tenantId, tenantId);
  }
}

// Bypass global scopes
final allPosts = await Post.query().withoutGlobalScope<ActiveScope>().get();
final allAll = await Post.query().withoutGlobalScopes().get();
```

---

## 16. Soft Deletes

### 16.1 Opt-In via Mixin

```dart
@Table(name: 'posts')
class Post extends Model with SoftDeletes {
  // SoftDeletes mixin adds:
  // - DateTime? deletedAt field
  // - Global scope that excludes deleted records from all queries
  // - delete() performs soft delete (sets deletedAt)
  // - forceDelete() performs actual DELETE
  // - restore() sets deletedAt back to null
  // - withTrashed(), onlyTrashed() scope methods
}
```

### 16.2 Usage

```dart
// Regular queries automatically exclude soft-deleted records
final posts = await Post.query().get();  // Only non-deleted

// Include soft-deleted
final allPosts = await Post.query().withTrashed().get();

// Only soft-deleted
final trashedPosts = await Post.query().onlyTrashed().get();

// Soft delete
await post.delete();  // Sets deletedAt = now, does NOT remove from DB

// Restore
await post.restore();  // Sets deletedAt = null

// Permanently delete
await post.forceDelete();  // Actually removes from DB

// Check status
if (post.isTrashed) { ... }
```

### 16.3 Migration Support

The `table.softDeletes()` helper adds a nullable `deleted_at` timestamp column. For PostgreSQL, a partial unique index can be auto-generated to enforce uniqueness only among non-deleted records:

```dart
// In migration
table.softDeletes();
table.unique(['email']).sql((idx) => idx.where('deleted_at IS NULL'));
```

---

## 17. Pagination & Chunking

### 17.1 Offset Pagination

```dart
final page = await User.query()
    .where(User$.isActive, true)
    .orderBy(User$.createdAt, descending: true)
    .paginate(page: 2, perPage: 20);

print(page.items);        // List<User> for this page
print(page.total);        // Total record count
print(page.currentPage);  // 2
print(page.lastPage);     // e.g., 5
print(page.perPage);      // 20
print(page.hasNextPage);  // true
print(page.hasPrevPage);  // true
print(page.nextPage);     // 3
print(page.prevPage);     // 1

// Serialize for API response
final json = page.toMap();
// {
//   'data': [...],
//   'meta': {'total': 100, 'perPage': 20, 'currentPage': 2, 'lastPage': 5}
// }
```

### 17.2 Cursor Pagination

For high-performance pagination (especially MongoDB):

```dart
final firstPage = await User.query()
    .orderBy(User$.createdAt, descending: true)
    .cursorPaginate(perPage: 20);

// Next page using cursor
final secondPage = await User.query()
    .orderBy(User$.createdAt, descending: true)
    .cursorPaginate(perPage: 20, after: firstPage.nextCursor);

print(secondPage.items);       // List<User>
print(secondPage.nextCursor);  // Opaque cursor string for next page
print(secondPage.prevCursor);  // Opaque cursor string for previous page
print(secondPage.hasMore);     // bool
```

### 17.3 Chunking

```dart
// Callback-based chunking
await User.query()
    .where(User$.isActive, true)
    .chunk(500, (List<User> batch) async {
      for (final user in batch) {
        await processUser(user);
      }
      // Return false to stop processing early
      return true;
    });

// Stream-based chunking
await for (final batch in User.query().streamChunks(500)) {
  // batch is List<User> of up to 500
  await processBatch(batch);
}

// Item-by-item streaming
await for (final user in User.query().stream()) {
  await processUser(user);
}
```

---

## 18. Transactions

### 18.1 Basic Transactions

```dart
await Worm.transaction((txn) async {
  final user = User()
    ..name = 'Jane'
    ..email = 'jane@example.com';
  await user.save(transaction: txn);
  
  final post = Post()
    ..title = 'First Post'
    ..userId = user.id;
  await post.save(transaction: txn);
  
  // If anything throws, both operations are rolled back
});
```

### 18.2 Return Values from Transactions

```dart
final user = await Worm.transaction((txn) async {
  final user = User()..name = 'Jane';
  await user.save(transaction: txn);
  return user;
});
```

### 18.3 Savepoints (PostgreSQL Only)

```dart
await Worm.transaction((txn) async {
  await user.save(transaction: txn);
  
  try {
    await txn.savepoint(() async {
      await riskyOperation(txn);  // If this fails...
    });
  } catch (e) {
    // ...only the savepoint is rolled back, not the whole transaction
    log.warning('Risky operation failed, continuing: $e');
  }
  
  await anotherOperation(txn);  // This still succeeds
});
```

### 18.4 MongoDB Transaction Handling

Transactions on MongoDB require a replica set. Worm's MongoDB adapter checks `supportsTransactions` capability:

```dart
if (Worm.adapter('mongo').supportsTransactions) {
  await Worm.transaction((txn) async { ... }, connection: 'mongo');
} else {
  // Fallback: execute operations without transaction wrapping
  // Log a warning if in strict mode
}
```

---

## 19. CLI Tool

### 19.1 Installation

```bash
dart pub global activate worm
```

After activation, all commands are available globally as `worm <command>`.

### 19.2 Command Reference

| Command | Description |
|---------|-------------|
| `worm init` | Initialize Worm in a Dart project (creates `migrations/`, `seeds/`, config) |
| `worm make:model <Name>` | Generate a model class |
| `worm make:model <Name> --migration` | Generate model + migration |
| `worm make:model <Name> --migration --seeder --factory` | Generate model + migration + seeder + factory |
| `worm make:model <Name> --all` | Generate model + migration + seeder + factory |
| `worm make:migration <name>` | Generate an empty migration |
| `worm make:migration --auto` | Auto-generate migration from model diff |
| `worm make:migration --auto --name <name>` | Auto-generate with custom name |
| `worm make:seeder <Name>` | Generate a seeder class |
| `worm make:factory <Name>` | Generate a factory class |
| `worm make:observer <Name>` | Generate an observer class |
| `worm migrate` | Run all pending migrations |
| `worm migrate:rollback` | Rollback last migration batch |
| `worm migrate:rollback --steps=N` | Rollback N steps |
| `worm migrate:refresh` | Rollback all and re-run |
| `worm migrate:fresh` | Drop all tables and re-run |
| `worm migrate:status` | Show migration status |
| `worm migrate --pretend` | Show SQL without executing |
| `worm db:seed` | Run seeders |
| `worm db:seed --class=<Name>` | Run specific seeder |
| `worm db:seed --env=<env>` | Run for specific environment |
| `worm schema:dump` | Dump current schema |
| `worm schema:dump --prune` | Dump and remove old migrations |
| `worm gen` | Run code generation (macros/build_runner) |
| `worm model:show <Name>` | Display model schema, fields, relations |

### 19.3 Generated File Templates

`worm make:model User --all` generates:

```
lib/models/user.dart          # Model class with annotations
migrations/20260412_..._create_users_table.dart  # Migration
seeds/user_seeder.dart         # Seeder
lib/factories/user_factory.dart  # Factory
```

---

## 20. Logging & Debugging

### 20.1 Query Logging

```dart
// In WormConfig
logging: LogConfig(
  enabled: true,
  level: LogLevel.debug,        // debug, info, warning, error
  file: 'logs/worm.log',        // File on disk (null = stdout only)
  slowQueryThreshold: Duration(milliseconds: 200),
  logQueryParameters: true,     // Include param values (disable in prod!)
  formatQueries: true,          // Pretty-print SQL
),
```

### 20.2 Log Output Format

```
[2026-04-12 14:30:01.234] [QUERY] SELECT * FROM "users" WHERE "is_active" = $1 ORDER BY "created_at" DESC LIMIT 20 | params: [true] | 3.2ms
[2026-04-12 14:30:01.238] [QUERY] SELECT * FROM "posts" WHERE "user_id" IN ($1, $2, $3, ...) | params: [uuid-1, uuid-2, ...] | 5.1ms
[2026-04-12 14:30:02.100] [SLOW QUERY] SELECT COUNT(*) FROM "posts" WHERE ... | 203ms (threshold: 200ms)
[2026-04-12 14:30:03.000] [ERROR] UniqueConstraintException on "users.email": duplicate key value
```

### 20.3 Programmatic Query Inspection

```dart
// Get SQL without executing
final sql = User.query().where(User$.isActive, true).toSql();

// Get execution plan
final plan = await User.query().where(User$.email, 'jane@example.com').explain();
print(plan.usesIndex);      // true
print(plan.indexName);       // 'idx_users_email'
print(plan.estimatedCost);   // 1.23
print(plan.estimatedRows);   // 1
print(plan.raw);             // Raw EXPLAIN ANALYZE output

// Temporary debug logging for a single query
final users = await User.query()
    .where(User$.isActive, true)
    .debug()  // Logs this specific query regardless of global setting
    .get();
```

---

## 21. Strictness Mode

### 21.1 Configuration

```dart
StrictnessConfig(
  preventLazyLoading: true,
  preventFullTableScans: true,
  preventSilentMassAssign: true,
  logN1Warnings: true,
  warnOnMissingIndex: true,
)
```

### 21.2 Behaviors

| Setting | Trigger | Effect |
|---------|---------|--------|
| `preventLazyLoading` | Accessing a relation that wasn't eager-loaded | Throws `LazyLoadingException` |
| `preventFullTableScans` | `.delete()` or `.update()` without any `.where()` | Throws `DangerousQueryException` |
| `preventSilentMassAssign` | `.fill()` with guarded fields | Throws `MassAssignmentException` |
| `logN1Warnings` | Multiple sequential single-record queries for same model | Logs warning with suggestion to use eager loading |
| `warnOnMissingIndex` | Query on a column without an index (via EXPLAIN) | Logs warning suggesting index creation |

### 21.3 Unsafe Escape Hatch

```dart
// Explicitly allow dangerous operations
Worm.unsafe(() async {
  await User.query().delete();  // Allowed: delete all users
  await Post.query().withTrashed().delete();  // Allowed
});
```

---

## 22. Performance

### 22.1 Built-In Optimizations

- **Dirty tracking**: `save()` on existing models generates `UPDATE` with only changed columns
- **Batched eager loading**: 2 queries instead of N+1 for any relationship depth
- **`IN` chunking**: Large `WHERE IN` lists auto-split into 1000-item batches (Postgres)
- **Connection pooling**: Reuses connections across queries
- **Prepared statement caching**: Frequently executed query patterns reuse prepared statements
- **Streaming cursors**: `stream()` and `chunk()` use DB cursors, not `OFFSET` pagination
- **Lazy hydration**: Fields can be hydrated on access (not on fetch) for large models
- **Concurrent relation loading**: Independent relations fetched in parallel via `Future.wait`

### 22.2 Query Optimization Hints

```dart
// Only fetch needed columns
final names = await User.query().select([User$.name, User$.email]).get();

// Use cursor pagination instead of offset for deep pages
final page = await User.query().cursorPaginate(perPage: 20, after: cursor);

// Bulk operations bypass model hydration
await User.query().where(User$.isActive, false).update({'role': 'inactive'});
```

---

## 23. Error Handling

### 23.1 Exception Hierarchy

```
WormException (base)
├── ConnectionException          // Cannot connect to database
│   ├── ConnectionTimeoutException
│   └── AuthenticationException
├── QueryException               // Query execution failed
│   ├── UniqueConstraintException   // Duplicate key
│   ├── ForeignKeyException         // FK violation
│   ├── CheckConstraintException    // CHECK violation
│   └── SyntaxException             // Invalid SQL/query
├── ModelException               // Model-level errors
│   ├── ModelNotFoundException      // find() returned null when expected
│   ├── MassAssignmentException     // Guarded field in fill()
│   ├── ValidationException         // Validation rules failed
│   └── LazyLoadingException        // Lazy load in strict mode
├── MigrationException           // Migration errors
│   ├── MigrationLockException      // Another process is migrating
│   └── IrreversibleMigrationException  // down() not implemented
├── AdapterException             // Adapter-specific errors
│   ├── AdapterMismatchException    // Using .sql() on Mongo
│   └── UnsupportedOperationException // Feature not supported by adapter
├── DangerousQueryException      // delete/update without WHERE in strict mode
└── OperationCancelledException  // Lifecycle hook cancelled operation
```

### 23.2 Error Context

All exceptions include query context for debugging (sanitized — no parameter values in production):

```dart
try {
  await user.save();
} on UniqueConstraintException catch (e) {
  print(e.table);       // 'users'
  print(e.column);      // 'email'
  print(e.message);     // 'Duplicate key value violates unique constraint "users_email_unique"'
  print(e.query);       // 'INSERT INTO "users" ...' (sanitized in prod)
}
```

---

## 24. Testing Strategy

### 24.1 Test Tiers

1. **Core Unit Tests** (fast, no DB, every commit)
   - QueryBuilder → Descriptor correctness (golden snapshots)
   - PredicateTree boolean logic
   - Model dirty tracking, timestamps, defaults
   - Scope composition
   - Serialization (hidden/visible/appends/cycles)
   - Cast round-trips
   - Validation rule execution
   - Event ordering and cancellation

2. **Adapter Contract Tests** (DB required, PR gate)
   - Same test suite run against PostgresAdapter and MongoAdapter
   - CRUD parity, query parity, relationship parity, transaction contract, error mapping
   - Ensures any adapter produces identical behavior for the same model code

3. **Adapter Integration Tests** (DB-specific)
   - Postgres: migrations, FK constraints, partial indexes, EXPLAIN, concurrent upsert
   - Mongo: index idempotency, bulk write, cursor streaming, ObjectId mapping

4. **E2E Workflow Tests** (CLI + codegen + migrate + seed + query)
   - Generate a mini project, run `worm gen`, `worm migrate`, `worm db:seed`, execute queries, verify

5. **Performance Regression Tests** (nightly)
   - Hydrate 10k models (time + memory budget)
   - Eager load 1k parents + 5k children (query count ≤ 2)
   - Stream 50k rows (bounded memory)
   - withCount on 1k parents (single grouped query)

### 24.2 Test Harness

```dart
abstract class AdapterTestHarness {
  DatabaseAdapter get adapter;
  Future<void> setUp();     // Create test DB / collections
  Future<void> tearDown();  // Drop everything
  Future<void> migrate();   // Run test migrations
}

class PostgresTestHarness extends AdapterTestHarness { ... }
class MongoTestHarness extends AdapterTestHarness { ... }

// Run contract tests for each adapter
void main() {
  group('Postgres', () => runContractTests(PostgresTestHarness()));
  group('MongoDB', () => runContractTests(MongoTestHarness()));
}
```

### 24.3 Testing Utilities for Users

```dart
// In-memory adapter for unit tests (no DB needed)
Worm.initialize(adapters: {'default': InMemoryAdapter()});

// Database transactions for test isolation
// Each test runs in a transaction that is rolled back after
setUp(() => Worm.beginTestTransaction());
tearDown(() => Worm.rollbackTestTransaction());

// Factory integration
test('user can publish post', () async {
  final user = await UserFactory().create();
  final post = await PostFactory().for_(user, 'author').create();
  
  await post.publish();
  
  expect(post.status, 'published');
  expect(post.publishedAt, isNotNull);
});
```

---

## 25. Naming Conventions

### 25.1 Summary Table

| Context | Convention | Example |
|---------|-----------|---------|
| Dart model class | PascalCase | `User`, `BlogPost` |
| Dart field name | camelCase | `firstName`, `isActive`, `createdAt` |
| Database table name | snake_case, plural | `users`, `blog_posts` |
| Database column name | snake_case | `first_name`, `is_active`, `created_at` |
| Foreign key column | snake_case, `<model>_id` | `user_id`, `blog_post_id` |
| Pivot table | snake_case, alphabetical, singular | `role_user` |
| Migration file | timestamp + snake_case | `20260412_100000_create_users_table.dart` |
| Migration class | PascalCase | `CreateUsersTable` |
| Seeder class | PascalCase + Seeder | `UserSeeder` |
| Factory class | PascalCase + Factory | `UserFactory` |
| Observer class | PascalCase + Observer | `UserObserver` |
| Generated companion | PascalCase + `$` | `User$` |
| CLI commands | kebab-case with colon | `make:model`, `migrate:rollback` |

### 25.2 Auto-Conversion Rules

- Dart `camelCase` ↔ DB `snake_case`: automatic, bidirectional
- Model class `User` → table `users` (pluralized, lowercased, snake_cased)
- Model class `BlogPost` → table `blog_posts`
- Dart `userId` → DB `user_id`
- Pivot table from `User` + `Role` → `role_user` (alphabetical order, singular)
- Polymorphic type column stores model class name: `'Post'`, `'Video'`

### 25.3 Override Convention

Any auto-derived name can be overridden with an explicit annotation parameter:

```dart
@Table(name: 'app_users')  // Override table name
class User extends Model {
  @Column(name: 'usr_email')  // Override column name
  String email;
  
  @BelongsToMany(() => Role, pivot: 'custom_pivot_table')  // Override pivot name
  List<Role>? roles;
}
```

---

## Appendix A: Quick Reference — Complete Model Example

```dart
@WormModel()
@Table(name: 'users')
class User extends Model with SoftDeletes {
  @Column()
  String name;
  
  @Column(unique: true)
  String email;
  
  @Column(defaultValue: true)
  bool isActive;
  
  @Column(guarded: true)
  String? role;
  
  @Column(hidden: true)
  String? passwordHash;
  
  @Column(cast: DecimalCast(precision: 10, scale: 2))
  Decimal? balance;
  
  @Column()
  Map<String, dynamic>? metadata;
  
  // ─── Accessors / Mutators ───
  String get displayName => name.toUpperCase();
  set password(String plain) => passwordHash = hashPassword(plain);
  
  // ─── Relationships ───
  @HasMany(() => Post, foreignKey: 'userId', onDelete: OnDelete.cascade)
  List<Post>? posts;
  
  @HasOne(() => Profile, foreignKey: 'userId')
  Profile? profile;
  
  @BelongsToMany(() => Role, pivot: 'role_user', foreignKey: 'userId',
      relatedKey: 'roleId', withPivot: ['assignedAt'], timestamps: true)
  List<Role>? roles;
  
  // ─── Scopes ───
  @Scope()
  static QueryBuilder<User> active(QueryBuilder<User> q) =>
      q.where(User$.isActive, true);
  
  // ─── Validation ───
  @override
  Map<Field, List<ValidationRule>> get rules => {
    User$.name: [Required(), MinLength(2), MaxLength(100)],
    User$.email: [Required(), Email(), Unique()],
  };
  
  // ─── Serialization ───
  @Appended()
  int get postsCount => posts?.length ?? 0;
}
```

## Appendix B: Quick Reference — Complete Query Examples

```dart
// ─── CRUD ───
final user = User()..name = 'Jane'..email = 'jane@example.com';
await user.save();                                     // INSERT
user.name = 'Jane Smith';
await user.save();                                     // UPDATE (only name)
await user.delete();                                   // Soft delete
await user.restore();                                  // Restore
await user.forceDelete();                              // Hard delete

// ─── Querying ───
final all = await User.query().get();
final one = await User.find('uuid');
final active = await User.query().active().get();
final admins = await User.query()
    .where(User$.role, 'admin')
    .where(User$.isActive, true)
    .orderBy(User$.createdAt, descending: true)
    .limit(10)
    .get();

// ─── Complex Queries ───
final results = await Post.query()
    .where(Post$.status.whereIn(['published', 'draft']))
    .whereGroup((q) => q
        .where(Post$.title.contains('Flutter'))
        .orWhere(Post$.content.contains('Dart')))
    .withRelations([Post$.author, Post$.comments])
    .withCount(Post$.comments)
    .orderBy(Post$.createdAt, descending: true)
    .paginate(page: 1, perPage: 20);

// ─── Aggregations ───
final count = await User.query().active().count();
final avgBalance = await User.query().avg(User$.balance);

// ─── Bulk Operations ───
await User.query().where(User$.isActive, false).update({'role': 'inactive'});
await User.query().where(User$.deletedAt.isNotNull()).forceDelete();

// ─── Transactions ───
await Worm.transaction((txn) async {
  final user = await UserFactory().create(transaction: txn);
  await PostFactory().count(3).for_(user, 'author').create(transaction: txn);
});
```
