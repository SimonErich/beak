---
title: 'Part 5: Queries that sing'
description: Filter by date range, group with OR, paginate, rank with withCount, and inspect the SQL.
---

With a stable flock in the journal, you can ask real questions. This part filters sightings by date, groups conditions, paginates results, ranks birds by activity, and peeks at the SQL worm builds.

## Goal

One `report.dart` script that runs five queries over the seeded data and prints answers you can predict exactly.

## The seeded data

The seeder gave you three birds and six sightings on fixed June dates:

| Species | Sightings |
| --- | --- |
| Robin | Jun 1 (x1) |
| Jay | Jun 4 (x2), Jun 5 (x3) |
| Wren | Jun 7 (x3), Jun 8 (x4), Jun 9 (x5) |

Keep that table handy as you read the output.

## The report script

```dart title="bin/report.dart"
import 'package:nestwatch/models/bird.dart';
import 'package:nestwatch/models/sighting.dart';
import 'package:nestwatch/nestwatch.dart';
import 'package:worm/worm.dart';

Future<void> main() async {
  await bootNestwatch();

  // 1. Date-range filter with a ComparableField.
  final window = await Sighting.query()
      .where(
        Sighting$.observedAt.between(
          DateTime.utc(2026, 6, 4),
          DateTime.utc(2026, 6, 8),
        ),
      )
      .orderBy(Sighting$.observedAt)
      .get();
  print('Sightings Jun 4 to Jun 8: ${window.length}');
  for (final s in window) {
    final day = s.observedAt.toIso8601String().substring(0, 10);
    print('  $day  ${s.location}  x${s.count}');
  }

  // 2. Grouped OR: busy feeders or big flocks.
  final busy = await Sighting.query()
      .whereGroup(
        (q) => q
            .where(Sighting$.count.gte(4))
            .orWhere(Sighting$.location.eq('Feeder 1')),
      )
      .orderBy(Sighting$.count, descending: true)
      .get();
  print('Busy or big: ${busy.map((s) => s.count).toList()}');

  // 3. Paginate the journal.
  final page = await Sighting.query()
      .orderBy(Sighting$.observedAt)
      .paginate(perPage: 4);
  print(
    'Page ${page.currentPage}/${page.lastPage}, '
    'showing ${page.data.length} of ${page.total}',
  );

  // 4. Leaderboard via withCount.
  final board = await Bird.query().withCount('sightings').get();
  board.sort(
    (a, b) => b
        .getInjected<int>('sightingsCount')
        .compareTo(a.getInjected<int>('sightingsCount')),
  );
  print('Leaderboard:');
  for (final bird in board) {
    print('  ${bird.species}: ${bird.getInjected<int>('sightingsCount')}');
  }

  // 5. Peek at the SQL (inspection only, never executed).
  print(Bird.query().where(Bird$.species.eq('Wren')).toSql());
}
```

## Checkpoint

```bash
dart run bin/report.dart
```

```text
Sightings Jun 4 to Jun 8: 4
  2026-06-04  Feeder 1  x2
  2026-06-05  Feeder 2  x3
  2026-06-07  Feeder 1  x3
  2026-06-08  Feeder 2  x4
Busy or big: [5, 4, 3, 2, 1]
Page 1/2, showing 4 of 6
Leaderboard:
  Wren: 3
  Jay: 2
  Robin: 1
SELECT * FROM "birds" WHERE "species" = ?
-- Params: [Wren]
```

## Reading each query

**Date range.** `Sighting$.observedAt` is a `ComparableField<DateTime>`, so it gets range operators like `between`. The bounds are inclusive, so Jun 4 through Jun 8 catches four sightings and skips Wren's Jun 9. Only comparable fields get `between`, `gt`, and friends; a plain `StringField` would not compile with them, which stops a whole class of mistakes.

**Grouped OR.** `whereGroup` wraps its inner conditions in parentheses. Here it means "count is at least 4, or the location is Feeder 1". That matches the two big Wren counts plus every bird's first sighting, five rows, sorted by count descending.

**Pagination.** `paginate(perPage: 4)` runs one page query and one count query, then hands back a `Page`. With six sightings and four per page, you get page 1 of 2. `page.data` holds the rows, `page.total` the full count.

**Leaderboard.** `withCount('sightings')` adds one grouped `COUNT` query and stores the result on each bird under `sightingsCount`. You read it with `getInjected<int>('sightingsCount')`. No sighting rows were loaded to produce the ranking; the database did the counting.

**SQL peek.** `toSql()` compiles the query to a string so you can see what worm will send. It is for inspection only, not execution. The literal is shown as a bound parameter (`?`) with the value listed below, which is how the SQLite driver keeps your values out of the SQL text.

:::caution
`toSql()` output is for reading, not running. Values are parameterized, and the string is not a statement you should feed back to a database. Never build queries by concatenating untrusted input.
:::

## What just happened

Every filter went through a typed `Sighting$` or `Bird$` field, so the compiler checked your columns and operators. Aggregates and counts ran inside SQLite, not in Dart, so the leaderboard scales to any number of sightings. And nothing ran until you called a terminal like `get()`, `paginate()`, or `toSql()`; each chain step just built up the query.

The immutability is worth pausing on. `Sighting.query()` returns a fresh builder, and so does every `.where()`, `.orderBy()`, and `.whereGroup()` after it. You can hold a half-built query in a variable and branch from it without one branch leaking conditions into another. The database sees nothing until the terminal.

## Gotchas

- **Terminals run; chainables do not.** `where`, `orderBy`, `limit`, and `whereGroup` only build the query. `get`, `first`, `count`, `paginate`, and `toSql` are the terminals that execute or compile it.
- **`between` is inclusive.** Both bounds are included, so Jun 4 to Jun 8 returns sightings on both endpoint days. Adjust your bounds if you want a half-open range.
- **Field type gates the operators.** `between`, `gt`, and `lte` live on `ComparableField`. LIKE-family operators live on `StringField`. Reaching for a range operator on a plain field is a compile error, not a runtime surprise.
- **`getInjected` throws when the key is missing.** If you read `sightingsCount` without a preceding `withCount('sightings')`, it throws rather than returning zero, so a forgotten aggregate fails loudly.
- **`toSql()` is not runnable.** It parameterizes values and formats the query for reading. Do not send its output to a database.

## Continue reading

- [Part 6: Safety nets and wrap-up](./06-safety-nets-and-wrap-up.md)
- [Query basics](../queries/query-basics.md)
- [Pagination](../queries/pagination.md)
- [Logging and debugging](../guides/logging-and-debugging.md)
