---
title: Project structure
description: Separate model behavior, resource navigation and screen layout in one application.
type: guide
audience: [beginner, agent]
status: draft
---

# Project structure

Use [the runnable shop](https://github.com/SimonErich/beak/tree/main/examples/clean_beak_config) as the complete project reference. Its server and panel share schemas while retaining separate entrypoints.

```text
lib/main.dart                         panel, resources, pages and formatting
lib/resources/<resource>/models/      schemas and generated typed helpers
lib/resources/<resource>/*_resource.dart  navigation, search and screen roles
lib/resources/<resource>/screens/     forms, tables and reusable sections
lib/domain/                           shared pure application calculations
lib/server.dart                       server policy and advanced graph rules
lib/migrations/                       reviewed schema changes
lib/seeders/                          repeatable example data
lib/beak/                             generated registry and server wiring
bin/                                 generated server and migration entrypoints
test/                                model, API and widget tests
```

There is no mandatory file per field or operation. Small resources can use a model and default screens. Add separate layout or behavior files when they improve readability.

`examples/quickstart` remains the minimal CLI-generated application. `examples/clean_beak_config` is the maintained shop and customization showcase. Both use the same declarative resource runtime.

## Continue reading

- [Quickstart](quickstart.md)
- [Declarative resources](../concepts/declarative-resources.md)
