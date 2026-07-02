---
title: Why worm?
description: The naming story, the Eloquent inheritance, and the opinions that shape the ORM.
---

This page tells you where worm comes from: the name, the lineage, and the opinions baked into it. For the technical overview, start with [what is worm?](./what-is-worm.md).

## The name

Flutter's mascot is Dash, a hummingbird. This ecosystem's core project is Beak: the part of the bird that gets things done. And what does a bird catch with its beak? A worm.

The worm is what the bird eats. An ORM is what your app lives on. Every request that reads a row, every job that writes one, feeds through the data layer. So the data layer is the worm: dug up early, swallowed whole, quietly keeping the whole bird going. The name is a small joke with a serious point. Data access is not a side dish. It is the meal.

That's also why these docs lean on bird metaphors exactly as far as they help and no further. The [tutorial](../tutorial/overview.md) builds a bird-sighting journal. The reference pages are all business.

## Standing on Eloquent's shoulders

Worm's authors compare it to exactly one thing: Laravel's Eloquent. If you have used Eloquent, worm's vocabulary will feel familiar on day one. Models with `save()` and `delete()`. Fillable and guarded mass assignment. Local and global scopes. Observers. Factories and seeders. Soft deletes. `migrate:fresh --seed`.

What Eloquent cannot give you is what Dart can: a static type system. In Eloquent, `where('agee', '>=', 18)` fails at runtime, if you are lucky. In worm, the same typo does not compile:

```dart
final adults = await User.query()
    .where(User$.age.gte(18)) // User$.agee is a compile error
    .get();
```

That is the whole pitch. Eloquent's expressiveness, Dart's compiler. Worm does not position itself against other Dart persistence packages; it targets a different niche (server-side Dart) and a different heritage.

## Opinions you are opting into

Worm is opinionated where it counts, and it is worth knowing the opinions before you commit:

- **No lazy loading, ever.** Accessing an unloaded relation throws. You state what you need up front and worm fetches it in batches. Your query count is visible in your code, not hidden in your accessors. See [eager loading](../relations/eager-loading.md).
- **Migrations are never auto-applied.** Worm can generate migration code, but a human reviews and runs it. See [migrations](../database/migrations.md).
- **Configuration is Dart code.** No YAML config files. `Worm.initialize` takes typed objects; your editor autocompletes them. See [configuration](./configuration.md).
- **Strictness is available, not mandatory.** Guardrails like full-table-scan prevention and N+1 detection are off by default and one flag away. See [strict mode](../guides/strict-mode.md).

If those defaults read like your own code-review comments, you will feel at home.

## Built in the open

Worm lives in the beak monorepo alongside its generator, lint rules, and four database drivers, all developed under strict analysis settings (no `dynamic`, no `as` casts, typed exceptions). The same conventions are enforced on contributions, and the [contributing guide](../contributing/contributing.md) shows you around. The flock is small and new members are welcome.

## Continue reading

- [What is worm?](./what-is-worm.md) Architecture and the package family.
- [Installation](./installation.md) Get the packages into your pubspec.
- [Quickstart](./quickstart.md) See the typed query pitch run on your machine.
