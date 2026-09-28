---
title: Relationships
description: Configure related editors while Beak manages their draft graph.
---

# Relationships

Declare a relationship on the schema and place its generated field in a form. Beak loads existing rows, tracks local changes and builds the save plan.

```dart title="examples/clean_beak_config/lib/resources/orders/models/order_item.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/models/order_item.dart"
```

A to-one input uses `.inputCombobox()`. A to-many field uses `.tableForm(...)`; galleries use `.galleryForm(...)`. Configure the related fields inside that section, and use an advanced form for less common options.

## Ownership and cancellation

Owned children belong to the parent's lifecycle. Shared records and pivot connections have different removal semantics. Declare ownership on the relationship, and choose detach or owned deletion in its editor. Removing a row from a draft does not immediately delete it remotely.

Related creation inside a picker stays in the parent draft. Modal cancellation restores its checkpoint. Finishing the parent resolves temporary identities and saves the graph through the source's commit capability.

## Dependent selections

Shared `BeakExists` rules with `BeakFieldMatch` describe eligible foreign keys. Standard pickers infer the matching filters and prerequisites, and recheck a selected value when dependencies change. The backend enforces the same rule independently.

The order example makes delivery profiles depend on the selected customer. A custom option query remains available when eligibility needs a genuinely application-specific query.

## Continue reading

- [Seeding and the API](04-seeding-and-the-api.md)
- [Relationship reference](../models/relationships.md)
