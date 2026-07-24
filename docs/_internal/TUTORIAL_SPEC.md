# Tutorial spec: "First Flight" (writers of the tutorial read this)

Not published. Pins the tutorial so its chapters form one consistent narrative
even when written by more than one person. Read this plus STYLE_GUIDE.md and
EXAMPLE_MAP.md before writing any chapter.

## The project

"First Flight" builds the **reference admin for a small coffee roastery**. It is
the real `apps/reference_admin*` app in this repo, revealed one concept at a
time, so every snippet is code that actually compiles and ships. The three
packages:

- `reference_admin_models` (pure Dart): the shared models.
- `reference_admin_server` (Dart, Shelf): the generated backend, port **8080**.
- `reference_admin` (Flutter): the panel, `apiBaseUrl: http://localhost:8080`.

The models, in the order the tutorial introduces them:

1. `CategoryModel` (`apps/reference_admin_models/lib/src/category.dart`): id, name;
   hasMany products. The gentle first model.
2. `TagModel` (`tag.dart`): id, name. Even simpler; a belongs-to-many target.
3. `ProductModel` (`product.dart`): the rich one. String/text/decimal/int/enum/
   image/datetime columns, rules, a `BeakBelongsTo` category and a
   `BeakBelongsToMany` tags, soft deletes.
4. `UserModel` (`user.dart`), `OrderModel` (`order.dart`),
   `OrderItemModel` (`order_item.dart`): customers and orders.

Server wiring: `apps/reference_admin_models/lib/reference_admin_models.dart`
(`referenceModels`, `buildReferenceRegistry`),
`apps/reference_admin_server/lib/src/server_builder.dart` (`buildReferenceServer`),
`bin/reference_admin_server.dart`, `bin/worm.dart`,
`lib/src/migrations/reference_migrations.dart`,
`lib/src/seeders/reference_seeder.dart`. Panel:
`apps/reference_admin/lib/main.dart` (`buildReferencePanelConfig`).

## The rule about features the reference app does not have

Prefer real reference_admin code. When a chapter teaches a feature the shipped
reference_admin does not use (a kanban view, a form wizard, a custom block
dashboard), show **minimal, correct API usage built on the store's own models**
(Product, Order, Category), and frame it as "here is how you would add this to
your store." Keep it compilable: real class names, real constructor params
(check the source or API_INVENTORY.md), no invented APIs. You may borrow the
shape of a superdashboard example, but retype it against the store's models and
say nothing that claims it is already in the reference app. Never paste a
superdashboard column constant (e.g. a superdashboard `OrderColumns.*`) into a
store snippet.

## Chapter map (cumulative; each ends with a command to run and expected output)

- `tutorial/index.md` (Overview): what you build (a screenshot-in-words of the
  finished roastery admin), the finished project tree, how the parts fit, what
  you learn, prerequisites (Dart ^3.11, Flutter stable, Docker, melos 6.3.3,
  the sibling obers_ui checkout). Link to chapter 1.
- `01-hatch-the-project.md`: the three-package layout, `melos bootstrap`,
  `melos run up` (Postgres 25432 + MinIO 29000), `cp .env.example .env`. End:
  services healthy.
- `02-first-model-and-migration.md`: define `CategoryModel` and its columns
  class; write its migration; register the model in `referenceModels` and the
  migration in `bin/worm.dart`; `dart run bin/worm.dart migrate`. End: the
  categories table exists. Anchor: category.dart, reference_migrations.dart.
- `03-the-panel-comes-alive.md`: `BeakPanelConfig` with one
  `BeakResource(model: CategoryModel())`; `buildReferenceServer` + start the
  backend on 8080; `flutter run -d chrome`. End: a working list/create/show/edit
  panel for categories. Anchor: main.dart, server_builder.dart, bin/*.
- `04-relationships-and-rich-columns.md`: add `TagModel`, then `ProductModel`
  (enum status with badgeColors, decimal price with prefix, image upload with a
  transform pipeline, belongsTo category, belongsToMany tags); their migrations.
  Note `BeakHasOne` exists too, with the superdashboard order.dart transaction as
  the labeled example. Anchor: product.dart, tag.dart, reference_migrations.dart;
  hasOne from apps/beak_superdashboard/lib/models/commerce/order.dart.
- `05-seeding-a-flock-of-data.md`: the `ReferenceSeeder` (fixed ids, insert
  helper), register it, `dart run bin/worm.dart db:seed`; then show the
  `SeedContext` factory toolkit as "leveling up" for larger data. Anchor:
  reference_seeder.dart, apps/beak_superdashboard/lib/seeders/seed_context.dart.
- `06-filters-actions-and-view-modes.md`: add `BeakSelectFilter` +
  `BeakTextFilter` to Products; a custom `BeakRecordAction` (duplicateProduct,
  real code from main.dart); then add a kanban `BeakKanbanView` of orders grouped
  by an enum status (minimal correct usage on the store's Order). Anchor:
  main.dart; view-mode API from packages/beak_frontend/lib/src/panel/beak_resource_view.dart.
- `07-a-custom-dashboard.md`: config-only `dashboardStats`/`dashboardCharts` on
  `BeakPanelConfig` (real, from main.dart), then a custom `BeakScreen` at `/`
  with a block tree (KPIs + a chart) built on the store's tables. Anchor:
  main.dart; block dashboard shape from apps/beak_superdashboard/lib/panel/dashboard.dart.
- `08-forms-wizards-and-dual-mode-detail.md`: form `sections` with conditional
  visibility; a `formSteps` wizard for creating a product; a dual-mode
  detail/form layout (`BeakFieldGroupBlock`/`BeakRelationBlock`) reused for show
  and edit. Anchor: packages/beak_frontend/lib/src/form/*, detail/*;
  shapes from calendar_event_form.dart and commerce_layouts.dart, retyped to the store.
- `09-auth-theming-and-polish.md`: `BeakAuthConfig` (login/register/recover),
  `initialThemeMode` + the theme toggle, a `BeakNotificationSource` bell, the
  Ctrl/Cmd-K command bar (free), `BeakMaintenanceConfig`. Anchor:
  apps/beak_superdashboard/lib/panel/config.dart, retyped to the store where needed.
- `10-wrap-up.md`: recap what was built and the concepts met (in the order used),
  then point outward: Core concepts, the Reference, Deployment, Extending Beak.

## Voice for the tutorial

Warm and encouraging without gushing. Each chapter opens with what the reader
will have working by the end. Code arrives when the store needs it, not as a
feature list. Close each chapter with the exact command and the output to expect,
then a short `!!! note "What just happened"`. Use the bird theme lightly (the
project is "First Flight"; the reader is getting a Beak app off the ground).
