# worm

A type-safe, Eloquent-inspired ORM for server-side Dart. Annotated models, a
fluent query builder with compile-time checked fields, migrations, seeding,
factories, and swappable database adapters (PostgreSQL, MySQL, SQLite,
MongoDB, in-memory).

Why "worm"? Flutter's mascot Dash is a bird. This ecosystem's core project is
Beak, the bird's beak. And the worm is what the bird eats. Your app has to
live on something.

```dart
@Table()
class User extends Model {
  @PrimaryKey()
  late String id;

  @Column()
  late String name;

  @Column()
  late int age;
}

final adults = await User.query()
    .where(User$.age.gte(18))
    .orderBy(User$.createdAt, descending: true)
    .get();
```

A typo in a field name is a compile-time error, not a 3 a.m. incident.

## Documentation

The full documentation lives in [docs/](docs/) and is published as a
searchable site (Astro Starlight, built by the `docs` GitHub workflow from
[docs_site/](docs_site/)).

Good entry points:

- [What is worm?](docs/start-here/what-is-worm.md)
- [Quickstart](docs/start-here/quickstart.md)
- [Tutorial: build a bird-sighting journal](docs/tutorial/overview.md)
- [Cheatsheet](docs/reference/cheatsheet.md)
- [Choosing a database](docs/drivers/choosing-a-database.mdx)
- [Contributing and writing your own driver](docs/contributing/writing-a-database-driver.md)

## Packages

| Package | Role |
|---|---|
| `worm` | Core ORM: models, queries, relations, migrations, seeding, CLI |
| `worm_generator` | build_runner code generator for typed companions |
| `worm_lints` | Custom lint rules for worm projects |
| `worm_sqlite` | SQLite driver (in-process, no server) |
| `worm_postgres` | PostgreSQL driver (pooling, savepoints, EXPLAIN) |
| `worm_mysql` | MySQL driver |
| `worm_mongodb` | MongoDB driver (NoSQL, document filters) |

## Development

```bash
dart pub get
dart format . && dart analyze && dart test
```

See [contributing](docs/contributing/contributing.md) for the full setup,
including live-database test environments via docker compose.
