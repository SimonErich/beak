# The block system

> Separate custom page composition from draft-based forms.

`BeakBlock` is the common description type for custom page content. `BeakBlockHost` dispatches the sealed hierarchy, provides record context and renders nested layouts. A `BeakWidgetBlock` admits an application widget where a specialized interaction is needed.

Blocks remain useful for dashboards, read views and specialized modules. Editing uses the configured-form runtime and form layout nodes, which carry field dependencies, relationship drafts and validation. A custom form node receives a draft scope; an independent custom widget receives normal Flutter context.

```dart title="packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
part of 'beak_block.dart';

/// The documented escape hatch: embeds an arbitrary widget subtree where
/// no declarative block fits (mirrors `BeakCustomColumn` on the column
/// side).
///
/// Prefer a typed block whenever one exists — escape hatches trade away
/// the declarative guarantees the rest of the union keeps.
final class BeakWidgetBlock extends BeakBlock {
  /// Creates a block that renders whatever [builder] returns.
  const BeakWidgetBlock(this.builder, {super.span});

  /// Builds the embedded subtree.
  final WidgetBuilder builder;
}

```

## Continue reading

- [Block catalog](../blocks/index.md)
- [Forms](../forms/form-screens.md)
