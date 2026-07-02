/// Serializer with cycle detection and depth limiting.
library;

import 'dart:convert';

import 'serializable.dart';

/// Renders a [Serializable] (and its relation graph) to a
/// JSON-shaped `Map<String, Object?>`.
///
/// The serializer enforces three invariants:
///
/// * Fields listed in [SerializationDescriptor.hidden] are removed.
/// * Computed values listed in [SerializationDescriptor.appended]
///   are added under their own keys.
/// * Cycles are broken at the deepest already-seen node by replacing
///   the recursion with `{type, id, ref: true}`. Once a node is
///   serialized in full it stays cached so the same instance reused
///   elsewhere in the tree only emits a reference.
///
/// [maxDepth] caps how many nested relation levels are walked. When
/// the depth budget is exhausted, deeper relations collapse into the
/// same `{ref: true}` shorthand.
final class Serializer {
  /// Creates a [Serializer].
  const Serializer({this.maxDepth = 8})
    : assert(maxDepth >= 0, 'maxDepth must be non-negative');

  /// Maximum number of nested relation levels to traverse.
  final int maxDepth;

  /// Serialize [root] to a JSON-shaped map.
  Map<String, Object?> toMap(Serializable root) {
    final seen = <String, Map<String, Object?>>{};
    return _serialize(root, depth: 0, seen: seen);
  }

  /// Serialize [root] to a JSON string.
  String toJson(Serializable root) => jsonEncode(toMap(root));

  Map<String, Object?> _serialize(
    Serializable node, {
    required int depth,
    required Map<String, Map<String, Object?>> seen,
  }) {
    final key = '${node.serializationType}#${node.serializationId}';
    final cached = seen[key];
    if (cached != null) return _reference(node);
    final descriptor = node.describe();
    final entry = <String, Object?>{};
    seen[key] = entry;
    final included = _filterFields(descriptor);
    entry.addAll(included);
    for (final ap in descriptor.appended.entries) {
      if (!_isVisible(ap.key, descriptor)) continue;
      entry[ap.key] = ap.value;
    }
    if (depth >= maxDepth) return entry;
    for (final rel in descriptor.relations.entries) {
      if (!_isVisible(rel.key, descriptor)) continue;
      entry[rel.key] = _serializeRelation(
        rel.value,
        depth: depth + 1,
        seen: seen,
      );
    }
    return entry;
  }

  Map<String, Object?> _filterFields(SerializationDescriptor d) {
    final out = <String, Object?>{};
    for (final entry in d.fields.entries) {
      if (!_isVisible(entry.key, d)) continue;
      out[entry.key] = entry.value;
    }
    return out;
  }

  bool _isVisible(String key, SerializationDescriptor d) {
    if (d.hidden.contains(key)) return false;
    final whitelist = d.visible;
    if (whitelist != null && !whitelist.contains(key)) return false;
    return true;
  }

  Object? _serializeRelation(
    Object value, {
    required int depth,
    required Map<String, Map<String, Object?>> seen,
  }) {
    if (value is Serializable) {
      return _serialize(value, depth: depth, seen: seen);
    }
    if (value is List<Serializable>) {
      return <Map<String, Object?>>[
        for (final item in value) _serialize(item, depth: depth, seen: seen),
      ];
    }
    return null;
  }

  Map<String, Object?> _reference(Serializable node) => <String, Object?>{
    'type': node.serializationType,
    'id': node.serializationId,
    'ref': true,
  };
}
