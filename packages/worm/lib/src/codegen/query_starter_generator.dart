/// Emits the query-starter extension and typed local-scope methods.
library;

import 'model_descriptor.dart';

/// Generates the `<Model>Query` entry-point extension and the
/// `<Model>QueryScopes` typed local-scope extension.
///
/// Output shape for a class `User` with a `PublishedScope` local
/// scope:
///
/// ```dart
/// extension UserQuery on User {
///   static QueryBuilder<User> query() => QueryBuilder<User>.from(
///     QueryContext<User>(
///       adapter: Worm.adapter(),
///       table: User$.tableName,
///       hydrate: UserHydration.fromRow,
///       globalScopes: const <GlobalScope<Model>>[
///         ActiveScope(),
///         SoftDeleteScope(),
///       ],
///     ),
///   );
/// }
///
/// extension UserQueryScopes on QueryBuilder<User> {
///   QueryBuilder<User> published() => scope(const PublishedScope());
/// }
/// ```
///
/// Calls the public `QueryBuilder` / `QueryContext` API only;
/// the generator never embeds the builder implementation. The
/// extension is emitted only when at least one scope carries a
/// `className`, so models without typed local scopes get no empty
/// extension block.
final class QueryStarterGenerator {
  /// Creates a [QueryStarterGenerator] for [descriptor].
  const QueryStarterGenerator(this.descriptor);

  /// The model whose query starter is generated.
  final ModelDescriptor descriptor;

  /// Renders the query-starter source.
  String generate() {
    final className = descriptor.className;
    final buffer = StringBuffer()
      ..writeln('/// Query starter for $className.')
      ..writeln('extension ${className}Query on $className {')
      ..write(_renderQuery())
      ..writeln('}');
    final typed = descriptor.scopes.where((s) => s.className != null).toList();
    if (typed.isNotEmpty) {
      buffer
        ..writeln()
        ..write(_renderScopeMethodsExtension(typed));
    }
    return buffer.toString();
  }

  String _renderQuery() {
    final className = descriptor.className;
    final companion = descriptor.companionName;
    final hydrator = '${className}Hydration.fromRow';
    final buffer = StringBuffer()
      ..writeln('  /// Starts a query against `${descriptor.tableName}`.')
      ..writeln('  static QueryBuilder<$className> query() =>')
      ..writeln('      QueryBuilder<$className>.from(')
      ..writeln('        QueryContext<$className>(')
      ..writeln('          adapter: Worm.adapter(),')
      ..writeln('          table: $companion.tableName,')
      ..writeln('          hydrate: $hydrator,')
      ..write('          globalScopes: ');
    if (descriptor.globalScopes.isEmpty) {
      buffer.writeln('const <GlobalScope<Model>>[],');
    } else {
      buffer.writeln('const <GlobalScope<Model>>[');
      for (final type in descriptor.globalScopes) {
        buffer.writeln('            $type(),');
      }
      buffer.writeln('          ],');
    }
    buffer
      ..writeln('        ),')
      ..writeln('      );');
    return buffer.toString();
  }

  String _renderScopeMethodsExtension(List<ScopeDescriptor> scopes) {
    final className = descriptor.className;
    final buffer = StringBuffer()
      ..writeln('/// Local scope methods generated for $className.')
      ..writeln(
        'extension ${className}QueryScopes on QueryBuilder<$className> {',
      );
    var first = true;
    for (final scope in scopes) {
      if (!first) buffer.writeln();
      first = false;
      buffer.write(_renderScopeMethod(className, scope));
    }
    buffer.writeln('}');
    return buffer.toString();
  }

  String _renderScopeMethod(String className, ScopeDescriptor scope) {
    final signature = scope.parameters
        .map((p) => '${p.type} ${p.name}')
        .join(', ');
    final args = scope.parameters.map((p) => p.name).join(', ');
    final ctor = args.isEmpty
        ? 'const ${scope.className}()'
        : '${scope.className}($args)';
    return [
      '  /// Apply the `${scope.name}` local scope.',
      '  QueryBuilder<$className> ${scope.name}($signature) =>',
      '      scope($ctor);',
      '',
    ].join('\n');
  }
}
