import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

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
    this.isConstVariable = false,
    this.sortKey,
    this.table,
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

  /// Whether [name] is a top-level `const` variable, so referencing it is a
  /// constant expression, as `const Name()` is for a constructible class.
  final bool isConstVariable;

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

/// A `BeakResource` subclass the project wrote, and where it lives.
///
/// The generated panel builds one with its unnamed constructor and uses it in
/// place of the default resource of the model it configures, so writing the
/// class is all it takes to customise one resource while every other stays
/// generated.
final class BeakDiscoveredResource
    implements Comparable<BeakDiscoveredResource> {
  /// Creates a discovered resource class.
  const BeakDiscoveredResource({
    required this.className,
    required this.importPath,
    required this.isConst,
    this.modelClass,
  });

  /// The class name, e.g. `ProductResource`.
  final String className;

  /// Path relative to `lib/`, e.g. `resources/products/product_resource.dart`.
  final String importPath;

  /// Whether its unnamed constructor is `const`.
  final bool isConst;

  /// The `BeakModel` class its constructor passes as `model:`, when the
  /// source names one literally (`model: const ProductModel()`).
  ///
  /// The generated panel matches resources to models at runtime, by table,
  /// so this is only a hint for the commands that write Dart a person then
  /// owns, such as `beak eject main`.
  final String? modelClass;

  /// A Dart expression constructing the resource.
  String get expression => isConst ? 'const $className()' : '$className()';

  /// Whether this class configures the model class [model].
  ///
  /// By the model its constructor names, or, when the source does not name
  /// one literally, by the naming convention every Beak scaffold follows:
  /// `NoteResource` configures `NoteModel`.
  bool configures(String model) =>
      modelClass == model ||
      (modelClass == null && className == conventionalNameFor(model));

  /// The resource class name Beak scaffolds for [modelClass]:
  /// `OrderItemModel` -> `OrderItemResource`.
  static String conventionalNameFor(String modelClass) =>
      '${modelClass.endsWith('Model') ? modelClass.substring(0, modelClass.length - 'Model'.length) : modelClass}Resource';

  @override
  int compareTo(BeakDiscoveredResource other) {
    final int byPath = importPath.compareTo(other.importPath);
    return byPath != 0 ? byPath : className.compareTo(other.className);
  }

  @override
  String toString() => '$className ($importPath)';
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
    this.resources = const [],
    this.overrides = const {},
    this.storageRegistry,
    this.issues = const [],
    this.migratedTables = const <String>{},
    this.tablesCreatedByMigration = const <String, Set<String>>{},
    this.migrationsDeclaringKeys = const <String>{},
  });

  /// Tables the discovered migrations create, read from the source.
  ///
  /// Read from the AST rather than inferred from file names, because one
  /// migration legitimately creates several tables — a single
  /// `CreateCommerceTables` builds six — and a name-based guess would decide
  /// five of them were missing and write duplicates.
  final Set<String> migratedTables;

  /// The tables each migration creates with `schema.create`, by the migration's
  /// class name.
  ///
  /// [migratedTables] also counts a table a migration only alters. This does
  /// not, because it answers a different question: which migration has to run
  /// before which, when one table has a foreign key to another.
  final Map<String, Set<String>> tablesCreatedByMigration;

  /// The migrations, by class name, whose tables get their foreign keys from
  /// the model: those that call `BeakBlueprint.defineForeignKeys`.
  ///
  /// A create migration frozen to the columns a table had on day one names no
  /// foreign key, so whatever the model points at today is not something that
  /// migration needs to exist first.
  final Set<String> migrationsDeclaringKeys;

  /// `BeakModel` subclasses anywhere under `lib/`, in path order, including
  /// the models `beak prepare` generates from schema classes.
  final List<BeakDiscoveredSymbol> models;

  /// `BeakResource` subclasses anywhere under `lib/`, in path order.
  ///
  /// Only classes Beak can build: public, not abstract, and with an unnamed
  /// constructor that takes no required arguments. A resource that needs
  /// arguments is composed by hand, and the generated panel keeps the
  /// default for its model.
  final List<BeakDiscoveredResource> resources;

  /// `BeakScreen` declarations under `lib/screens/`, in path order.
  final List<BeakDiscoveredSymbol> screens;

  /// `Migration` subclasses under `lib/migrations/`, in path order.
  final List<BeakDiscoveredSymbol> migrations;

  /// `Seeder` subclasses under `lib/seeders/`, in path order.
  final List<BeakDiscoveredSymbol> seeders;

  /// Convention override files present in the project, by kind.
  final Map<BeakOverrideKind, BeakDiscoveredSymbol> overrides;

  /// The `beakStorageRegistry()` in `lib/server.dart`, when it declares one.
  ///
  /// Independent of the `beakServer` override: registering a plug-in upload
  /// driver is not a reason to take over the whole server.
  final BeakDiscoveredSymbol? storageRegistry;

  /// Problems that must be fixed before generation can succeed.
  final List<BeakDiscoveryIssue> issues;

  /// This discovery with [migrations] registered in the given order instead.
  BeakDiscovery withMigrations(List<BeakDiscoveredSymbol> migrations) =>
      BeakDiscovery(
        models: models,
        screens: screens,
        migrations: migrations,
        seeders: seeders,
        resources: resources,
        overrides: overrides,
        storageRegistry: storageRegistry,
        issues: issues,
        migratedTables: migratedTables,
        tablesCreatedByMigration: tablesCreatedByMigration,
        migrationsDeclaringKeys: migrationsDeclaringKeys,
      );

  /// A one-line summary, so a discovery miss is visible rather than silent.
  ///
  /// Resource classes are counted on their own: to the person who wrote
  /// one, a summary that did not mention it reads as "your file was not
  /// picked up".
  String get summary =>
      '${_count(models.length, 'model')} · '
      '${_count(resources.length, 'resource class', 'resource classes')} · '
      '${_count(screens.length, 'screen')} · '
      '${_count(overrides.length, 'override')}';

  /// The summary of a project whose panel is built by the file at
  /// [entrypoint], not by Beak.
  ///
  /// The generated panel finds `lib/screens/` and the override files itself.
  /// An authored one lists its pages and takes its theme where it is written,
  /// so counting them here describes nothing the panel uses.
  String summaryOfAuthored(String entrypoint) =>
      '${_count(models.length, 'model')} · '
      '${_count(resources.length, 'resource class', 'resource classes')} · '
      'screens and overrides not applicable ($entrypoint is authored)';

  static String _count(int count, String one, [String? many]) =>
      '$count ${count == 1 ? one : many ?? '${one}s'}';
}

