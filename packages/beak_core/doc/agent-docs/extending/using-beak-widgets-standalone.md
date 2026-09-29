# Using Beak widgets standalone

> Embed Beak's forms, tables and data blocks in an existing Flutter application.

You can use Beak without making it the root of the application. Import
`package:beak/panel.dart` for its public widgets and `package:beak/ui.dart` for the
matching `Oi*` controls. Provide the same model metadata and data source the full
panel would use.

`BeakConfiguredForm` accepts a model, registry, data source, record identifier,
presentation mode and optional layout or wizard steps. It owns fetching, the
local graph, validation, save, cancel and receipt recovery. `BeakStatCard` accepts
a typed aggregate and a data source. `BeakDataTable` uses the ordinary table
configuration and source contracts.

A host supplies obers_ui theme/localization and, where desired,
`BeakFormattingScope` so embedded and standard widgets display values consistently.
A complete `BeakPanel` can also be embedded in a constrained route; its responsive
shell derives its available space from its host.

## Reuse panel dependencies in custom widgets

Inside a panel, `beakDependencies(context)` resolves the nearest scoped container.
Use its `BeakDataSource`, wrap reads in `BeakResourceRepository`, and subscribe with
`useBeakDataRevision` when a custom widget should refresh after confirmed writes.
Do not create a second client with a different identity or cache lifetime.

The shop's `ShopReceivablesCard` is a working example. It embeds in two different
screens, shares their source and formatting, handles failures explicitly and
refreshes after a saved invoice changes. Its
`test/custom_shop_test.dart` proves those behaviors at narrow and wide sizes.
See [custom blocks and widgets](custom-blocks-and-widgets.md).

## Keep source capabilities explicit

Ordinary CRUD sources can render and edit conventional forms. Model behavior,
named actions and authoritative graph calculations require a source that provides
the corresponding atomic graph capability. A source cannot claim transaction or
recovery semantics merely because a custom widget calls it.

The shop's `test/order_form_test.dart` runs an ordinary configured form through
`HttpBeakDataSource` into its real SQLite-backed API. This is the integration
pattern when testing behavior that needs the server's authoritative lifecycle.
Use `InMemoryBeakDataSource` for local presentation, filtering and draft tests.

## Continue reading

- [Custom widgets](custom-blocks-and-widgets.md).
- [Custom data sources](custom-data-sources.md).
