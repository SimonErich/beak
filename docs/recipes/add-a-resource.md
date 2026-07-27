---
title: Add a resource end-to-end
description: One annotated class, one command, and the table, API, form, table view and detail page exist.
---

# Add a resource end-to-end

Write one annotated class under `lib/models/`. The field's type picks the column
kind, and its nullability decides whether the value is required:

```dart title="examples/store/lib/models/tag.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'tag.beak.dart';

/// A free-form label products are tagged with.
@Resource()
final class Tag extends BeakSchema {
  /// What the tag is called.
  @Display()
  @Column(
    searchable: true,
    sortable: true,
    unique: true,
    rules: [BeakMaxLength(60)],
  )
  late final String name;
}
```

Then run the generator:

```bash
beak prepare
```

That writes `tag.beak.dart` beside it (`TagColumns`, `TagRelations`,
`TagModel`, a typed record view), adds the model to `beakModels` and the
registry, adds the resource to the panel config, and writes the migration the
new table needs. You register nothing. Give it an icon and a sidebar section in
`beak.yaml` if the defaults are not what you want.

## Continue reading

- [Defining a resource](../models/defining-models.md)
- [Generated code](../models/generated-code.md)
