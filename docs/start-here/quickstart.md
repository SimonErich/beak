---
title: Quickstart
description: Generate and run the minimal maintained Beak application.
type: tutorial
audience: [beginner]
status: draft
---

# Quickstart

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
--8<-- "examples/quickstart/lib/resources/notes/models/note.dart"
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
