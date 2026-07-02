# worm_generator

Build-runner code generation for the `worm` ORM.

For every class annotated with `@Table`, this builder emits a
`.worm.dart` part file containing:

- A typed companion class (`Model$`) with `Field<T>` constants
  for every `@Column`.
- A hydration extension with `fromRow` (pattern-matching, no
  `as` casts) and `toRow`.
- A query-starter extension exposing `tableName`.
- A scope metadata extension.

## Usage

Add to a project's `dev_dependencies`:

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  worm_generator:
    path: ../worm_generator
```

Annotate the model and declare the generated part:

```dart
import 'package:worm/annotations.dart';

part 'user.worm.dart';

@Table(name: 'users')
class User {
  @Column()
  final String id;

  @Column()
  final String email;

  User({required this.id, required this.email});
}
```

Then run the generator:

```sh
dart run build_runner build
```

Or use the project's CLI wrapper:

```sh
dart run worm:worm gen
```
