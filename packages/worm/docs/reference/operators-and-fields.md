---
title: Operators and fields
description: Complete reference for typed fields, every operator extension, the Operator enum, and the predicate tree.
---

Every typed field class, every operator extension method, the full `Operator` enum with its long-form aliases, and the sealed `PredicateTree` hierarchy. For how these plug into a query, read [query basics](../queries/query-basics.md).

All symbols on this page are exported from `package:worm/worm.dart`. Code generation emits field constants for you (for example `User$.age` as a `ComparableField<int>`); hand-written `const` fields work identically.

## Mini-index

| Symbol | One-liner |
| --- | --- |
| [Field](#field) | Typed column reference; equality and null operators |
| [ComparableField](#comparablefield) | Orderable column; adds range operators |
| [StringField](#stringfield) | Text column; adds LIKE-family operators |
| [FieldOperators](#fieldoperators) | `eq neq isNull isNotNull inList notInList whereIn whereNotIn` |
| [ComparableFieldOperators](#comparablefieldoperators) | `gt gte lt lte between notBetween` |
| [StringFieldOperators](#stringfieldoperators) | `like notLike ilike contains startsWith endsWith` |
| [Operator](#operator) | 15-value comparison enum plus 6 long-form aliases |
| [Predicate](#predicate) | Single WHERE-clause value object |
| [PredicateTree](#predicatetree) | Sealed boolean composition tree |
| [LeafNode](#leafnode) | One predicate |
| [AndNode](#andnode) | AND of two sub-trees |
| [OrNode](#ornode) | OR of two sub-trees |
| [NotNode](#notnode) | Negation of a sub-tree |
| [GroupNode](#groupnode) | Parenthesized sub-tree |
| [ExistsNode](#existsnode) | EXISTS / NOT EXISTS subquery |
| [ColumnNode](#columnnode) | Column-to-column comparison |
| [RawNode](#rawnode) | Raw SQL escape hatch |
| [RelationField](#relationfield) | Typed reference to a relation by name |
| [RelationPath](#relationpath) | Dot-joined nested relation path |
| [RelationLoadSpec](#relationloadspec) | Typedef alias for `RelationPath` |

## Field classes

### Field

**Signature**

```dart
final class Field<T> {
  const Field(String name, {String? tableName});
  final String name;
  final String? tableName;
}
```

**Example**

```dart
const isActive = Field<bool>('is_active');
final users = await User.query().where(isActive.eq(true)).get();
```

`T` is the Dart type of the column value. `tableName` is an optional qualifier for joins and multi-table queries. Equality and `hashCode` compare `name` and `tableName`.

**Gotchas**

- A plain `Field<T>` only gets the universal operators (`eq`, `neq`, null checks, list membership). Range and text operators are compile errors by design; use [ComparableField](#comparablefield) or [StringField](#stringfield).
- `name` is the database column name (usually snake_case), not the Dart property name.

**Related:** [FieldOperators](#fieldoperators), [query basics](../queries/query-basics.md), [code generation](../models/code-generation.md)

### ComparableField

**Signature**

```dart
final class ComparableField<T> extends Field<T> {
  const ComparableField(String name, {String? tableName});
}
```

**Example**

```dart
const age = ComparableField<int>('age');
final adults = await User.query().where(age.gte(18)).get();
```

A field whose values support ordering. Adds `gt`, `gte`, `lt`, `lte`, `between`, `notBetween` on top of the universal operators.

**Gotchas**

- The code generator infers this kind for `int`, `double`, `num`, and `DateTime` columns; everything except those and `String` becomes a plain `Field<T>`.

**Related:** [ComparableFieldOperators](#comparablefieldoperators), [annotations: FieldKind inference](./annotations.md#fieldkind-inference)

### StringField

**Signature**

```dart
final class StringField extends Field<String> {
  const StringField(String name, {String? tableName});
}
```

**Example**

```dart
const name = StringField('name');
final matches = await User.query().where(name.startsWith('Al')).get();
```

A `String` column. Adds the LIKE family (`like`, `notLike`, `ilike`, `contains`, `startsWith`, `endsWith`) on top of the universal operators.

**Gotchas**

- `StringField` is not generic; it fixes `T` to `String`.
- Sorting on a `StringField` works everywhere (`orderBy` accepts any `Field`), but range operators like `gt` need a `ComparableField<String>` if you really want lexicographic comparison.

**Related:** [StringFieldOperators](#stringfieldoperators)

## Operator extensions

Every method below returns a `PredicateTree`, ready for `where(...)` or boolean composition.

### FieldOperators

**Signature**

```dart
extension FieldOperators<T> on Field<T>
```

| Method | Signature | Compiles to |
| --- | --- | --- |
| `eq` | `PredicateTree eq(T value)` | `Operator.eq` (`=`) |
| `neq` | `PredicateTree neq(T value)` | `Operator.neq` (`!=`) |
| `isNull` | `PredicateTree isNull()` | `Operator.isNull` (`IS NULL`) |
| `isNotNull` | `PredicateTree isNotNull()` | `Operator.isNotNull` (`IS NOT NULL`) |
| `inList` | `PredicateTree inList(List<T> values)` | `Operator.inList` (`IN (...)`) |
| `notInList` | `PredicateTree notInList(List<T> values)` | `Operator.notInList` (`NOT IN (...)`) |
| `whereIn` | `PredicateTree whereIn(List<T> values)` | Alias; forwards to `inList` |
| `whereNotIn` | `PredicateTree whereNotIn(List<T> values)` | Alias; forwards to `notInList` |

**Example**

```dart
const status = Field<String>('status');
final tree = status.inList(['active', 'trial']);
// identical output:
final same = status.whereIn(['active', 'trial']);
```

**Gotchas**

- `whereIn` / `whereNotIn` are the only long-form extension aliases. They produce byte-identical predicate trees to `inList` / `notInList`.
- `isNull()` and `isNotNull()` take no arguments and carry a `null` operand in the resulting `Predicate`.

**Related:** [Operator](#operator), [PredicateTree](#predicatetree)

### ComparableFieldOperators

**Signature**

```dart
extension ComparableFieldOperators<T> on ComparableField<T>
```

| Method | Signature | Compiles to |
| --- | --- | --- |
| `gt` | `PredicateTree gt(T value)` | `Operator.gt` (`>`) |
| `gte` | `PredicateTree gte(T value)` | `Operator.gte` (`>=`) |
| `lt` | `PredicateTree lt(T value)` | `Operator.lt` (`<`) |
| `lte` | `PredicateTree lte(T value)` | `Operator.lte` (`<=`) |
| `between` | `PredicateTree between(T lower, T upper)` | `Operator.between` (`BETWEEN`) |
| `notBetween` | `PredicateTree notBetween(T lower, T upper)` | `Operator.notBetween` (`NOT BETWEEN`) |

**Example**

```dart
const age = ComparableField<int>('age');
final range = age.between(18, 65); // inclusive on both ends
```

**Gotchas**

- `between` is inclusive on both bounds, matching SQL `BETWEEN`.
- The two bounds travel as a single `(lower, upper)` record in `Predicate.value`.

**Related:** [Predicate](#predicate), [advanced queries](../queries/advanced-queries.md)

### StringFieldOperators

**Signature**

```dart
extension StringFieldOperators on StringField
```

| Method | Signature | Compiles to |
| --- | --- | --- |
| `like` | `PredicateTree like(String pattern)` | `Operator.like` (`LIKE`) |
| `notLike` | `PredicateTree notLike(String pattern)` | `Operator.notLike` (`NOT LIKE`) |
| `ilike` | `PredicateTree ilike(String pattern)` | `Operator.ilike` (case-insensitive `LIKE`) |
| `contains` | `PredicateTree contains(String substring)` | `Operator.like` with `'%substring%'` |
| `startsWith` | `PredicateTree startsWith(String prefix)` | `Operator.like` with `'prefix%'` |
| `endsWith` | `PredicateTree endsWith(String suffix)` | `Operator.like` with `'%suffix'` |

**Example**

```dart
const email = StringField('email');
final corp = await User.query().where(email.endsWith('@example.com')).get();
```

**Gotchas**

- `contains`, `startsWith`, and `endsWith` are sugar over `Operator.like`: they wrap your input in `%` wildcards. Literal `%` or `_` characters inside the input are not escaped and keep their LIKE wildcard meaning.
- `like`, `notLike`, and `ilike` pass your pattern through verbatim; you supply the wildcards.

**Related:** [Operator](#operator), [security guide](../guides/security.md)

## The Operator enum

### Operator

**Signature**

```dart
enum Operator {
  eq, neq, gt, gte, lt, lte,
  like, notLike, ilike,
  isNull, isNotNull,
  inList, notInList,
  between, notBetween;
}
```

**Values**

| Value | Meaning | Produced by |
| --- | --- | --- |
| `eq` | `=` | `field.eq(v)`, `where(field, v)` |
| `neq` | `!=` | `field.neq(v)` |
| `gt` | `>` | `field.gt(v)` |
| `gte` | `>=` | `field.gte(v)` |
| `lt` | `<` | `field.lt(v)` |
| `lte` | `<=` | `field.lte(v)` |
| `like` | `LIKE` | `field.like(p)`, `contains`, `startsWith`, `endsWith` |
| `notLike` | `NOT LIKE` | `field.notLike(p)` |
| `ilike` | case-insensitive `LIKE` | `field.ilike(p)` |
| `isNull` | `IS NULL` | `field.isNull()` |
| `isNotNull` | `IS NOT NULL` | `field.isNotNull()` |
| `inList` | `IN (...)` | `field.inList(vs)`, `field.whereIn(vs)` |
| `notInList` | `NOT IN (...)` | `field.notInList(vs)`, `field.whereNotIn(vs)` |
| `between` | `BETWEEN` | `field.between(lo, hi)` |
| `notBetween` | `NOT BETWEEN` | `field.notBetween(lo, hi)` |

**Long-form aliases** (static constants on the enum, resolving to the identical instance):

| Alias | Canonical |
| --- | --- |
| `Operator.equals` | `Operator.eq` |
| `Operator.notEquals` | `Operator.neq` |
| `Operator.greaterThan` | `Operator.gt` |
| `Operator.greaterThanOrEqualTo` | `Operator.gte` |
| `Operator.lessThan` | `Operator.lt` |
| `Operator.lessThanOrEqualTo` | `Operator.lte` |

**Example**

```dart
const age = ComparableField<int>('age');
final seniors = await User.query().where(age, Operator.gte, 65).get();
// Operator.greaterThanOrEqualTo is the same object:
assert(identical(Operator.equals, Operator.eq));
```

**Gotchas**

- Only the six comparison operators have long-form aliases. There is no `Operator.notIn`, `Operator.isNullCheck`, or similar; use the canonical names for the rest.
- The aliases are `static const` references, not separate enum values: `Operator.values.length` is 15, and `switch` statements over `Operator` need only the 15 canonical cases.

**Related:** [query basics](../queries/query-basics.md), [Predicate](#predicate)

## Predicates

### Predicate

**Signature**

```dart
final class Predicate {
  const Predicate({
    required String fieldName,
    required Operator operator,
    String? tableName,
    Object? value,
  });
  String get qualifiedName;
  Map<String, Object?> toMap();
}
```

**Example**

```dart
const p = Predicate(
  fieldName: 'age',
  operator: Operator.gte,
  value: 18,
);
print(p.qualifiedName); // 'age' (or 'users.age' with tableName)
```

The immutable value object inside every [LeafNode](#leafnode). Adapters consume it when compiling a query.

**Gotchas**

- `value` shapes vary by operator: a `(lower, upper)` record for `between` / `notBetween`, a `List` for `inList` / `notInList`, `null` for `isNull` / `isNotNull`, and the right-hand scalar otherwise.
- `toMap()` omits the `value` key for `isNull` / `isNotNull` and encodes records as `{'lower': ..., 'upper': ...}` for stable golden snapshots.

**Related:** [LeafNode](#leafnode), [adapter API](./adapter-api.md)

### PredicateTree

**Signature**

```dart
sealed class PredicateTree {
  PredicateTree and(PredicateTree other);
  PredicateTree or(PredicateTree other);
  PredicateTree not();
  PredicateTree group();
  Map<String, Object?> toMap();
}
```

**Example**

```dart
const name = StringField('name');
const age = ComparableField<int>('age');

// (name = 'Alice' OR name = 'Bob') AND age >= 18
final tree = name.eq('Alice').or(name.eq('Bob')).group().and(age.gte(18));
final rows = await User.query().where(tree).get();
```

The sealed root of the boolean composition tree. Field operator extensions produce leaves; the four combinators build the structure; adapters pattern-match over the eight subtypes.

**Gotchas**

- The tree is immutable: each combinator returns a new node wrapping the operands.
- `QueryBuilder.whereGroup((q) => ...)` is the fluent alternative to manual `.group()` calls.
- Because the class is `sealed`, exhaustive `switch` over the subtypes is checked by the compiler. Third-party code cannot add subtypes.

**Related:** [query basics](../queries/query-basics.md), [advanced queries](../queries/advanced-queries.md)

### LeafNode

**Signature**

```dart
final class LeafNode extends PredicateTree {
  const LeafNode(Predicate predicate);
}
```

**Example**

```dart
const tree = LeafNode(
  Predicate(fieldName: 'age', operator: Operator.gte, value: 18),
);
```

**Gotchas**

- You rarely construct one by hand; every field operator method returns a `LeafNode`.

**Related:** [Predicate](#predicate), [FieldOperators](#fieldoperators)

### AndNode

**Signature**

```dart
final class AndNode extends PredicateTree {
  const AndNode(PredicateTree left, PredicateTree right);
}
```

**Example**

```dart
final tree = age.gte(18).and(name.eq('Alice')); // AndNode
```

**Gotchas**

- Chained `where(...)` calls on a builder also AND their trees together; you don't need explicit `AndNode`s for the common case.

**Related:** [PredicateTree](#predicatetree)

### OrNode

**Signature**

```dart
final class OrNode extends PredicateTree {
  const OrNode(PredicateTree left, PredicateTree right);
}
```

**Example**

```dart
final tree = name.eq('Alice').or(name.eq('Bob')); // OrNode
```

**Gotchas**

- OR binds the two sub-trees as written; add `.group()` (or use `whereGroup`) when mixing OR with subsequent ANDs to control precedence.

**Related:** [GroupNode](#groupnode)

### NotNode

**Signature**

```dart
final class NotNode extends PredicateTree {
  const NotNode(PredicateTree child);
}
```

**Example**

```dart
final tree = status.eq('archived').not(); // NotNode
```

**Gotchas**

- On MongoDB, NOT compiles to `$nor`; behavior is equivalent.

**Related:** [PredicateTree](#predicatetree)

### GroupNode

**Signature**

```dart
final class GroupNode extends PredicateTree {
  const GroupNode(PredicateTree child);
}
```

**Example**

```dart
final grouped = name.eq('Alice').or(name.eq('Bob')).group();
```

**Gotchas**

- `whereGroup` runs its inner builder with global scopes disabled so scope predicates don't leak into the parentheses; the outer builder still applies them.

**Related:** [OrNode](#ornode), [scopes](../queries/scopes.md)

### ExistsNode

**Signature**

```dart
final class ExistsNode extends PredicateTree {
  const ExistsNode(QueryDescriptor subquery, {bool negated = false});
}
```

**Example**

```dart
final activePosts = Post.query().where(Post$.published.eq(true));
final authors = await User.query().whereExists(activePosts).get();
```

Carries the full subquery descriptor so adapters can render the nested query. Produced by `QueryBuilder.whereExists` and `whereNotExists`.

**Gotchas**

- Compiles to `EXISTS (...)` in SQL; the in-memory adapter evaluates it through a subquery resolver.

**Related:** [advanced queries](../queries/advanced-queries.md)

### ColumnNode

**Signature**

```dart
final class ColumnNode extends PredicateTree {
  const ColumnNode({
    required String leftField,
    required String rightField,
    required Operator operator,
    String? leftTable,
    String? rightTable,
  });
}
```

**Example**

```dart
// WHERE users.created_at = users.updated_at
final untouched = await User.query()
    .whereColumn(User$.createdAt, User$.updatedAt)
    .get();
```

Compares two columns instead of a column and a value. Produced by `QueryBuilder.whereColumn`, which defaults the operator to equality.

**Gotchas**

- The in-memory evaluator rejects column-to-column `like`, `inList`, `between`, and null-check operators with `UnsupportedOperationException`; stick to the six comparison operators for portability.

**Related:** [advanced queries](../queries/advanced-queries.md)

### RawNode

**Signature**

```dart
final class RawNode extends PredicateTree {
  const RawNode(String sql, {List<Object?> parameters = const []});
}
```

**Example**

```dart
final evens = await User.query()
    .whereRaw('age % 2 = 0', allowRaw: true)
    .get();
```

A raw SQL fragment rendered verbatim into the WHERE clause. Produced by `QueryBuilder.whereRaw` (which requires `allowRaw: true`) and by `whereRaw` on the `.sql()` dialect context.

**Gotchas**

- Adapters that cannot honor raw SQL reject queries containing a `RawNode`: the Mongo filter compiler throws, and the in-memory evaluator throws `UnsupportedOperationException`.
- `toMap()` exposes only the parameter count, never the bound values, so snapshot diagnostics cannot leak credentials or PII.
- Never build the SQL fragment from untrusted input; it is emitted verbatim. Put user data in `parameters`.

**Related:** [security guide](../guides/security.md), [advanced queries](../queries/advanced-queries.md)

## Relation references

### RelationField

**Signature**

```dart
final class RelationField<Parent extends Model, Related extends Model> {
  const RelationField(String name, {required String foreignKey, String localKey = 'id'});
  RelationPath include(List<RelationField<Model, Model>> children);
}
```

**Example**

```dart
// Generated for User from @HasMany(Post):
// static const posts = RelationField<User, Post>('posts', foreignKey: 'user_id');

final users = await User.query().withRelations([User$.posts]).get();
```

A compile-time reference to a relation by name. Generated companions emit one constant per relation (`User$.posts`). The instance carries no load logic; the eager loader and `Model.relations` key on `name`.

**Gotchas**

- Type parameters are the parent and related model classes, not the cardinality. A has-one and a has-many relation emit the same shape.
- `localKey` defaults to `'id'`; `foreignKey` has no default on the class itself (codegen derives `<snake_case_parent>_id` when the annotation omits it).
- `include` flattens the chain into a dot-joined [RelationPath](#relationpath): `User$.posts.include([Post$.comments])` produces `'posts.comments'`.

**Related:** [eager loading](../relations/eager-loading.md), [defining relations](../relations/defining-relations.md)

### RelationPath

**Signature**

```dart
final class RelationPath {
  const RelationPath(String path);
  final String path;
}
```

**Example**

```dart
final users = await User.query()
    .withPath(const RelationPath('posts.comments'))
    .get();
```

A dot-separated nested relation path, consumed by the eager loader. Usually produced by `RelationField.include`, but constructible directly.

**Gotchas**

- The string form (`withRelationPaths(['posts.comments'])`) is equivalent; `RelationPath` just keeps it typed.

**Related:** [RelationField](#relationfield), [eager loading](../relations/eager-loading.md)

### RelationLoadSpec

**Signature**

```dart
typedef RelationLoadSpec = RelationPath;
```

**Example**

```dart
RelationLoadSpec spec = User$.posts.include([Post$.comments]);
```

Spec-vocabulary alias for [RelationPath](#relationpath). `RelationField.include(...)` is documented as returning a "relation load spec"; this typedef makes that literal.

**Gotchas**

- It is the same type at runtime; there is no separate class hierarchy.

**Related:** [RelationPath](#relationpath)

## Continue reading

- [Query basics](../queries/query-basics.md) for the three `where()` shapes and every terminal.
- [Advanced queries](../queries/advanced-queries.md) for subqueries, column comparisons, and dialect escape hatches.
- [Eager loading](../relations/eager-loading.md) for `RelationField` and `RelationPath` in action.
- [Adapter API](./adapter-api.md) for how adapters consume `Predicate` and `PredicateTree`.
