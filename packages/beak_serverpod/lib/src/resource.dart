import 'package:beak_core/beak_core.dart';

import 'codec.dart';
import 'data_source.dart';

/// Operations a resource explicitly implements; these are not authorization.
enum ServerpodOperation {
  /// List records with their true pagination envelope.
  query,

  /// Read a record by identity.
  get,

  /// Create through a domain command.
  create,

  /// Edit through a domain command.
  update,

  /// Archive or delete through a domain operation.
  delete,

  /// Restore through a separately authorized operation.
  restore,

  /// Irreversibly delete through a separately bound operation.
  forceDelete,

  /// Resolve identities in one batch.
  batchGet,

  /// Aggregate using the same server scopes as queries.
  aggregate,
}

/// Type-erased dispatch surface, retaining typed entities inside each binding.
abstract interface class ServerpodResourceBinding {
  /// Metadata registered for this logical resource.
  BeakModel get model;

  /// Operations that have an actual binding.
  Set<ServerpodOperation> get operations;

  /// Queries and converts a page.
  Future<BeakPage<BeakRecord>> queryRecords(BeakQuerySpec spec);

  /// Reads by a typed or routed identity.
  Future<BeakRecord?> getOne(Object id);

  /// Reads the typed edit command shape for pre-filling a form.
  Future<BeakRecord> loadEditValues(Object id);

  /// Decodes a create input and runs its typed operation.
  Future<BeakRecord> create(BeakRecord input);

  /// Decodes an edit input and runs its typed operation.
  Future<BeakRecord> update(Object id, BeakRecord input);

  /// Runs the explicitly bound deletion behavior.
  Future<void> delete(Object id, {bool force = false});

  /// Restores when separately supported.
  Future<BeakRecord> restore(Object id);

  /// Resolves a batch in one domain call.
  Future<List<BeakRecord>> batchGet(List<Object> ids);

  /// Executes a server-side aggregate.
  Future<num> aggregate(BeakAggregateSpec spec);
}