// --8<-- [start:beakOverrideKind]
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

  /// `lib/server.dart` — middleware, extra routes and policy.
  server(path: 'server.dart', symbol: 'beakServer');

  const BeakOverrideKind({required this.path, required this.symbol});
  // --8<-- [end:beakOverrideKind]

  /// Path relative to `lib/` this override lives at.
  final String path;

  /// Top-level function the file must declare for the override to apply.
  final String symbol;
}

/// Scans a Beak project for the declarations Beak wires up for you.
///
/// Discovery is an *unresolved* parse: it reads names and supertypes, never
/// types. That makes a scan of a large project take milliseconds, which keeps
/// `beak prepare` cheap enough to run before every `beak dev`, and it is why a
/// model whose supertype is itself declared in another package cannot be found
/// (see [BeakProjectScanner.scan]).
final class BeakProjectScanner {
  /// Creates a scanner over [projectRoot].
  const BeakProjectScanner(this.projectRoot);

  /// The project directory holding `lib/` and `pubspec.yaml`.
  final Directory projectRoot;

  /// Directory, relative to `lib/`, holding custom screens.
  static const String screensDir = 'screens';

  /// Directory, relative to `lib/`, holding hand-written migrations.
  static const String migrationsDir = 'migrations';

  /// Directory, relative to `lib/`, holding seeders.
  static const String seedersDir = 'seeders';

  /// Directory, relative to `lib/`, holding one folder per feature: its schema
  /// classes under `models/`, its screens, and its `BeakResource` class.
  ///
  /// Models and resource classes are found anywhere under `lib/`; this is the
  /// folder `beak make:resource` writes them to.
  static const String resourcesDir = 'resources';

  /// The function `lib/server.dart` declares to register storage drivers.
  static const String storageRegistrySymbol = 'beakStorageRegistry';

  /// The class `beak introspect` extends to adopt an existing schema.
  ///
  /// A migration by another name: it is discovered under `lib/migrations/`
  /// like any other, and additionally vouches for the tables it lists.
  static const String baselineMigrationSupertype = 'BeakBaselineMigration';

