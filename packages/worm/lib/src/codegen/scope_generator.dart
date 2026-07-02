/// Emits scope-metadata wiring for a model.
library;

import 'model_descriptor.dart';

/// Generates the scope metadata extension for a model.
///
/// Emits one artefact:
///
/// `extension <Model>WormScopes on <Model>$` — the `scopeNames`
/// and `globalScopes` metadata constants. The latter is the list
/// of registered `@GlobalScope`-tagged scopes that auto-apply to
/// every `QueryBuilder<Model>` created from the model's
/// `QueryContext`.
///
/// The typed `extension <Model>QueryScopes on QueryBuilder<Model>`
/// (with one wrapper per declared `LocalScope`) is emitted by
/// `QueryStarterGenerator`, not here, so the scope methods sit on
/// the query starter's output surface alongside `query()`.
final class ScopeGenerator {
  /// Creates a [ScopeGenerator] for [descriptor].
  const ScopeGenerator(this.descriptor);

  /// The model whose scope metadata is generated.
  final ModelDescriptor descriptor;

  /// Renders the scope metadata source.
  String generate() => _renderMetadataExtension();

  String _renderMetadataExtension() {
    final className = descriptor.className;
    final companion = descriptor.companionName;
    final buffer = StringBuffer()
      ..writeln('/// Declared scopes on $className.')
      ..writeln('extension ${className}WormScopes on $companion {')
      ..writeln('  /// Names of scopes declared on $className.')
      ..writeln('  static const List<String> scopeNames = <String>[');
    for (final scope in descriptor.scopes) {
      buffer.writeln("    '${scope.name}',");
    }
    buffer
      ..writeln('  ];')
      ..writeln()
      ..writeln('  /// Global scopes auto-applied to every')
      ..writeln('  /// QueryBuilder<$className>.')
      ..writeln('  static const List<GlobalScope<Model>> globalScopes =')
      ..writeln('      <GlobalScope<Model>>[');
    for (final type in descriptor.globalScopes) {
      buffer.writeln('    $type(),');
    }
    buffer
      ..writeln('  ];')
      ..writeln('}');
    return buffer.toString();
  }
}
