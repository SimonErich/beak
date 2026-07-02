---
title: Scopes
description: Global scopes, local scopes, typed scope methods, and how soft deletes ride the same machinery.
---

Scopes are reusable query transformers: global scopes apply to every query automatically, local scopes apply on demand. This page covers both, the escape hatches, and why soft deletes are nothing special. It builds on [query basics](./query-basics.md).

## Global scopes

A `GlobalScope` is a query modifier auto-applied to every builder created from a model's context. It declares a unique `name` (used for bypassing) and an `apply` method that returns a constrained builder:

```dart
final class ActiveScope extends GlobalScope<Model> {
  const ActiveScope();

  @override
  String get name => 'active';

  @override
  QueryBuilder<Model> apply(QueryBuilder<Model> builder) =>
      builder.where(const Field<bool>('is_active').eq(true));
}
```

Global scopes live on `QueryContext.globalScopes`. With codegen, annotate the model class with `@GlobalScope(ActiveScope)` and the generated `query()` registers the scope for you:

```dart
final users = await User.query().get();
// SELECT * FROM users WHERE is_active = true
```

Two properties matter:

- **Execution time, not build time.** Scopes are applied when a terminal runs (and inside `toSql()`), in registration order. The builder's own `descriptor.where` stays scope-free until then.
- **They constrain writes too.** Bulk `update()` and `delete()` run their WHERE through the same scopes, so a scoped-out row can't be bulk-updated by accident.

## Bypassing global scopes

Bypass one scope by type, or all of them:

```dart
// Drop just the ActiveScope for this query.
final everyone = await User.query().withoutGlobalScope<ActiveScope>().get();

// Drop every registered global scope.
final raw = await User.query().withoutGlobalScopes().get();
```

`withoutGlobalScope<X>()` resolves `X` against the registered scopes via an `is X` check and records the matched scope's `name`. When no registered scope satisfies `is X`, it returns the builder unchanged. That silent no-op is the classic scope bug: a typo'd or unregistered type parameter disables nothing and throws nothing.

## Local scopes

A `LocalScope` is an opt-in predicate fragment. It never applies automatically; you attach it with `scope()`:

```dart
final class PublishedScope extends LocalScope<Post> {
  const PublishedScope();

  @override
  QueryBuilder<Post> apply(QueryBuilder<Post> builder) =>
      builder.where(Post$.published.eq(true));
}

final posts = await Post.query().scope(const PublishedScope()).get();
```

For one-off fragments that don't earn a class, wrap a closure in `CallableLocalScope`:

```dart
final adults = await User.query()
    .scope(CallableLocalScope((q) => q.where(User$.age.gte(18))))
    .get();
```

Local scopes compose freely with each other, with global scopes, and with any other chainable.

## Typed scope methods

`Post.query().scope(const PublishedScope())` works, but `Post.query().published()` reads better. A three-line extension gets you there:

```dart
extension PostQueryScopes on QueryBuilder<Post> {
  QueryBuilder<Post> published() => scope(const PublishedScope());
}

final posts = await Post.query().published().where(Post$.views.gt(100)).get();
```

This is exactly the shape the codegen core emits when a scope descriptor names its backing `LocalScope` class.

:::note[What @Scope generates today]
The `@Scope('published')` annotation on a model method currently makes `worm_generator` record the name in the generated `scopeNames` metadata list only; it does not yet emit a callable query method, and there is no string-based `applyScope` on the builder. Write the extension above by hand for typed scope calls. `@GlobalScope(...)` registration, by contrast, is fully wired into the generated `query()`. See [code generation](../models/code-generation.md).
:::

## Soft deletes are just a scope

There is no special soft-delete engine. The `SoftDeletes` mixin registers a bundled `SoftDeleteScope`, a plain `GlobalScope` that filters `deleted_at IS NULL`:

```dart
// What the bundled scope does, conceptually:
builder.where(const Field<Object?>('deleted_at').isNull());
```

Its `name` is the `softDeleteScopeName` constant (`'soft_deletes'`), and its column defaults to `'deleted_at'` (`SoftDeleteScope({column: 'deleted_at'})`). The familiar sugar is just the bypass machinery from above:

```dart
final live = await User.query().get();          // scope applied
final all = await User.query().withTrashed().get();   // scope bypassed
final gone = await User.query().onlyTrashed().get();  // bypassed + deleted_at IS NOT NULL
```

`withTrashed()` is literally `withoutGlobalScope<SoftDeleteScope<Model>>()`, and `onlyTrashed({column: 'deleted_at'})` is `withTrashed()` plus an `isNotNull()` predicate on the column. The model-side story (trashing, restoring, `forceDelete`) lives in [soft deletes](../models/soft-deletes.md).

## Gotchas

- `withoutGlobalScope<X>()` is a silent no-op when no registered scope satisfies `is X`. No error, no effect.
- Global scopes apply at execution time in registration order. `toSql()` includes them; `descriptor.where` before a terminal does not.
- Global scopes constrain bulk `update()` and `delete()` WHERE clauses too.
- `whereGroup()` runs its inner builder with global scopes disabled so scope predicates can't leak into your parentheses; the outer builder still applies them once.
- Local scopes never auto-apply. Forgetting `.scope(...)` (or the extension call) means the fragment isn't there.
- `find()` and `findOrFail()` also run through global scopes: a soft-deleted row is not findable without `withTrashed()`.
- `@Scope` on a model method emits `scopeNames` metadata only; typed scope methods are hand-written extensions today.

## API summary

| Symbol | Signature sketch | One-liner |
| --- | --- | --- |
| `GlobalScope<T>` | `abstract; String get name; QueryBuilder<T> apply(builder)` | Query modifier auto-applied to every builder at execution time. |
| `LocalScope<T>` | `abstract; QueryBuilder<T> apply(builder)` | Opt-in reusable predicate fragment. |
| `CallableLocalScope<T>` | `CallableLocalScope((q) => ...)` | Closure-backed `LocalScope` for ad-hoc fragments. |
| `SoftDeleteScope<T>` | `SoftDeleteScope({column: 'deleted_at'})` | Bundled global scope filtering `deleted_at IS NULL`. |
| `softDeleteScopeName` | `const String` | Stable name (`'soft_deletes'`) of the soft-delete scope. |
| `QueryBuilder.scope` | `scope(LocalScope<T> scope)` | Apply a local scope to this builder. |
| `QueryBuilder.withoutGlobalScope` | `withoutGlobalScope<X extends GlobalScope>()` | Bypass one global scope by type; silent no-op when unregistered. |
| `QueryBuilder.withoutGlobalScopes` | `withoutGlobalScopes()` | Bypass every global scope on this builder. |
| `QueryBuilder.withTrashed` | `withTrashed()` | Include soft-deleted rows (typed bypass of `SoftDeleteScope`). |
| `QueryBuilder.onlyTrashed` | `onlyTrashed({column: 'deleted_at'})` | Return only soft-deleted rows. |
| `QueryContext.globalScopes` | `List<GlobalScope<Model>>` | Registration list the builder applies in order. |

## Continue reading

- [Soft deletes](../models/soft-deletes.md): the model-side mixin, `restore()`, and `forceDelete()`.
- [Code generation](../models/code-generation.md): what `@GlobalScope` and `@Scope` actually emit.
- [Multiple connections](../database/multiple-connections.md): tenancy patterns where a global scope does the fencing.
