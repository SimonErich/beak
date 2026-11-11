import 'definition_field.dart';

export 'definition_field.dart';

/// How the server runs one operation, as a definition class declares it with
/// `BeakHandling`.
enum DefinitionHandling {
  /// Not offered.
  off,

  /// Beak runs it through Serverpod.
  stock,

  /// Beak saves it after the handler's `derive`.
  derived,

  /// The model's server handler runs it.
  custom;

  /// Whether the operation is offered at all.
  bool get isOpen => this != off;

  /// Whether the server handler has code to run for it.
  bool get needsHandler => this == derived || this == custom;
}

/// One `@Resource` class of a Serverpod admin's definitions package.
final class DefinitionClass {
  /// Creates a class.
  const DefinitionClass({
    required this.name,
    required this.library,
    required this.path,
    required this.fields,
    this.input = false,
    this.inputTable,
    this.area,
    this.list = DefinitionHandling.stock,
    this.create = DefinitionHandling.off,
    this.update = DefinitionHandling.off,
    this.delete = DefinitionHandling.off,
    this.commands = const [],
    this.commandInputs = const {},
    this.access = const {},
    this.reason,
    this.restoreKey,
    this.labelKey,
    this.hasBehavior = false,
    this.hasValidationRules = false,
    this.hasPermissions = false,
    this.imports = const [],
    this.parts = const [],
    this.docComment,
  });

  /// The class name, which is the Serverpod model's.
  final String name;

  /// The library's path under `lib/` (`src/catalog/product.dart`).
  final String library;

  /// The file as `beak generate` reports it, relative to `beak.yaml`.
  final String path;

  /// The declared fields, in declaration order.
  final List<DefinitionField> fields;

  /// Whether the class is a `@CommandInput()`.
  final bool input;

  /// The `@CommandInput(table:)` name.
  final String? inputTable;

  /// The `area:` of `@ServerpodAdminModel`.
  final String? area;

  /// How rows are listed.
  final DefinitionHandling list;

  /// How a record is created.
  final DefinitionHandling create;

  /// How a record is updated.
  final DefinitionHandling update;

  /// How a record is deleted.
  final DefinitionHandling delete;

  /// The commands the server handler runs.
  final List<String> commands;

  /// The `@CommandInput` class per command that takes one.
  final Map<String, String> commandInputs;

  /// Per-operation role overrides.
  final Map<String, List<String>> access;

  /// Why writes are closed.
  final String? reason;

  /// The restore key of a soft-deleted row.
  final List<String>? restoreKey;

  /// The `@Resource(labelKey:)` override.
  final String? labelKey;

  /// Whether the class declares `static get behavior`.
  final bool hasBehavior;

  /// Whether the class declares `static get validationRules`.
  final bool hasValidationRules;

  /// Whether the class declares `static get permissions`.
  final bool hasPermissions;

  /// The library's import URIs.
  final List<String> imports;

  /// The library's part URIs.
  final List<String> parts;

  /// The class's doc comment.
  final String? docComment;

  /// The write binding name, `null` when nothing is written.
  String? get write =>
      writes ? '${name[0].toLowerCase()}${name.substring(1)}' : null;

  /// Whether any write is offered.
  bool get writes =>
      create.isOpen || update.isOpen || delete.isOpen || commands.isNotEmpty;

  /// Whether the model needs a server handler class.
  bool get needsHandler =>
      list == DefinitionHandling.custom ||
      create.needsHandler ||
      update.needsHandler ||
      delete == DefinitionHandling.custom ||
      commands.isNotEmpty;

  /// The part file next to the library (`product.beak.dart`).
  String get partFile {
    final base = library.split('/').last;
    return '${base.substring(0, base.length - '.dart'.length)}.beak.dart';
  }
}
