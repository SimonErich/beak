# Example map

Internal source map for documentation writers. Quote current, compiling source;
read an implementation or test before introducing an API. Prefer source snippet
markers for examples that have them. Paths below are workspace-relative.

The canonical shop is `examples/clean_beak_config`; the minimal scaffold is
`examples/quickstart`. Both use port 8080 by default. The second complete app,
`examples/foodio-adminpanel`, preserves Gabel branding and runs on port 8081.
These are unauthenticated local demos; do not imply that their configuration
demonstrates production auth. Foodio’s [README](../../examples/foodio-adminpanel/README.md)
contains run steps; [DOMAIN.md](../../examples/foodio-adminpanel/DOMAIN.md) defines
its exact fixture counts, money and workflow contracts.

| Topic | Source |
| --- | --- |
| Minimal project | `examples/quickstart/lib/main.dart`, `examples/quickstart/lib/models/note.dart` |
| Explicit panel registration | `examples/clean_beak_config/lib/main.dart` |
| Resources, search, filters | `examples/clean_beak_config/lib/resources/products/product_resource.dart` |
| Typed schemas | `examples/clean_beak_config/lib/resources/products/models/product.dart` |
| Dependent selectors and shared validation | `examples/clean_beak_config/lib/resources/orders/models/order.dart` |
| Suggested values | `examples/clean_beak_config/lib/resources/orders/models/order_item.dart` |
| Named actions and document states | `examples/clean_beak_config/lib/resources/invoices/models/invoice.dart` |
| Shared sections, tabs and wizards | `examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart` |
| Semantic types and structured objects | `examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart` |
| Semantic controls | `examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart` |
| Galleries | `examples/clean_beak_config/lib/resources/products/screens/product_form.dart` |
| Attribute metadata adapter | `examples/clean_beak_config/lib/domain/shop_attributes.dart` |
| Variant preview and staged generation | `examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart` (`ShopVariantBuilder`) |
| Dashboard | `examples/clean_beak_config/lib/overview.dart` (`shopOverview`) |
| Custom operations and import | `examples/clean_beak_config/lib/operations.dart` (`shopOperations`) |
| Reusable live custom widget | `examples/clean_beak_config/lib/widgets/receivables_card.dart` (`ShopReceivablesCard`) |
| Resumable demo drafts | `examples/clean_beak_config/lib/shop_drafts.dart` |
| Transactional business policy | `examples/clean_beak_config/lib/domain/shop_graph_preparer.dart` |
| Pure domain calculations | `examples/clean_beak_config/lib/domain/shop_totals.dart` |
| Backend registration | `examples/clean_beak_config/lib/server.dart` |
| Additive migrations | `examples/clean_beak_config/lib/migrations/expand_shop_catalog.dart`, `add_variant_combinations.dart` |
| Repeatable seeding | `examples/clean_beak_config/lib/seeders/shop_seeder.dart` |
| API workflow and rollback evidence | `examples/clean_beak_config/test/shop_api_test.dart` |
| Custom widgets and refresh evidence | `examples/clean_beak_config/test/custom_shop_test.dart` |
| Reusable layouts and responsive rendering | `examples/clean_beak_config/test/shop_widget_test.dart` |

## Gabel / Foodio sources

| Topic | Source |
| --- | --- |
| Composed order list, presets and saved views | `examples/foodio-adminpanel/lib/resources/orders/order_resource.dart` |
| Catalog wizard, responsive review and shared detail | `examples/foodio-adminpanel/lib/resources/orders/order_form.dart`, `order_review.dart`, `order_detail.dart` |
| Declarative record templates and visual identities | `examples/foodio-adminpanel/lib/resources/orders/order_presentations.dart` |
| Supporting configured forms | `examples/foodio-adminpanel/lib/resources/people/`, `finance/`, `operations/` |
| Typed command inputs and state transitions | `examples/foodio-adminpanel/lib/domain/order_behavior.dart`, `_redelivery_input.dart`, `_order_note_input.dart` |
| Live money and budget previews | `examples/foodio-adminpanel/lib/resources/orders/order_totals.dart` |
| Transactional budget/capacity and immutable snapshots | `examples/foodio-adminpanel/lib/domain/foodio_order_preparer.dart` |
| Persistent demo effects and stale-request guards | `examples/foodio-adminpanel/lib/domain/foodio_effects.dart` |
| Query-backed 48,213-order fixture | `examples/foodio-adminpanel/lib/seeders/foodio_seeder.dart` |
| Real API, replay and rollback tests | `examples/foodio-adminpanel/test/foodio_api_test.dart` |
| Full panel route, curated form and wizard tests | `examples/foodio-adminpanel/test/foodio_panel_test.dart`, `supporting_forms_test.dart`, `order_wizard_presentation_test.dart` |

## Framework reference sources

Use implementation signatures and focused package tests for features that the
canonical shop does not exercise. Do not add unrelated sample apps solely to
provide a documentation quote.

- Core contracts: `packages/beak_core/lib/src/model/`, `query/`, `validation/`,
  `behavior/`, `data/`, `columns/`, `storage/`.
- HTTP and policy behavior: `packages/beak_backend/lib/src/endpoints/`, `auth/`,
  `service/`, `uploads/`, `export/`, and corresponding tests.
- Data-source adapters: `packages/beak_backend/lib/src/data/worm/` and
  `packages/beak_frontend/lib/src/data/`.
- Form runtime and presentations: `packages/beak_frontend/lib/src/form/`.
- Custom pages, resources and navigation: `packages/beak_frontend/lib/src/panel/`.
- Block catalog: `packages/beak_frontend/lib/src/blocks/beak_block.dart`, the
  individual block declarations, `beak_block_host.dart`, and block tests.
- Charts: `packages/beak_frontend/lib/src/dashboard/beak_chart.dart` and chart/block
  tests; do not imply a chart appears in the shop unless it does.
- Auth, row/field policy and upload ownership: backend policy tests and frontend
  auth tests, explicitly labeled as framework examples.
- CLI discovery and generation: `packages/beak_cli/lib/src/project/`, `schema/`
  and generation/compile tests.

Check paths when choosing a snippet: generated schema parts and generated host
files can move as the application evolves. Document authored model/resource files
first; generated output explains implementation only when necessary.