/// Typed callbacks over existing generated Serverpod entities and command DTOs.
///
/// The client remains caller-owned and authenticated. This binding never opens
/// a database connection or infers write behavior from an entity's fields.
base class ServerpodResource<T, Id extends Object, Create, Update>
    extends BeakModel
    implements ServerpodResourceBinding {
  /// Binds the supported operations for [model].
  ServerpodResource({
    required this.model,
    required this.codec,
    required this.idCodec,
    required this.identify,
    BeakPermissions? permissions,
    this.createModel,
    this.editModel,
    this.onChanged,
    required Future<BeakPage<T>> Function(BeakQuerySpec spec) query,
    required Future<T?> Function(Id id) get,
    this.createCodec,
    this.updateCodec,
    this.editValues,
    Future<T> Function(Create input)? create,
    Future<T> Function(Id id, Update input)? update,
    Future<void> Function(Id id)? archive,
    Future<void> Function(Id id)? forceDelete,
    Future<T> Function(Id id)? restore,
    Future<List<T>> Function(List<Id> ids)? batchGet,
    Future<num> Function(BeakAggregateSpec spec)? aggregate,
  }) : _permissions = permissions,
       _query = query,
       _get = get,
       _create = create,
       _update = update,
       _archive = archive,
       _forceDelete = forceDelete,
       _restore = restore,
       _batchGet = batchGet,
       _aggregate = aggregate;

  @override
  final BeakModel model;

  final BeakPermissions? _permissions;

  @override
  BeakPermissions get permissions => _permissions ?? model.permissions;

  @override
  String get table => model.table;

  @override
  List<BeakColumn> get columns => model.columns;

  @override
  BeakColumn get primaryKey => model.primaryKey;

  @override
  String get displayColumnKey => model.displayColumnKey;

  @override
  List<BeakRelationship> get relationships => model.relationships;

  @override
  List<Enum>? get formSlots => model.formSlots;

  @override
  late final ServerpodDataSource dataSource = ServerpodDataSource(
    resources: [this],
  );

  @override
  final BeakModel? createModel;

  @override
  final BeakModel? editModel;

  /// Runs after a successful mutation; never replaces its domain operation.
  final Future<void> Function()? onChanged;

  @override
  Set<BeakOperation> get capabilities => {
    BeakOperation.read,
    if (operations.contains(ServerpodOperation.create)) BeakOperation.create,
    if (operations.contains(ServerpodOperation.update)) BeakOperation.update,
    if (operations.contains(ServerpodOperation.delete)) BeakOperation.delete,
  };

  /// Generated entity conversion, separate from write-command conversion.
  final ServerpodCodec<T> codec;

  /// Validates routed identities without accepting arbitrary stringification.
  final ServerpodValueCodec<Id> idCodec;

  /// Typed identity selector, including IDs nested in composed DTOs.
  final Id Function(T value) identify;

  /// Generated decoder for the create command, when supported.
  final ServerpodCodec<Create>? createCodec;

  /// Generated decoder for the edit command, when supported.
  final ServerpodCodec<Update>? updateCodec;

  /// Maps read data to edit input without duplicating field serialization.
  final Update Function(T value)? editValues;

  final Future<BeakPage<T>> Function(BeakQuerySpec spec) _query;
  final Future<T?> Function(Id id) _get;
  final Future<T> Function(Create input)? _create;
  final Future<T> Function(Id id, Update input)? _update;
  final Future<void> Function(Id id)? _archive;
  final Future<void> Function(Id id)? _forceDelete;
  final Future<T> Function(Id id)? _restore;
  final Future<List<T>> Function(List<Id> ids)? _batchGet;
  final Future<num> Function(BeakAggregateSpec spec)? _aggregate;

  @override
  Set<ServerpodOperation> get operations => {
    ServerpodOperation.query,
    ServerpodOperation.get,
    if (_create != null && createCodec != null) ServerpodOperation.create,
    if (_update != null && updateCodec != null) ServerpodOperation.update,
    if (_archive != null) ServerpodOperation.delete,
    if (_forceDelete != null) ServerpodOperation.forceDelete,
    if (_restore != null) ServerpodOperation.restore,
    if (_batchGet != null) ServerpodOperation.batchGet,
    if (_aggregate != null) ServerpodOperation.aggregate,
  };

  Id _id(Object value) {
    if (value is Id) return value;
    if (idCodec == ServerpodCodecs.integer && value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return idCodec.decode(BeakIntValue(parsed));
    }
    return idCodec.decode(BeakValue.of(value));
  }

  BeakRecord _encode(T value) {
    final record = codec.encode(value);
    final id = idCodec.encode(identify(value));
    return BeakRecord(
      values: {...record.values, model.primaryKey.key: id, 'id': id},
      relations: record.relations,
    );
  }

  @override
  Future<BeakPage<BeakRecord>> queryRecords(BeakQuerySpec spec) async {
    final page = await _query(spec);
    return BeakPage(
      items: [for (final value in page.items) _encode(value)],
      total: page.total,
      page: page.page,
      perPage: page.perPage,
    );
  }

  @override
  Future<BeakRecord?> getOne(Object id) async {
    final value = await _get(_id(id));
    return value == null ? null : _encode(value);
  }

  @override
  Future<BeakRecord> loadEditValues(Object id) async {
    final buildInput = editValues;
    final inputCodec = updateCodec;
    if (buildInput == null || inputCodec == null) {
      return unsupportedServerpodOperation(model.table, 'editValues');
    }
    final value = await _get(_id(id));
    if (value == null) {
      throw const BeakNotFoundException('The record no longer exists.');
    }
    return inputCodec.encode(buildInput(value));
  }

  @override
  Future<BeakRecord> create(BeakRecord input) async {
    final create = _create;
    final inputCodec = createCodec;
    if (create == null || inputCodec == null) {
      return unsupportedServerpodOperation(model.table, 'create');
    }
    final saved = await create(inputCodec.decode(input));
    await onChanged?.call();
    return _encode(saved);
  }

  @override
  Future<BeakRecord> update(Object id, BeakRecord input) async {
    final update = _update;
    final inputCodec = updateCodec;
    if (update == null || inputCodec == null) {
      return unsupportedServerpodOperation(model.table, 'update');
    }
    final saved = await update(_id(id), inputCodec.decode(input));
    await onChanged?.call();
    return _encode(saved);
  }

  @override
  Future<void> delete(Object id, {bool force = false}) async {
    final operation = force ? _forceDelete : _archive;
    if (operation == null) {
      unsupportedServerpodOperation(
        model.table,
        force ? 'forceDelete' : 'delete',
      );
    }
    await operation(_id(id));
    await onChanged?.call();
  }

  @override
  Future<BeakRecord> restore(Object id) async {
    final restore = _restore;
    if (restore == null) {
      return unsupportedServerpodOperation(model.table, 'restore');
    }
    final restored = await restore(_id(id));
    await onChanged?.call();
    return _encode(restored);
  }

  @override
  Future<List<BeakRecord>> batchGet(List<Object> ids) async {
    final batchGet = _batchGet;
    if (batchGet == null) {
      return unsupportedServerpodOperation(model.table, 'batchGet');
    }
    final values = await batchGet([for (final id in ids) _id(id)]);
    return [for (final value in values) _encode(value)];
  }

  @override
  Future<num> aggregate(BeakAggregateSpec spec) async {
    final aggregate = _aggregate;
    if (aggregate == null) {
      return unsupportedServerpodOperation(model.table, 'aggregate');
    }
    return aggregate(spec);
  }
}

/// Fails explicitly when a resource has no corresponding domain operation.
Never unsupportedServerpodOperation(String resource, String operation) =>
    throw BeakValidationException(
      'Resource "$resource" does not support $operation.',
    );
