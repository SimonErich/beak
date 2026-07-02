/// Central registry resolving polymorphic morph-type strings.
library;

import '../exception/configuration_exception.dart';
import '../model/model.dart';

/// Hydrator that turns a raw row into a model of type [M].
typedef MorphHydrator<M extends Model> = M Function(Map<String, Object?>);

/// Registered binding for a single morph-type string.
///
/// Each registration stores the canonical morph-type string (as it
/// is written to the database), the Dart [type] it represents, the
/// snake_case [table] that holds rows for [type], and an optional
/// [hydrate] callback used by morph eager loaders that share the
/// registry instead of carrying their own per-relation maps.
final class MorphRegistration<M extends Model> {
  /// Creates a [MorphRegistration].
  const MorphRegistration({
    required this.morphType,
    required this.type,
    required this.table,
    this.hydrate,
  });

  /// Canonical morph-type string stored in `*_type` columns.
  final String morphType;

  /// Dart [Model] type identified by [morphType].
  final Type type;

  /// Snake_case table holding rows of [type].
  final String table;

  /// Optional hydrator producing a typed [M] from a raw row.
  final MorphHydrator<M>? hydrate;
}

/// Central morph-type registry.
///
/// Multiple polymorphic relations (e.g. `commentable`, `taggable`)
/// share one registry instance, so adding a new participating model
/// is a single [register] call instead of editing every per-relation
/// `MorphTo` definition. The registry is purely declarative; loaders
/// look up bindings by [morphTypeFor] or [registrationFor].
final class MorphRegistry {
  /// Creates an empty [MorphRegistry].
  MorphRegistry();

  final Map<String, MorphRegistration<Model>> _byMorphType =
      <String, MorphRegistration<Model>>{};
  final Map<Type, MorphRegistration<Model>> _byType =
      <Type, MorphRegistration<Model>>{};

  /// All registered bindings in registration order.
  List<MorphRegistration<Model>> get registrations =>
      List<MorphRegistration<Model>>.unmodifiable(_byMorphType.values);

  /// Register [registration].
  ///
  /// Throws [ConfigurationException] when the morph-type string or
  /// Dart type is already registered — the registry is the single
  /// source of truth for both directions of the mapping, so silently
  /// shadowing an existing entry would mask a real misconfiguration.
  void register<M extends Model>(MorphRegistration<M> registration) {
    if (_byMorphType.containsKey(registration.morphType)) {
      throw ConfigurationException(
        key: 'morph.duplicate.type',
        message:
            'Morph type "${registration.morphType}" is already '
            'registered to ${_byMorphType[registration.morphType]!.type}',
      );
    }
    if (_byType.containsKey(registration.type)) {
      throw ConfigurationException(
        key: 'morph.duplicate.dart',
        message:
            'Model ${registration.type} is already registered under '
            'morph type "${_byType[registration.type]!.morphType}"',
      );
    }
    final widened = MorphRegistration<Model>(
      morphType: registration.morphType,
      type: registration.type,
      table: registration.table,
      hydrate: registration.hydrate,
    );
    _byMorphType[registration.morphType] = widened;
    _byType[registration.type] = widened;
  }

  /// Drop every registration. Intended for tests.
  void clear() {
    _byMorphType.clear();
    _byType.clear();
  }

  /// Resolve the morph-type string for [type].
  ///
  /// Returns `null` when [type] is not registered.
  String? morphTypeFor(Type type) => _byType[type]?.morphType;

  /// Resolve the morph-type string for [type], throwing when unknown.
  ///
  /// Mirrors [morphTypeFor] but treats an unregistered [type] as a
  /// programmer error rather than a non-event: encoding a row requires
  /// a morph string and silently emitting `null` would corrupt the
  /// stored polymorphic association. Throws [ConfigurationException]
  /// with key `'morph.unknown'`.
  String morphNameFor(Type type) {
    final found = _byType[type]?.morphType;
    if (found == null) {
      throw ConfigurationException(
        key: 'morph.unknown',
        message: 'No morph type registered for $type',
      );
    }
    return found;
  }

  /// Resolve the Dart [Model] type for [morphType].
  ///
  /// Returns `null` when [morphType] is unknown.
  Type? typeFor(String morphType) => _byMorphType[morphType]?.type;

  /// Resolve the registration for [morphType], or `null`.
  MorphRegistration<Model>? registrationFor(String morphType) =>
      _byMorphType[morphType];

  /// Resolve the registration for Dart [type], or `null`.
  MorphRegistration<Model>? registrationForType(Type type) => _byType[type];

  /// `<morphType, table>` map of every registration. Convenient for
  /// callers that need the same data the per-relation morph
  /// definitions accept.
  Map<String, String> get tableMap => <String, String>{
    for (final entry in _byMorphType.entries) entry.key: entry.value.table,
  };
}
