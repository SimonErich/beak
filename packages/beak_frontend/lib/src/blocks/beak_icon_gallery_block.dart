part of 'beak_block.dart';

/// One labelled icon in a [BeakIconGalleryBlock].
final class BeakIconGalleryItem {
  /// Creates an entry pairing [icon] with its [label].
  const BeakIconGalleryItem({required this.icon, required this.label});

  /// The icon to display.
  final BeakIconToken icon;

  /// The name shown beneath the icon.
  final String label;
}

/// A reference grid of named icons — a design-system cheat-sheet. Each entry
/// renders onto `OiIcon` with its label beneath.
final class BeakIconGalleryBlock extends BeakBlock {
  /// Creates a gallery of [items] laid out in [columns] columns.
  const BeakIconGalleryBlock({
    required this.items,
    this.columns = 6,
    super.span,
  });

  /// The icons to display.
  final List<BeakIconGalleryItem> items;

  /// The number of grid columns.
  final int columns;
}
