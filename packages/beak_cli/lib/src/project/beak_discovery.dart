import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// One declaration Beak found in a project, and where it lives.
///
/// [importPath] is relative to `lib/`, ready to drop into a generated
/// `import` directive.
final class BeakDiscoveredSymbol implements Comparable<BeakDiscoveredSymbol> {
  /// Creates a discovered symbol.
  const BeakDiscoveredSymbol({
    required this.name,
    required this.importPath,
    required this.isConstructible,
    this.sortKey,
    this.table,
    this.alsoDeclares = const {},
  });

  /// The Dart identifier: a class name, or a top-level variable/function name.
  final String name;

  /// Path relative to `lib/`, e.g. `models/product.dart`.
  final String importPath;

  /// Whether [name] is a class Beak can write `const Name()` for.
  ///
  /// `false` for a top-level `final` variable or a zero-argument function,
  /// which the emitter references directly instead.
  final bool isConstructible;

  /// Optional companion functions the same file declares, by name.
  ///
  /// An override file may wire more than one thing; `lib/server.dart` adding
  /// `beakStorageRegistry` is how a project registers a plug-in upload driver.
  final Set<String> alsoDeclares;

  /// What this symbol sorts by ahead of its path, when it declares one.
  ///
  /// A migration's `name` getter carries its timestamp, and worm runs
  /// migrations in the order they are registered. Sorting by path instead
  /// would put `create_order_items_table.dart` before
  /// `create_orders_table.dart` and the foreign key would reference a table
  /// that does not exist yet.
  final String? sortKey;

  /// The physical table a model backs, when this symbol is one.
  ///
  /// Read from the declaration — an `@Resource(table:)` argument, or the
  /// model's own `String get table => '...';` — and never re-derived from the
  /// class name. `beak.yaml` is keyed by table, so a second derivation is a
  /// second answer: `@Resource(table: 'people')` on a class named `Person`
  /// silently lost its icon for as long as the emitter pluralised the class
  /// name instead of reading this.
  final String? table;

  /// A Dart expression evaluating to this symbol.
  String get expression => isConstructible ? 'const $name()' : name;

  /// The same expression without a leading `const`, for use inside a context
  /// that is already constant — where `const` would be flagged as redundant.
  String get constFreeExpression => isConstructible ? '$name()' : name;

  @override
  int compareTo(BeakDiscoveredSymbol other) {
    final String? key = sortKey;
    final String? otherKey = other.sortKey;
    if (key != null && otherKey != null) {
      final int byKey = key.compareTo(otherKey);
      if (byKey != 0) {
        return byKey;
      }
    }
    final int byPath = importPath.compareTo(other.importPath);
    return byPath != 0 ? byPath : name.compareTo(other.name);
  }

  @override
  String toString() => '$name ($importPath)';
}

/// A problem that stops generation, with the file that caused it.
final class BeakDiscoveryIssue {
  /// Creates an issue about [path].
  const BeakDiscoveryIssue({required this.path, required this.message});

  /// Project-relative path of the offending file.
  final String path;

  /// What is wrong, and what to do about it.
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Everything a scan of a project turned up.
final class BeakDiscovery {
  /// Creates a discovery result.
  const BeakDiscovery({
    this.models = const [],
    this.screens = const [],
    this.migrations = const [],
    this.seeders = const [],
    this.overrides = const {},
    this.resourceOverrides = const {},
    this.issues = const [],
    this.migratedTables = const <String>{},
  });

  /// Tables the discovered migrations create, read from the source.
  ///
  /// Read from the AST rather than inferred from file names, because one
  /// migration legitimately creates several tables — a single
  /// `CreateCommerceTables` builds six — and a name-based guess would decide
  /// five of them were missing and write duplicates.
  final Set<String> migratedTables;

  /// `BeakModel` subclasses under `lib/models/`, in path order.
  final List<BeakDiscoveredSymbol> models;

  /// `BeakScreen` declarations under `lib/screens/`, in path order.
  final List<BeakDiscoveredSymbol> screens;

  /// `Migration` subclasses under `lib/migrations/`, in path order.
  final List<BeakDiscoveredSymbol> migrations;

  /// `Seeder` subclasses under `lib/seeders/`, in path order.
  final List<BeakDiscoveredSymbol> seeders;

  /// Convention override files present in the project, by kind.
  final Map<BeakOverrideKind, BeakDiscoveredSymbol> overrides;

  /// `lib/resources/<table>.dart` files adjusting one generated resource,
  /// keyed by the table their file name names.
  ///
  /// The narrow escape hatch between "the defaults are fine" and
  /// `beak eject panel`: the file takes the generated [BeakResource] and
  /// returns a changed copy, so every other resource stays generated.
  final Map<String, BeakDiscoveredSymbol> resourceOverrides;

