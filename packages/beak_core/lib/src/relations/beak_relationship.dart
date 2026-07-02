import 'package:meta/meta.dart';

import '../columns/beak_render_config.dart';
import '../context/beak_context.dart';
import '../context/beak_render_intent.dart';
import 'beak_on_delete.dart';

part 'beak_belongs_to.dart';
part 'beak_belongs_to_many.dart';
part 'beak_has_many.dart';
part 'beak_has_one.dart';

/// How many related records a relationship resolves to.
enum BeakRelationCardinality {
  /// At most one related record (belongs-to, has-one).
  one,

  /// A list of related records (has-many, belongs-to-many).
  many,
}

/// A typed, ORM-neutral description of a relationship between two models.
///
/// Declared once on a `BeakModel` and consumed everywhere: the backend
/// eager-loads it by [key] (matching the worm relation name), pickers show
/// the related model's [displayColumnKey] and search its [searchColumnKeys],
/// and the frontend switches exhaustively over this sealed family to choose
/// the widget per surface.
@immutable
sealed class BeakRelationship {
  /// Creates a relationship named [key] pointing at [relatedTable].
  const BeakRelationship({
    required this.key,
    required this.label,
    required this.relatedTable,
    required this.displayColumnKey,
    this.searchColumnKeys = const [],
  });

  /// Relation name; matches the relation name on the backing ORM model.
  final String key;

  /// Human-readable label shown in tables, forms, and detail views.
  final String label;

  /// Physical table/collection name of the related model.
  final String relatedTable;

  /// Key of the related-model column that represents a record in pickers
  /// and links.
  final String displayColumnKey;

  /// Keys of related-model columns searched when picking a record.
  final List<String> searchColumnKeys;

  /// The per-context render configuration of this relationship.
  BeakRenderConfig get renderConfig;

  /// The rendering hint for a given [context]. The frontend refines it per
  /// concrete relationship type (e.g. a form-context [BeakRenderIntent
  /// .relationLink] becomes a searchable single-select).
  BeakRenderIntent intentFor(BeakContext context) =>
      renderConfig.intentFor(context);

  /// Whether this relationship resolves to one record or many.
  BeakRelationCardinality get cardinality;
}
