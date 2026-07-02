/// Consolidated morph (polymorphic) types: a generic
/// sealed [MorphTarget] union, the [MorphBinding] used
/// by `MorphTo` definitions, and a `toMorphTarget`
/// extension on raw rows.
///
/// The four morph relation kinds share their target
/// types here as one consolidated module — the
/// per-relation files (`morph_one.dart`,
/// `morph_many.dart`, `morph_to.dart`,
/// `morph_to_many.dart`) consume these types rather
/// than redefining them.
library;

import '../model/model.dart';

/// Canonical row key carrying the morph type string.
const String morphTypeKey = '_morphType';

/// Canonical row key carrying the morph id value.
const String morphIdKey = '_morphId';

/// Sealed union representing a morph reference resolved
/// against a known table registry.
///
/// Implementations exist for two cases:
///
/// - [GenericMorph]: the row's morph type was found in
///   the allowed-types registry. Carries the type
///   string, resolved table, and id.
/// - [UnresolvedMorph]: the row's morph type was null
///   or absent from the registry. Carries the raw type
///   string when one was present.
///
/// Pattern matching is exhaustive — no default branch.
sealed class MorphTarget {
  /// Const base constructor.
  const MorphTarget();
}

/// A morph reference whose type was recognized.
final class GenericMorph extends MorphTarget {
  /// Creates a [GenericMorph].
  const GenericMorph({
    required this.type,
    required this.table,
    required this.id,
  });

  /// Raw morph-type string as stored on the row.
  final String type;

  /// Table the type resolves to.
  final String table;

  /// Primary-key value of the referenced row.
  final Object id;
}

/// A morph reference whose type could not be resolved.
///
/// `rawType` is the value observed on the row (if any).
/// It is null when the row had no morph type at all.
final class UnresolvedMorph extends MorphTarget {
  /// Creates an [UnresolvedMorph].
  const UnresolvedMorph({this.rawType});

  /// Raw value of the morph-type column, when present.
  final String? rawType;
}

/// Extension exposing typed morph discrimination over
/// a raw row map.
extension MorphTargetMap on Map<String, Object?> {
  /// Returns a [GenericMorph] when this row's [morphTypeKey]
  /// is present in [allowedTypes] and a non-null id exists.
  ///
  /// Returns an [UnresolvedMorph] in every other case —
  /// missing type, unknown type, or missing id.
  ///
  /// Callers receive a [MorphTarget] union and never need
  /// to read `_morphType` / `_morphId` directly.
  MorphTarget toMorphTarget(Map<String, String> allowedTypes) {
    final rawType = this[morphTypeKey];
    if (rawType is! String) return const UnresolvedMorph();
    final table = allowedTypes[rawType];
    if (table == null) return UnresolvedMorph(rawType: rawType);
    final id = this[morphIdKey];
    if (id == null) return UnresolvedMorph(rawType: rawType);
    return GenericMorph(type: rawType, table: table, id: id);
  }
}

/// Per-type loading binding for a morph-to definition.
final class MorphBinding<S> {
  /// Creates a [MorphBinding].
  const MorphBinding({
    required this.table,
    required this.hydrate,
    required this.wrap,
    this.ownerKey = 'id',
  });

  /// Parent table for rows of this morph type.
  final String table;

  /// Hydrator turning a raw row into a [Model].
  final Model Function(Map<String, Object?>) hydrate;

  /// Wraps the hydrated parent into the sealed case [S].
  final S Function(Model) wrap;

  /// Primary-key column on the parent.
  final String ownerKey;
}