  /// Scans the project and returns what it found.
  ///
  /// A class counts as a model when it extends `BeakModel` — directly, or via
  /// another class in the scanned set (one local hop, which covers the common
  /// shared-base-class pattern). A model must have a zero-argument `const`
  /// constructor so Beak can instantiate it; one that does not is reported as
  /// an issue naming the file, rather than silently skipped.
  BeakDiscovery scan({Map<String, String> tablesByModelClass = const {}}) {
    final issues = <BeakDiscoveryIssue>[];
    final List<BeakDiscoveredSymbol> models = _scanModels(
      issues,
      tablesByModelClass,
    );
    final migrations = _scanClasses(
      migrationsDir,
      supertype: 'Migration',
      alsoExtending: const {baselineMigrationSupertype},
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
    final resources = _scanResources(issues);

    _rejectRemovedOverrides(issues);

    final (overrides, storageRegistry) = _scanOverrides();
    final tableOfModel = <String, String>{
      for (final model in models)
        if (model.table case final String table) model.name: table,
    };
    return BeakDiscovery(
      models: models,
      resources: resources,
      screens: screens,
      migrations: migrations,
      seeders: seeders,
      overrides: overrides,
      storageRegistry: storageRegistry,
      issues: issues,
      migratedTables: _scanMigratedTables(tableOfModel),
      tablesCreatedByMigration: _scanTablesCreatedByMigration(tableOfModel),
      migrationsDeclaringKeys: _scanMigrationsDeclaringKeys(),
    );
  }

  /// Scans for the models alone, ignoring everything else a Beak app holds.
  ///
  /// What `beak prepare` reads in a package that only holds schema classes:
  /// no resources, screens, migrations, seeders or override files, so none of
  /// their issues either. The models and the issues about them are the same
  /// as [scan] reports.
  BeakDiscovery scanModels({
    Map<String, String> tablesByModelClass = const {},
  }) {
    final issues = <BeakDiscoveryIssue>[];
    final List<BeakDiscoveredSymbol> models = _scanModels(
      issues,
      tablesByModelClass,
    );
    return BeakDiscovery(models: models, issues: issues);
  }

  /// Every `BeakModel` under `lib/`, with duplicate names reported in
  /// [issues].
  List<BeakDiscoveredSymbol> _scanModels(
    List<BeakDiscoveryIssue> issues,
    Map<String, String> tables,
  ) {
    final List<BeakDiscoveredSymbol> models = _scanClasses(
      '',
      supertype: 'BeakModel',
      issues: issues,
      requireConstConstructor: true,
      tables: tables,
      excluding: _commandModelNames(),
    );
    _rejectDuplicateNames(models, 'model', issues);
    return models;
  }

  /// The classes a model hands out as its `createModel` or `editModel`.
  ///
  /// A command model describes the write shape of a table another model
  /// already owns, so it is reachable from that model and never a registry
  /// entry of its own: the registry refuses a second model for one table.
  Set<String> _commandModelNames() {
    final names = <String>{};
    for (final file in _dartFilesUnder('')) {
      for (final declaration in _parse(file).declarations) {
        if (declaration is! ClassDeclaration) {
          continue;
        }
        for (final member in declaration.members) {
          if (member is MethodDeclaration &&
              member.isGetter &&
              _commandModelGetters.contains(member.name.lexeme)) {
            member.body.accept(_IdentifierCollector(names));
          }
        }
      }
    }
    return names;
  }

  static const Set<String> _commandModelGetters = {'createModel', 'editModel'};

  /// Classes under `lib/<directory>` extending [supertype], in path order.
  ///
  /// A private or abstract class is followed as a base but never listed: the
  /// generated code could not name it or build it. A class in [excluding] is
  /// skipped the same way.
  List<BeakDiscoveredSymbol> _scanClasses(
    String directory, {
    required String supertype,
    Set<String> alsoExtending = const {},
    required List<BeakDiscoveryIssue> issues,
    required bool requireConstConstructor,
    Map<String, String> tables = const {},
    Set<String> excluding = const {},
  }) {
    final found = <BeakDiscoveredSymbol>[];
    // Two passes: the first collects classes extending the supertype
    // directly, the second picks up classes extending one of those (the
    // shared-local-base pattern). `visited` is keyed by declaration site, not
    // by name, so the second pass neither re-reports an issue the first
    // already raised nor hides two classes that genuinely share a name.
    final directBases = <String>{supertype, ...alsoExtending};
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
          if (name.startsWith('_') ||
              declaration.abstractKeyword != null ||
              excluding.contains(name)) {
            continue;
          }
          if (requireConstConstructor &&
              !_hasConstDefaultConstructor(declaration)) {
            issues.add(
              BeakDiscoveryIssue(
                path: 'lib/$path',
                message:
                    '$name extends $extended but has no zero-argument const '
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
  /// `BeakBlueprint.createPivot` names its pivot through. A
  /// `BeakBaselineMigration` covers what it lists: the table of each model in
  /// its `models`, found through [tableOfModel], and each relation constant in
  /// its `pivots`. Unresolved AST, so it costs a parse and nothing else.
  Set<String> _scanMigratedTables(Map<String, String> tableOfModel) {
    final tables = <String>{};
    for (final file in _dartFilesUnder(migrationsDir)) {
      _collectMigratedTables(_parse(file), tables, tableOfModel);
    }
    return tables;
  }

  /// The tables each migration class creates, by class name.
  ///
  /// `schema.create('x', …)` calls only, plus the models a
  /// `BeakBaselineMigration` lists, which it creates through their table.
  Map<String, Set<String>> _scanTablesCreatedByMigration(
    Map<String, String> tableOfModel,
  ) {
    final created = <String, Set<String>>{};
    for (final file in _dartFilesUnder(migrationsDir)) {
      for (final declaration in _parse(file).declarations) {
        if (declaration is! ClassDeclaration) {
          continue;
        }
        final tables = <String>{};
        if (declaration.extendsClause?.superclass.name.lexeme ==
            baselineMigrationSupertype) {
          _collectBaselineCoverage(declaration, tables, tableOfModel);
          // A pivot is recorded as `Owner.field`, which is not a table name.
          tables.removeWhere((table) => table.contains('.'));
        }
        _collectCreatedTables(declaration, tables);
        if (tables.isNotEmpty) {
          created[declaration.name.lexeme] = tables;
        }
      }
    }
    return created;
  }

  /// The migration classes that call `defineForeignKeys`.
  Set<String> _scanMigrationsDeclaringKeys() {
    final declaring = <String>{};
    for (final file in _dartFilesUnder(migrationsDir)) {
      for (final declaration in _parse(file).declarations) {
        if (declaration is ClassDeclaration &&
            _callsMethod(declaration, 'defineForeignKeys')) {
          declaring.add(declaration.name.lexeme);
        }
      }
    }
    return declaring;
  }

  /// Whether [node] contains a call to a method named [name].
  static bool _callsMethod(AstNode node, String name) {
    if (node is MethodInvocation && node.methodName.name == name) {
      return true;
    }
    return node.childEntities.any(
      (child) => child is AstNode && _callsMethod(child, name),
    );
  }

  /// Adds the table of every `create('x', …)` call below [node] to [into].
  static void _collectCreatedTables(AstNode node, Set<String> into) {
    if (node is MethodInvocation && node.methodName.name == 'create') {
      if (node.argumentList.arguments.firstOrNull
          case final SimpleStringLiteral table) {
        into.add(table.value);
      }
    }
    for (final child in node.childEntities) {
      if (child is AstNode) {
        _collectCreatedTables(child, into);
      }
    }
  }

  /// Walks [node] collecting the tables its schema calls name.
  static void _collectMigratedTables(
    AstNode node,
    Set<String> into,
    Map<String, String> tableOfModel,
  ) {
    if (node is ClassDeclaration &&
        node.extendsClause?.superclass.name.lexeme ==
            baselineMigrationSupertype) {
      _collectBaselineCoverage(node, into, tableOfModel);
    }
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
        _collectMigratedTables(child, into, tableOfModel);
      }
    }
  }

  /// What the `models` and `pivots` getters of the baseline [declaration]
  /// list, added to [into].
  ///
  /// A model is written `const ProductModel()` and stands for its table; a
  /// pivot is written `ProductRelations.tags` and is recorded the way a
  /// `createPivot` call records it, so `beak prepare` recognises it as
  /// already created.
  static void _collectBaselineCoverage(
    ClassDeclaration declaration,
    Set<String> into,
    Map<String, String> tableOfModel,
  ) {
    for (final member in declaration.members) {
      if (member is! MethodDeclaration || !member.isGetter) {
        continue;
      }
      final Set<Expression> listed = switch (member.body) {
        ExpressionFunctionBody(:final ListLiteral expression) => {
          ...expression.elements.whereType<Expression>(),
        },
        _ => const {},
      };
      switch (member.name.lexeme) {
        case 'models':
          for (final element in listed) {
            final String? model = _constructedClassOf(element);
            if (tableOfModel[model] case final String table) {
              into.add(table);
            }
          }
        case 'pivots':
          for (final element in listed) {
            if (element case PrefixedIdentifier(
              prefix: SimpleIdentifier(name: final String owner),
              identifier: SimpleIdentifier(name: final String field),
            ) when owner.endsWith('Relations')) {
              into.add('$owner.$field');
            }
          }
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
          // A variable without an annotation is a screen when its initializer
          // builds one; the unresolved parse has no other way to tell.
          final String? declared = _typeName(declaration.variables.type);
          for (final variable in declaration.variables.variables) {
            final String? type =
                declared ??
                switch (variable.initializer) {
                  final Expression initializer => _constructedClassOf(
                    initializer,
                  ),
                  null => null,
                };
            if (type != 'BeakScreen') {
              continue;
            }
            found.add(
              BeakDiscoveredSymbol(
                name: variable.name.lexeme,
                importPath: path,
                isConstructible: false,
                isConstVariable: declaration.variables.isConst,
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
                    'required arguments. Beak calls it with none: give the '
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

  /// The override files present, keyed by kind, and the storage registry.
  (Map<BeakOverrideKind, BeakDiscoveredSymbol>, BeakDiscoveredSymbol?)
  _scanOverrides() {
    final overrides = <BeakOverrideKind, BeakDiscoveredSymbol>{};
    for (final kind in BeakOverrideKind.values) {
      if (_declaresFunction(kind.path, kind.symbol)) {
        overrides[kind] = BeakDiscoveredSymbol(
          name: kind.symbol,
          importPath: kind.path,
          isConstructible: false,
        );
      }
    }
    final String serverPath = BeakOverrideKind.server.path;
    final BeakDiscoveredSymbol? storageRegistry =
        _declaresFunction(serverPath, storageRegistrySymbol)
        ? BeakDiscoveredSymbol(
            name: storageRegistrySymbol,
            importPath: serverPath,
            isConstructible: false,
          )
        : null;
    return (overrides, storageRegistry);
  }

  /// Whether `lib/[path]` exists and declares a top-level function [name].
  bool _declaresFunction(String path, String name) {
    final file = File('${projectRoot.path}/lib/$path');
    if (!file.existsSync()) {
      return false;
    }
    return _parse(file).declarations.any(
      (declaration) =>
          declaration is FunctionDeclaration && declaration.name.lexeme == name,
    );
  }

  /// `BeakResource` subclasses Beak can build, anywhere under `lib/`.
  ///
  /// Two passes, like models: the first finds classes extending
  /// `BeakResource` directly, the second those extending one of them, which
  /// covers a shared local base such as `abstract class ShopResource`.
  List<BeakDiscoveredResource> _scanResources(List<BeakDiscoveryIssue> issues) {
    final units = <(String, CompilationUnit)>[
      for (final file in _dartFilesUnder(''))
        if (!file.path.endsWith('.beak.dart'))
          (_libRelativePath(file), _parse(file)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final bases = <String>{'BeakResource'};
    final visited = <String>{};
    final found = <BeakDiscoveredResource>[];
    for (var pass = 0; pass < 2; pass++) {
      for (final (path, unit) in units) {
        for (final declaration in unit.declarations) {
          if (declaration is! ClassDeclaration) {
            continue;
          }
          final String? extended =
              declaration.extendsClause?.superclass.name.lexeme;
          final String name = declaration.name.lexeme;
          if (extended == null ||
              !bases.contains(extended) ||
              !visited.add('$path#$name')) {
            continue;
          }
          bases.add(name);
          final bool isAbstract =
              declaration.abstractKeyword != null ||
              declaration.sealedKeyword != null;
          final ConstructorDeclaration? constructor = _unnamedConstructorOf(
            declaration,
          );
          // Without an unnamed constructor, `Name()` only compiles when the
          // class declares no constructor at all and so gets the implicit
          // one; declaring only named constructors removes it.
          final bool buildable = constructor == null
              ? !declaration.members.any(
                  (member) => member is ConstructorDeclaration,
                )
              : !constructor.parameters.parameters.any(
                  (parameter) => parameter.isRequired,
                );
          // A private class cannot be imported by the generated panel, and
          // an abstract one or one needing arguments cannot be built by it.
          if (isAbstract || !buildable || name.startsWith('_')) {
            continue;
          }
          found.add(
            BeakDiscoveredResource(
              className: name,
              importPath: path,
              isConst: constructor?.constKeyword != null,
              modelClass: constructor == null
                  ? null
                  : _modelClassOf(constructor),
            ),
          );
        }
      }
    }
    found.sort();

    final seen = <String, String>{};
    for (final resource in found) {
      final String? first = seen[resource.className];
      if (first != null) {
        issues.add(
          BeakDiscoveryIssue(
            path: 'lib/${resource.importPath}',
            message:
                'A resource class named ${resource.className} is already '
                'declared in lib/$first. The generated panel imports both, '
                'so the names would collide; rename one.',
          ),
        );
        continue;
      }
      seen[resource.className] = resource.importPath;
    }
    return [
      for (final resource in found)
        if (seen[resource.className] == resource.importPath) resource,
    ];
  }

  /// The unnamed constructor [declaration] declares, if it declares one.
  static ConstructorDeclaration? _unnamedConstructorOf(
    ClassDeclaration declaration,
  ) {
    for (final member in declaration.members) {
      if (member is ConstructorDeclaration && member.name == null) {
        return member;
      }
    }
    return null;
  }

  /// The model class [constructor] passes to `super(model: ...)`, or the
  /// default of a `super.model` parameter, when the source names it.
  static String? _modelClassOf(ConstructorDeclaration constructor) {
    for (final initializer in constructor.initializers) {
      if (initializer is! SuperConstructorInvocation) {
        continue;
      }
      for (final argument in initializer.argumentList.arguments) {
        if (argument is NamedExpression &&
            argument.name.label.name == 'model') {
          return _constructedClassOf(argument.expression);
        }
      }
    }
    for (final parameter in constructor.parameters.parameters) {
      if (parameter is DefaultFormalParameter &&
          parameter.parameter is SuperFormalParameter &&
          parameter.name?.lexeme == 'model') {
        if (parameter.defaultValue case final Expression value) {
          return _constructedClassOf(value);
        }
      }
    }
    return null;
  }

  /// `ProductModel` for `const ProductModel()` or `ProductModel()`.
  static String? _constructedClassOf(Expression expression) =>
      switch (expression) {
        InstanceCreationExpression(:final constructorName)
            when constructorName.name == null =>
          constructorName.type.name.lexeme,
        MethodInvocation(target: null, :final methodName)
            when RegExp('^[A-Z]').hasMatch(methodName.name) =>
          methodName.name,
        _ => null,
      };

  /// Reports the override files Beak no longer reads, naming what replaces
  /// each, so an upgrade fails loudly instead of quietly ignoring a file.
  void _rejectRemovedOverrides(List<BeakDiscoveryIssue> issues) {
    for (final file in _dartFilesUnder(resourcesDir)) {
      final String path = _libRelativePath(file);
      // Only lib/resources/<table>.dart was ever an override; everything in
      // a feature folder is the project's own code.
      if (path.split('/').length != 2 ||
          !_declaresFunction(path, _removedResourceOverrideSymbol)) {
        continue;
      }
      final String table = path
          .split('/')
          .last
          .replaceAll(RegExp(r'\.dart$'), '');
      issues.add(
        BeakDiscoveryIssue(
          path: 'lib/$path',
          message:
              'Beak no longer reads $_removedResourceOverrideSymbol() '
              'overrides. Configure the $table resource with a BeakResource '
              'subclass instead: `beak eject resource $table` writes one '
              'under lib/resources/$table/, and the generated panel uses it '
              'in place of the default. Then delete this file.',
        ),
      );
    }
    const dashboard = 'dashboard.dart';
    if (_declaresFunction(dashboard, _removedDashboardSymbol)) {
      issues.add(
        const BeakDiscoveryIssue(
          path: 'lib/$dashboard',
          message:
              'Beak no longer reads the $_removedDashboardSymbol() override. '
              "Declare the screen as a BeakScreen with path: '/' under "
              'lib/screens/ instead, and the panel opens on it. Then delete '
              'this file.',
        ),
      );
    }
  }

  /// The function a removed `lib/resources/<table>.dart` override declared.
  static const String _removedResourceOverrideSymbol = 'beakResource';

  /// The function a removed `lib/dashboard.dart` override declared.
  static const String _removedDashboardSymbol = 'beakDashboard';

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
                'lib/$first. Generated imports would collide; rename one.',
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

/// Collects every identifier under a node into [names].
final class _IdentifierCollector extends RecursiveAstVisitor<void> {
  _IdentifierCollector(this.names);

  final Set<String> names;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    names.add(node.name.lexeme);
    super.visitNamedType(node);
  }
}
