import 'package:meta/meta.dart';

/// How the server runs one operation on a Serverpod model.
enum BeakHandling {
  /// The operation is not offered: the panel hides it and the server refuses
  /// it.
  off,

  /// Beak runs the operation through Serverpod after its checks.
  stock,

  /// Beak saves the record after the model's server handler adds trusted
  /// values (`derive`), such as a revision or who published it.
  derived,

  /// The model's server handler runs the operation, typically through a use
  /// case the rest of the server shares. Beak still checks permissions,
  /// admission and rules first, and runs it in the request's transaction.
  ///
  /// On `list`, the handler narrows the rows (`scope`); the narrowed rows are
  /// all a list, a count, an export or opening one record can reach.
  custom,
}

/// Marks a `@Resource` schema class as a Serverpod model the admin exposes.
///
/// The class has the Serverpod model's name and declares the fields it
/// exposes, typed and named as in the `.spy.yaml` model; a field it leaves
/// out is never read or written by the admin. `beak generate` checks every
/// declared field against Serverpod and takes the table, keys, foreign keys
/// and timestamps from it:
///
/// ```dart
/// @Resource()
/// @ServerpodAdminModel(area: 'catalog', update: BeakHandling.custom)
/// final class Product extends BeakSchema {
///   @Display()
///   @Column(searchable: true, sortable: true)
///   late final String sku;
///
///   @BelongsTo()
///   late final ProductCategory? category;
/// }
/// ```
///
/// Every write is [BeakHandling.off] until opened, so a new model is read
/// only. A model with closed writes names its [reason].
@immutable
final class ServerpodAdminModel {
  /// Exposes the Serverpod model of the class's name, with the operations
  /// given.
  const ServerpodAdminModel({
    this.area,
    this.list = BeakHandling.stock,
    this.create = BeakHandling.off,
    this.update = BeakHandling.off,
    this.delete = BeakHandling.off,
    this.commands = const [],
    this.access = const {},
    this.reason,
    this.restoreKey,
  });

  /// Exposes the model with stock create, update and delete.
  const ServerpodAdminModel.editable({
    this.area,
    this.access = const {},
    this.restoreKey,
  }) : list = BeakHandling.stock,
       create = BeakHandling.stock,
       update = BeakHandling.stock,
       delete = BeakHandling.stock,
       commands = const [],
       reason = null;

  /// The `generate.areas` entry whose roles read and write the model.
  final String? area;

  /// Which rows a list, a count, an export and opening a record reach:
  /// [BeakHandling.stock] (every row) or [BeakHandling.custom] (the
  /// handler's `scope`).
  final BeakHandling list;

  /// How a new record is saved.
  final BeakHandling create;

  /// How a change to a record is saved.
  final BeakHandling update;

  /// How a record is deleted.
  final BeakHandling delete;

  /// The model commands (`BeakModelAction` names, such as `cancelOrder`) the
  /// model's server handler runs. A command is saved as an update that
  /// changes no field.
  final List<BeakCommand> commands;

  /// Roles that replace the area's for one operation (`read`, `write`,
  /// `create`, `update`, `delete`); all of them must be held.
  final Map<String, List<String>> access;

  /// Why the model is read only, or why its writes are closed.
  final String? reason;

  /// The fields that identify a soft-deleted row to restore, or `null` to
  /// detect them.
  final List<String>? restoreKey;
}

/// One server command a definition opens.
///
/// [input] names a `@CommandInput` class, whose typed values the generated
/// handler exposes as `write.input`.
@immutable
final class BeakCommand {
  /// Declares the command [name], optionally with a typed [input].
  const BeakCommand(this.name, {this.input});

  /// Stable wire identity, the `BeakModelAction` name.
  final String name;

  /// The `@CommandInput` model, or `null` for a command without input.
  final Type? input;
}

/// A field the server owns: the admin shows it and never writes it.
@immutable
final class ReadOnly {
  /// Marks the field read only.
  const ReadOnly();
}

/// A field the admin keeps on the server: never shown, never sent.
///
/// A create writes [defaultValue] when the Serverpod model requires a value.
@immutable
final class Hidden {
  /// Hides the field.
  const Hidden({this.defaultValue});

  /// The literal value a new record gets (a string, number or bool).
  final Object? defaultValue;
}

/// A command's typed input that is never stored, such as the role an
/// "assign role" command takes.
///
/// ```dart
/// @Resource()
/// @CommandInput()
/// final class AccountRoleCommand extends BeakSchema {
///   @BelongsTo()
///   late final Role role;
/// }
/// ```
@immutable
final class CommandInput {
  /// Declares an input model; [table] defaults to `input_<snake_name>`.
  const CommandInput({this.table});

  /// The table name its model reports.
  final String? table;
}
