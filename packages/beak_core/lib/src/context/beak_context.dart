/// The render site a column is currently being resolved for.
///
/// A single `BeakColumn` definition is rendered differently per site: a cell
/// in a table, an input in a form, a read-only entry in a detail view, or a
/// filter control. Column configuration (visibility, render intents) is keyed
/// by this enum, so one definition drives every surface.
// --8<-- [start:BeakContext]
enum BeakContext {
  /// A cell inside a resource list/table.
  table,

  /// An editable input inside a create/edit form.
  form,

  /// A read-only entry inside a record detail view.
  detail,

  /// A filter control inside a table's filter bar.
  filter,
}

// --8<-- [end:BeakContext]