  /// Problems that must be fixed before generation can succeed.
  final List<BeakDiscoveryIssue> issues;

  /// A one-line summary, so a discovery miss is visible rather than silent.
  ///
  /// Both kinds of override count toward the one number: to the person who
  /// wrote them, `lib/theme.dart` and `lib/resources/products.dart` are the
  /// same thing — a file they added to change what Beak generated — and a
  /// summary that counted only the first reported "0 overrides" to a project
  /// that had just ejected one.
  String get summary {
    final int overrideCount = overrides.length + resourceOverrides.length;
    return '${models.length} model${models.length == 1 ? '' : 's'} · '
        '${screens.length} screen${screens.length == 1 ? '' : 's'} · '
        '$overrideCount override${overrideCount == 1 ? '' : 's'}';
  }
}

/// The convention files a project may supply to override a Beak default.
///
/// Each is optional: absent means Beak uses its own default, and nothing
/// about it appears in the project.
enum BeakOverrideKind {
  /// `lib/panel.dart` — the whole panel config, last word.
  panel(path: 'panel.dart', symbol: 'beakPanel'),

  /// `lib/theme.dart` — light and dark themes.
  theme(path: 'theme.dart', symbol: 'beakLightTheme'),

  /// `lib/auth.dart` — auth routes and callbacks.
  auth(path: 'auth.dart', symbol: 'beakAuth'),

  /// `lib/dashboard.dart` — replaces the generated `/` screen.
  dashboard(path: 'dashboard.dart', symbol: 'beakDashboard'),

  /// `lib/server.dart` — middleware, extra routes, policy, and optionally
  /// the storage registry a plug-in upload driver is registered into.
  server(
    path: 'server.dart',
    symbol: 'beakServer',
    optionalSymbols: {'beakStorageRegistry'},
  );

  const BeakOverrideKind({
    required this.path,
    required this.symbol,
    this.optionalSymbols = const {},
  });

  /// Path relative to `lib/` this override lives at.
  final String path;

  /// Top-level function the file must declare for the override to apply.
  final String symbol;

  /// Further functions the file may declare, each wiring one more thing.
  final Set<String> optionalSymbols;
}

/// Scans a Beak project for the declarations Beak wires up for you.
///
/// Discovery is an *unresolved* parse: it reads names and supertypes, never
/// types. That makes a scan of a large project take milliseconds, which is
/// what lets `beak dev` regenerate on every keystroke — and it is why a model
/// whose supertype is itself declared in another package cannot be found (see
/// [BeakProjectScanner.scan]).
final class BeakProjectScanner {
  /// Creates a scanner over [projectRoot].
  const BeakProjectScanner(this.projectRoot);

  /// The project directory holding `lib/` and `pubspec.yaml`.
  final Directory projectRoot;

  /// Directories scanned for each kind of declaration, relative to `lib/`.
  static const String modelsDir = 'models';

  /// Directory holding custom screens.
  static const String screensDir = 'screens';

  /// Directory holding hand-written migrations.
  static const String migrationsDir = 'migrations';

  /// Directory holding seeders.
  static const String seedersDir = 'seeders';

  /// Directory holding per-resource overrides, one file per table.
  static const String resourcesDir = 'resources';

  /// Top-level function a `lib/resources/<table>.dart` must declare.
  static const String resourceOverrideSymbol = 'beakResource';

  /// Scans the project and returns what it found.
  ///
  /// A class counts as a model when it extends `BeakModel` — directly, or via
  /// another class in the scanned set (one local hop, which covers the common
  /// shared-base-class pattern). A model must have a zero-argument `const`
  /// constructor so Beak can instantiate it; one that does not is reported as
  /// an issue naming the file, rather than silently skipped.
  BeakDiscovery scan({Map<String, String> tablesByModelClass = const {}}) {
    final issues = <BeakDiscoveryIssue>[];
    final models = _scanClasses(
      '',
      supertype: 'BeakModel',
      issues: issues,
      requireConstConstructor: true,
      tables: tablesByModelClass,
    );
    final migrations = _scanClasses(
      migrationsDir,
      supertype: 'Migration',
      issues: issues,
      requireConstConstructor: true,
    );
    final seeders = _scanClasses(
      seedersDir,
      supertype: 'Seeder',
      issues: issues,
      requireConstConstructor: true,
    );
    final screens = _scanScreens(issues);

    _rejectDuplicateNames(models, 'model', issues);

    final tables = <String>{
      for (final model in models)
        if (model.table case final String table) table,
    };
    return BeakDiscovery(
      models: models,
      screens: screens,
      migrations: migrations,
      seeders: seeders,
      overrides: _scanOverrides(),
      resourceOverrides: _scanResourceOverrides(tables, issues),
      issues: issues,
      migratedTables: _scanMigratedTables(),
    );
  }

