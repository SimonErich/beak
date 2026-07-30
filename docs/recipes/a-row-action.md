---
title: A custom row action
description: Give a resource a verb the CRUD basics do not cover, without ejecting the panel.
---

# A custom row action

When a resource needs a verb the CRUD basics do not cover, add it in
`lib/resources/<table>.dart`. That file takes the generated `BeakResource` and
returns a changed copy, so the model, label, icon and section stay generated:

```dart title="examples/store/lib/resources/products.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  // ...detail and formLayout...
  recordActions: [
    BeakRecordAction(
      key: 'publish',
      label: 'Publish',
      icon: OiIcons.rocket,
      onExecute: (record, context) async {
        final Object? id = context.model.primaryKeyOf(record);
        if (id == null) {
          return;
        }
        await context.dataSource.update(
          context.model.table,
          id,
          BeakRecord(
            values: {
              ProductColumns.status.key: BeakValue.of(
                ProductStatus.published.name,
              ),
              ProductColumns.publishedAt.key: BeakValue.of(DateTime.now()),
            },
          ),
        );
      },
    ),
  ],
  // ...bulkActions and viewModes...
);
```

The action reads and writes through generated column constants, never through a
string field reference, so renaming `publishedAt` in the schema class breaks the
build here rather than in production.

## Continue reading

- [Actions](../panel/actions.md)
