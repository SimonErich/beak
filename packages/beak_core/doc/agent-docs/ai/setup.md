# Set up your agent

> Give a coding agent the AGENTS.md, skills and docs bundle it needs in a Beak project.

Give an agent the repository instructions and the canonical example before asking
it to extend an application. Beak projects separate model definitions, behavior,
resource navigation and screen presentation, so a requested form change normally
has a small, explicit place to live.

`beak create` writes project guidance in `AGENTS.md`. Keep it current with the
application's own conventions and commands. For this repository, CodeGraph is the
first code-location tool when its index exists; inspect current source before
copying a signature from older documentation.

## Give the request a concrete boundary

For an ordinary resource, ask for the schema fields, typed rules, resource search
and navigation, and the form's structure. State the observable result: a dependent
profile must belong to the selected customer; adding variants must remain local
until Save; issuing an invoice must freeze the historical amounts.

Use these actual source examples:

- `resources/orders/models/order.dart` for shared dependent eligibility.
- `resources/orders/models/order_item.dart` for suggestions with manual overrides.
- `resources/invoices/models/invoice.dart` for shared rules and named actions.
- `resources/invoices/screens/invoice_form.dart` for reusable sections.
- `resources/products/screens/variant_builder.dart` for custom staged interactions.

All paths are under `examples/clean_beak_config/lib/`. The
[configuration guide](../concepts/declarative-resources.md) explains their roles.

## Keep generated files generated

Edit schemas and run `beak prepare`; do not hand-patch generated model helpers or
registries. Keep already applied migrations and add explicit upgrades. A new field
in Dart does not by itself upgrade an existing database.

Use `Model.field` references in queries, validation and input placements. Add shared
business behavior to model metadata or the domain policy, rather than separate
widget callbacks that only one screen can enforce. A custom widget should reuse
Beak's source, repository, formatting, draft and mutation-refresh contracts.

## Require evidence

Ask the agent to run formatting, analysis and focused tests. Exercise the actual
configured layout and backend when the feature spans both. Test error paths,
unsupported source capabilities and unknown save outcomes; a successful rendering
alone does not prove persistence or authorization.

When a feature is not a standard configuration, define the extension point and its
limits explicitly. Do not describe arbitrary UI closures as server-translated
rules. The same pure model rule can run on both sides; a widget callback remains
presentation code unless it is deliberately shared through a supported contract.

## Continue reading

- [Defining models](../models/defining-models.md).
- [Testing](../shipping/testing.md).