  /// Classes under `lib/<directory>` extending [supertype], in path order.
  List<BeakDiscoveredSymbol> _scanClasses(
    String directory, {
    required String supertype,
    required List<BeakDiscoveryIssue> issues,
    required bool requireConstConstructor,
    Map<String, String> tables = const {},
  }) {
    final found = <BeakDiscoveredSymbol>[];
    // Two passes: the first collects classes extending the supertype
    // directly, the second picks up classes extending one of those (the
    // shared-local-base pattern). `visited` is keyed by declaration site, not
    // by name, so the second pass neither re-reports an issue the first
    // already raised nor hides two classes that genuinely share a name.
    final directBases = <String>{supertype};
    final visited = <String>{};
    final units = <(String, CompilationUnit)>[
      for (final file in _dartFilesUnder(directory))
        // A generated `*.beak.dart` is a part of the library beside it, and a
        // part cannot be imported. Attribute its declarations to that library
        // so the generated import resolves.
        (_owningLibraryPath(file), _parse(file)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    for (var pass = 0; pass < 2; pass++) {
      for (final (path, unit) in units) {
        for (final declaration in unit.declarations) {
          if (declaration is! ClassDeclaration) {
            continue;
          }
          final String? extended =
              declaration.extendsClause?.superclass.name.lexeme;
          if (extended == null || !directBases.contains(extended)) {
            continue;
          }
          final String name = declaration.name.lexeme;
          if (!visited.add('$path#$name')) {
            continue;
          }
          directBases.add(name);
          if (requireConstConstructor &&
              !_hasConstDefaultConstructor(declaration)) {
            issues.add(
              BeakDiscoveryIssue(
                path: 'lib/$path',
                message:
                    '$name extends $supertype but has no zero-argument const '
                    'constructor. Add `const $name();` so Beak can '
                    'instantiate it.',
              ),
            );
            continue;
          }
          found.add(
            BeakDiscoveredSymbol(
              name: name,
              importPath: path,
              isConstructible: true,
              sortKey: _declaredNameOf(declaration),
              // The schema reader already parsed `@Resource(table:)`; for a
              // hand-written model the declaration itself carries it. Either
              // way it is read, never re-derived.
              table:
                  tables[name] ?? _declaredStringGetter(declaration, 'table'),
            ),
          );
        }
      }
    }
    found.sort();
    return found;
  }

  /// Every table the migrations under `lib/migrations/` create.
  ///
  /// Collects the string argument of every `schema.create('x', …)` and
  /// `schema.alter('x', …)`, plus the relation constant every
  /// `BeakBlueprint.createPivot` names its pivot through. Unresolved AST, so
  /// it costs a parse and nothing else.
  Set<String> _scanMigratedTables() {
    final tables = <String>{};
    for (final file in _dartFilesUnder(migrationsDir)) {
      _collectMigratedTables(_parse(file), tables);
    }
    return tables;
  }

  /// Walks [node] collecting the tables its schema calls name.
  static void _collectMigratedTables(AstNode node, Set<String> into) {
    if (node is MethodInvocation) {
      const schemaCalls = <String>{'create', 'alter'};
      final String method = node.methodName.name;
      if (schemaCalls.contains(method) || method == 'createPivot') {
        for (final argument in node.argumentList.arguments) {
          if (argument case final SimpleStringLiteral literal) {
            into.add(literal.value);
          }
          // `createPivot(…, ownerTable: 'products')` is deliberately NOT
          // collected. It names which side of the relationship owns the
          // pivot, not a table the migration creates — and recording it made
          // a pivot migration vouch for its owner, so deleting
          // `create_products_table.dart` left `products` looking covered and
          // `beak prepare` never wrote it back. That is gap A returning
          // through the check meant to prevent it.

          // A pivot names its table through a relation constant, which
          // unresolved AST cannot follow. Record the constant itself; the
          // emitter knows which pivot each one stands for.
          if (argument case PrefixedIdentifier(
            prefix: SimpleIdentifier(name: final String owner),
            identifier: SimpleIdentifier(name: final String field),
          ) when owner.endsWith('Relations')) {
            into.add('$owner.$field');
          }
        }
      }
    }
    for (final child in node.childEntities) {
      if (child is AstNode) {
        _collectMigratedTables(child, into);
      }
    }
  }

  /// The string a class's `String get name => '...';` returns, when it has
  /// one — a migration's timestamped identity.
  static String? _declaredNameOf(ClassDeclaration declaration) =>
      _declaredStringGetter(declaration, 'name');

  /// The string a class's `String get <getter> => '...';` returns.
  ///
  /// The one AST read behind both a migration's `name` and a hand-written
  /// model's `table`.
  static String? _declaredStringGetter(
    ClassDeclaration declaration,
    String getter,
  ) {
    for (final member in declaration.members) {
      if (member is! MethodDeclaration || !member.isGetter) {
        continue;
      }
      if (member.name.lexeme != getter) {
        continue;
      }
      if (member.body case final ExpressionFunctionBody body) {
        if (body.expression case final SimpleStringLiteral literal) {
          return literal.value;
        }
      }
    }
    return null;
  }

  /// `BeakScreen` declarations: a top-level variable of that type, or a
  /// zero-argument function returning one.
  List<BeakDiscoveredSymbol> _scanScreens(List<BeakDiscoveryIssue> issues) {
    final found = <BeakDiscoveredSymbol>[];
    for (final file in _dartFilesUnder(screensDir)) {
      final String path = _libRelativePath(file);
      final unit = _parse(file);
      for (final declaration in unit.declarations) {
        if (declaration is TopLevelVariableDeclaration) {
          if (_typeName(declaration.variables.type) != 'BeakScreen') {
            continue;
          }
          for (final variable in declaration.variables.variables) {
            found.add(
              BeakDiscoveredSymbol(
                name: variable.name.lexeme,
                importPath: path,
                isConstructible: false,
              ),
            );
          }
        } else if (declaration is FunctionDeclaration) {
          if (_typeName(declaration.returnType) != 'BeakScreen') {
            continue;
          }
          final parameters =
              declaration.functionExpression.parameters?.parameters ??
              const <FormalParameter>[];
          if (parameters.any((parameter) => parameter.isRequired)) {
            issues.add(
              BeakDiscoveryIssue(
                path: 'lib/$path',
                message:
                    '${declaration.name.lexeme} returns a BeakScreen but takes '
                    'required arguments. Beak calls it with none — give the '
                    'parameters defaults or build the screen in a variable.',
              ),
            );
            continue;
          }
          found.add(
            BeakDiscoveredSymbol(
              name: '${declaration.name.lexeme}()',
              importPath: path,
              isConstructible: false,
            ),
          );
        }
      }
    }
    found.sort();
    return found;
  }

  /// The override files present, keyed by kind.
  Map<BeakOverrideKind, BeakDiscoveredSymbol> _scanOverrides() {
    final overrides = <BeakOverrideKind, BeakDiscoveredSymbol>{};
    for (final kind in BeakOverrideKind.values) {
      final file = File('${projectRoot.path}/lib/${kind.path}');
      if (!file.existsSync()) {
        continue;
      }
      final unit = _parse(file);
      final bool declaresSymbol = unit.declarations.any(
        (declaration) =>
            declaration is FunctionDeclaration &&
            declaration.name.lexeme == kind.symbol,
      );
      if (declaresSymbol) {
        overrides[kind] = BeakDiscoveredSymbol(
          name: kind.symbol,
          importPath: kind.path,
          isConstructible: false,
          alsoDeclares: {
            for (final optional in kind.optionalSymbols)
              if (unit.declarations.any(
                (declaration) =>
                    declaration is FunctionDeclaration &&
                    declaration.name.lexeme == optional,
              ))
                optional,
          },
        );
      }
    }
    return overrides;
  }

  /// `lib/resources/<table>.dart` files declaring [resourceOverrideSymbol].
  ///
  /// The file name *is* the key, so a typo would otherwise be a file that
  /// silently does nothing; a name matching no known table is an issue.
  Map<String, BeakDiscoveredSymbol> _scanResourceOverrides(
    Set<String> tables,
    List<BeakDiscoveryIssue> issues,
  ) {
    final overrides = <String, BeakDiscoveredSymbol>{};
    for (final file in _dartFilesUnder(resourcesDir)) {
      final String path = _libRelativePath(file);
      // Resource-local schemas, screens and configuration classes are not
      // legacy top-level per-table override functions.
      if (path.split('/').length != 2) continue;
      final unit = _parse(file);
      if (unit.declarations.any(
        (declaration) => declaration is ClassDeclaration,
      )) {
        continue;
      }
      final String table = path
          .split('/')
          .last
          .replaceAll(RegExp(r'\.dart$'), '');
      final bool declaresSymbol = unit.declarations.any(
        (declaration) =>
            declaration is FunctionDeclaration &&
            declaration.name.lexeme == resourceOverrideSymbol,
      );
      if (!declaresSymbol) {
        issues.add(
          BeakDiscoveryIssue(
            path: 'lib/$path',
            message:
                'A resource override must declare '
                '"BeakResource $resourceOverrideSymbol(BeakResource '
                'generated)". Without it the file is never called.',
          ),
        );
        continue;
      }
      if (!tables.contains(table)) {
        issues.add(
          BeakDiscoveryIssue(
            path: 'lib/$path',
            message:
                'No model declares the table "$table". A resource override '
                'is named after the table it adjusts'
                '${_nearest(table, tables)}.',
          ),
        );
        continue;
      }
      overrides[table] = BeakDiscoveredSymbol(
        name: resourceOverrideSymbol,
        importPath: path,
        isConstructible: false,
      );
    }
    return overrides;
  }

  /// `, did you mean "orders"?` when one candidate is close enough.
  static String _nearest(String name, Set<String> candidates) {
    for (final candidate in candidates) {
      if (_isNear(name, candidate)) {
        return ' — did you mean "$candidate"?';
      }
    }
    return '';
  }

  /// Whether [a] and [b] differ by at most one edit, ignoring case.
  static bool _isNear(String a, String b) {
    final String left = a.toLowerCase();
    final String right = b.toLowerCase();
    if ((left.length - right.length).abs() > 1) {
      return false;
    }
    var edits = 0;
    var i = 0;
    var j = 0;
    while (i < left.length && j < right.length) {
      if (left[i] == right[j]) {
        i += 1;
        j += 1;
        continue;
      }
      if (++edits > 1) {
        return false;
      }
      if (left.length > right.length) {
        i += 1;
      } else if (left.length < right.length) {
        j += 1;
      } else {
        i += 1;
        j += 1;
      }
    }
    return edits + (left.length - i) + (right.length - j) <= 1;
  }

  void _rejectDuplicateNames(
    List<BeakDiscoveredSymbol> symbols,
    String kind,
    List<BeakDiscoveryIssue> issues,
  ) {
    final seen = <String, String>{};
    for (final symbol in symbols) {
      final String? first = seen[symbol.name];
      if (first != null) {
        issues.add(
          BeakDiscoveryIssue(
            path: 'lib/${symbol.importPath}',
            message:
                'A $kind named ${symbol.name} is already declared in '
                'lib/$first. Generated imports would collide — rename one.',
          ),
        );
        continue;
      }
      seen[symbol.name] = symbol.importPath;
    }
  }

  /// Whether [declaration] has a zero-argument `const` unnamed constructor,
  /// or no constructor at all (Dart's implicit one, which is not const).
  bool _hasConstDefaultConstructor(ClassDeclaration declaration) {
    for (final member in declaration.members) {
      if (member is! ConstructorDeclaration || member.name != null) {
        continue;
      }
      final bool takesRequiredArguments = member.parameters.parameters.any(
        (parameter) => parameter.isRequired,
      );
      return member.constKeyword != null && !takesRequiredArguments;
    }
    return false;
  }

  String? _typeName(TypeAnnotation? type) =>
      type is NamedType ? type.name.lexeme : null;

  CompilationUnit _parse(File file) => parseString(
    content: file.readAsStringSync(),
    throwIfDiagnostics: false,
  ).unit;

  /// The import path declarations in [file] should be attributed to.
  ///
  /// For a generated part file, that is the library declaring it; for
  /// anything else, the file itself.
  String _owningLibraryPath(File file) {
    final String path = _libRelativePath(file);
    if (!path.endsWith('.beak.dart')) {
      return path;
    }
    return path.replaceFirst(RegExp(r'\.beak\.dart$'), '.dart');
  }

  String _libRelativePath(File file) {
    final String libPath = '${projectRoot.path}/lib/';
    return file.path.startsWith(libPath)
        ? file.path.substring(libPath.length)
        : file.path;
  }

  /// Dart files under `lib/<directory>`, skipping generated and private ones.
  Iterable<File> _dartFilesUnder(String directory) sync* {
    final root = Directory('${projectRoot.path}/lib/$directory');
    if (!root.existsSync()) {
      return;
    }
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String name = entity.uri.pathSegments.last;
      // `_foo.dart` is private by convention; `*.g.dart` is our own output.
      if (name.startsWith('_') || name.endsWith('.g.dart')) {
        continue;
      }
      yield entity;
    }
  }
}
