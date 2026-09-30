# Tutorial spec: First Flight

Internal instructions for a coherent tutorial. Read STYLE_GUIDE.md and
EXAMPLE_MAP.md before writing. The tutorial starts with the minimal generated
project and grows into the canonical shop at `examples/clean_beak_config`.
Every snippet must correspond to a real source file or a compiled focused test.

## Project and vocabulary

Use one Dart/Flutter package: authored schemas and resource configuration under
`lib/`, generated parts beside schemas, generated host wiring in `lib/beak/`,
and generated `bin/serve.dart` / `bin/migrate.dart` entrypoints. The shop's models
are organized within resource folders. `BeakPanel(resources:..., pages:...)` is
the primary explicit application entrypoint.

Use port 8080 for the API and 3000 for the browser example. SQLite requires no
external service. The local shop is unauthenticated; production authentication
and tenant policy are separate, explicitly configured topics.

Introduce Category and Product first, then customers, orders and their owned
lines. Extend into variants/attributes and invoicing only after ordinary resource
configuration is clear. Do not invent Tag or Payment models in the shop.

## Chapter progression

1. Scaffold with the actual `beak create` command. Explain generated and authored
   files; run the minimal example before adding complexity.
2. Define an annotated schema, generate typed helpers and apply migrations.
   Use `Category` as the small model. Existing migrations are not regenerated or
   destructively replaced when models change.
3. Register `BeakResource` definitions in `BeakPanel`; show generated list, read,
   create and edit screens with no handwritten fetching or saving.
4. Add relationships and typed semantic metadata. Use the actual Product,
   Order/OrderItem and FulfillmentPolicy models; show owned rows as staged edits.
5. Seed the database using the repeatable ShopSeeder. Explain preserving existing
   data and make reset commands an explicitly separate development action.
6. Add typed filters and global search sources. Introduce Invoice's named model
   actions when explaining workflow state; distinguish them from arbitrary UI
   callback actions.
7. Compose `shopOverview`, `shopOperations` and the reusable ShopReceivablesCard.
   Show shared source, formatting, repository errors and mutation refresh.
8. Use `BeakFormSections` to project one layout into tabs or wizard steps. Model
   rules provide dependent selector eligibility and validation; presentation
   callbacks remain an escape hatch. Show suggestions, overrides, review and
   resumable drafts using the actual example configuration.
9. Explain production authentication and row/field policy using focused framework
   examples, then theme and formatting configuration from the shop. Never imply
   a user-interface visibility check replaces backend authorization.
10. Review the completed configuration, tests, extension points and deployment
    decisions. Link to the dynamic attribute/variant, graph policy, import and
    media guides without claiming production payment or tax certification.

## Evidence and writing

Each chapter should end with a command that runs and a specific observable
result. Verify constructor names against current source; quote named snippets
where available. Do not mix schema-generated helpers with an unrelated hand-coded
model from another example. If teaching an optional framework feature, label it
as an extension rather than claiming it ships in the canonical shop.

Keep the tutorial centered on model definitions, behavior and presentation.
Explain runtime internals only when they clarify a meaningful choice, such as
atomic versus staged sources, recovery after an unknown outcome, explicit draft
storage context or irreversible external side effects.
