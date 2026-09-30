---
title: Models
description: Define shared data, constraints and behavior once.
type: index
audience: [beginner, expert]
status: stable
---

# Models

A schema class describes one table: its fields, its links to other tables and the rules and behavior that go with them. `beak prepare` turns it into the typed model the backend and the panel both read. Start with Defining models, then read the pages below in the order the table lists them.

The shop's `Product` is a typical schema:

```dart title="examples/clean_beak_config/lib/resources/products/models/product.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product.dart"
```

## Which page to read

| You want to… | Read | For |
| --- | --- | --- |
| Describe data once and generate typed model, field and record APIs | [Defining models](defining-models.md) | Guide for beginners |
| Read the files `beak prepare` writes, pick the right symbol and know which files are yours | [Generated code](generated-code.md) | Guide for beginners, experts and agents |
| Choose storage kinds and semantic values for generated controls | [Fields](fields.md) | Guide for beginners |
| Define a field's meaning once for typed generation, inputs, validation, storage, filtering and display | [Semantic fields](semantic-fields.md) | Guide for experts |
| Share scalar, record and relationship constraints between client and server | [Validation](validation.md) | Guide for beginners and experts |
| Declare typed connections and ownership for pickers and nested editing | [Relationships](relationships.md) | Guide for beginners and experts |
| Declare value lifecycles, shared guards and named business actions on the schema | [Model behavior](behavior.md) | Guide for experts |
| Declare managed upload fields and ordered media collections | [Files and storage columns](files-and-storage-columns.md) | Guide for beginners and experts |
| Share attribute metadata between editors and validation, then preview and stage variant combinations | [Dynamic attributes and variants](dynamic-attributes-and-variants.md) | Guide for experts |

## Continue reading

- [Defining models](defining-models.md): Describe data once and generate typed model, field and record APIs.
- [Generated code](generated-code.md): Read the files `beak prepare` writes, pick the right symbol and know which files are yours.
- [Fields](fields.md): Choose storage kinds and semantic values for generated controls.
