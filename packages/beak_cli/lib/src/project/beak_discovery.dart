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

  /// A Dart expression evaluating to this symbol.
  String get expression => isConstructible ? 'const $name()' : name;

  /// The same expression without a leading `const`, for use inside a context
  /// that is already constant — where `const` would be flagged as redundant.
  String get constFreeExpression => isConstructible ? '$name()' : name;

  @override
  int compareTo(BeakDiscoveredSymbol other) {
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
    this.issues = const [],
  });

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

  /// Problems that must be fixed before generation can succeed.
  final List<BeakDiscoveryIssue> issues;

  /// A one-line summary, so a discovery miss is visible rather than silent.
  String get summary =>
      '${models.length} model${models.length == 1 ? '' : 's'} · '
      '${screens.length} screen${screens.length == 1 ? '' : 's'} · '
      '${overrides.length} override${overrides.length == 1 ? '' : 's'}';
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

  /// `lib/server.dart` — middleware, extra routes, policy.
  server(path: 'server.dart', symbol: 'beakServer');

  const BeakOverrideKind({required this.path, required this.symbol});

  /// Path relative to `lib/` this override lives at.
  final String path;

  /// Top-level function the file must declare for the override to apply.
  final String symbol;
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

  /// Scans the project and returns what it found.
  ///
  /// A class counts as a model when it extends `BeakModel` — directly, or via
  /// another class in the scanned set (one local hop, which covers the common
  /// shared-base-class pattern). A model must have a zero-argument `const`
  /// constructor so Beak can instantiate it; one that does not is reported as
  /// an issue naming the file, rather than silently skipped.
  BeakDiscovery scan() {
    final issues = <BeakDiscoveryIssue>[];
    final models = _scanClasses(
      modelsDir,
      supertype: 'BeakModel',
      issues: issues,
      requireConstConstructor: true,
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

    return BeakDiscovery(
      models: models,
      screens: screens,
      migrations: migrations,
      seeders: seeders,
      overrides: _scanOverrides(),
      issues: issues,
    );
  }

  /// Classes under `lib/<directory>` extending [supertype], in path order.
  List<BeakDiscoveredSymbol> _scanClasses(
    String directory, {
    required String supertype,
    required List<BeakDiscoveryIssue> issues,
    required bool requireConstConstructor,
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
        (_libRelativePath(file), _parse(file)),
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
            ),
          );
        }
      }
    }
    found.sort();
    return found;
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
        );
      }
    }
    return overrides;
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
