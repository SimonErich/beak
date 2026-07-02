/// Input metadata for model-level code generation.
library;

import 'column_descriptor.dart';
import 'relation_descriptor.dart';

/// A single positional parameter declared on a scope method.
final class ScopeParameter {
  /// Creates a [ScopeParameter].
  const ScopeParameter({required this.name, required this.type});

  /// Dart-side parameter identifier.
  final String name;

  /// Dart static type as it should appear in the generated
  /// signature, including any `?` for nullable types.
  final String type;
}

/// Describes a generator-visible scope on the model.
final class ScopeDescriptor {
  /// Creates a [ScopeDescriptor].
  const ScopeDescriptor({
    required this.name,
    this.parameters = const <ScopeParameter>[],
    this.className,
  });

  /// Scope identifier (also the Dart method name in
  /// camelCase). Passed to `QueryBuilder.applyScope` verbatim.
  final String name;

  /// Positional parameters mirrored on the generated method.
  final List<ScopeParameter> parameters;

  /// Name of the `LocalScope` subclass that backs this scope.
  ///
  /// When non-null the scope generator emits a typed
  /// `QueryBuilder<T>` extension method that instantiates the
  /// class with [parameters] and invokes `scope(...)` against it
  /// — e.g. `query.published()` for a `PublishedScope`. When
  /// null, only the legacy `scopeNames` metadata is emitted and
  /// the scope must be applied via `applyScope('name')`.
  final String? className;
}

/// Input to the worm codegen describing a single model.
///
/// Built either by `worm_generator` from an annotated source
/// file, or directly in unit tests.
final class ModelDescriptor {
  /// Creates a [ModelDescriptor].
  const ModelDescriptor({
    required this.className,
    required this.tableName,
    required this.columns,
    this.scopes = const <ScopeDescriptor>[],
    this.globalScopes = const <String>[],
    this.relations = const <RelationDescriptor>[],
    this.partOfImport,
  });

  /// Dart-side class name (PascalCase).
  final String className;

  /// Database-side table name (snake_case, plural).
  final String tableName;

  /// Column metadata in declaration order.
  final List<ColumnDescriptor> columns;

  /// Local scopes declared on the model.
  final List<ScopeDescriptor> scopes;

  /// Global-scope class names declared via `@GlobalScope` on
  /// the model. Emitted as `Type` literals in `query()`.
  final List<String> globalScopes;

  /// Relations declared on the model via `@HasOne`, `@HasMany`,
  /// etc. Emitted as `RelationField<T>` constants on the
  /// generated companion class — `RelationField<Child>` for
  /// single-valued relations and `RelationField<List<Child>>`
  /// for multi-valued relations.
  final List<RelationDescriptor> relations;

  /// Source file the generated code is a `part of`, e.g.
  /// `'user.dart'`. May be `null` when the generator emits
  /// a standalone library.
  final String? partOfImport;

  /// Convenience: the companion class name `User$`.
  String get companionName => '$className\$';
}
