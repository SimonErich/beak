# Quickstart

> Generate and run the minimal maintained Beak application.

Install the CLI as described in [Installation](installation.md), then generate a project:

```bash
beak create acme_admin
cd acme_admin
flutter pub get
beak prepare
beak migrate
beak dev
```

The generated project starts with a note schema. Add fields and relationships, run `beak prepare`, review generated migrations and apply them explicitly. Generation does not change the database on startup.

```dart title="examples/quickstart/lib/resources/notes/models/note.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'note.beak.dart';

/// A note.
///
/// Declared once. `beak prepare` generates the typed columns, the model, the
/// relationships (both sides), and a typed record view into `note.beak.dart`,
/// so there is no registry to edit.
@Resource(timestamps: true)
final class Note extends BeakSchema {
  /// What the note is called.
  ///
  /// Non-nullable, so it is required: the form validator, the API and the
  /// schema all derive that from the type rather than restating it.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(255)])
  late final String title;

  /// The note itself.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? body;

  /// Whether the note is pinned to the top of the list.
  @Column(filterable: true)
  late final bool pinned;
}
```

Generated `.beak.dart` parts contain typed fields and record readers. The `lib/beak/` files connect the registry, default panel and server. For an authored interface, pass a list of resources to `BeakPanel` and place layouts beside those resources. The [shop tutorial](../tutorial/index.md) demonstrates that structure.

## Run the checked-in shop

```bash
cd examples/clean_beak_config
flutter pub get
dart run ../../packages/beak_cli/bin/beak.dart prepare
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
dart run bin/serve.dart
```

In another terminal, run `flutter run -d chrome --web-port=3000` from the same directory. The panel uses the local API on port 8080. Database migrations preserve upgrade history; the seeder preserves existing records.

## Continue reading

- [Project structure](project-structure.md)
- [Tutorial](../tutorial/index.md)
