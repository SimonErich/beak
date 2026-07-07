part of 'beak_block.dart';

/// A record's related records, inline in its detail layout: the scoped
/// record's [relationship] rendered through the shared relation manager
/// (a table of the related rows with attach/detach where applicable).
/// Resolves the parent model and id from the enclosing `BeakRecordScope`.
final class BeakRelationBlock extends BeakBlock {
  /// Shows the scoped record's [relationship].
  const BeakRelationBlock(this.relationship, {this.title, super.span});

  /// The relationship to render.
  final BeakRelationship relationship;

  /// A heading override; defaults to the relationship's own label.
  final String? title;
}
