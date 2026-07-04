# beak_frontend

The Flutter admin panel for Beak: `BeakPanel` (shell + router) and generated
tables, forms, detail views, actions, filters, and dashboards on obers_ui.

Part of [**Beak**](https://github.com/marqably/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture.md) for how the packages fit
together.

## What it is

The presentation layer of the Beak stack. Hand `BeakPanel` a
`BeakPanelConfig` — a list of `BeakResource`s over your `beak_core` models,
plus optional dashboard stats and charts — and it stands up the entire app:
obers_ui theming, a go_router over every resource, generated
list/create/show/edit CRUD pages, and the HTTP data layer wired into GetIt.
Flutter, obers_ui-only (no Material); `HookWidget` + Signals + GetIt +
go_router throughout. The primary entry points are `BeakPanel` and
`BeakPanelConfig`.

## Usage

```dart
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

final config = BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: 'http://localhost:8080',
  resources: const [
    BeakResource(
      model: ProductModel(),
      icon: BeakIconToken(OiIcons.package),
      filters: [
        BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
        BeakTextFilter(column: ProductColumns.name, label: 'Name'),
      ],
      recordActions: [
        BeakRecordAction(
          key: 'duplicate',
          label: 'Duplicate',
          icon: OiIcons.copy,
          onExecute: duplicateProduct,
        ),
      ],
    ),
    BeakResource(model: UserModel(), icon: BeakIconToken(OiIcons.users)),
  ],
);

void main() => runApp(BeakPanel(config: config));
```

Tests inject a fake source so no HTTP is issued:
`BeakPanel(config: config, dataSource: fakeSource)`.

## Key types

- `BeakPanel` — root `HookWidget`; builds theme, router, and DI from a config.
- `BeakPanelConfig` — the declarative panel definition (resources, apiBaseUrl,
  dashboards, theming).
- `BeakResource` — one model surfaced as list/detail/form pages, with its
  actions and filters.
- `BeakRecordAction` / `BeakBulkAction` / `BeakGlobalAction` — typed action
  hooks over records, selections, and pages.
- `BeakSelectFilter` / `BeakTextFilter` / `BeakBoolFilter` — list-page filter
  controls bound to typed columns.
- `BeakStat` / `BeakChart` — dashboard aggregate tiles and charts.
- `BeakIconToken` — a typed `OiIcons` wrapper for navigation icons.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[reference admin](../../apps/reference_admin). Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
