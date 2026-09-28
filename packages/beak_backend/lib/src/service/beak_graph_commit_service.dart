import 'dart:async';
import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:crypto/crypto.dart';
import 'package:worm/worm.dart';

import '../auth/beak_auth_guard.dart';
import '../auth/beak_action_policy.dart';
import '../auth/beak_policy.dart';
import '../auth/beak_field_policy.dart';
import '../auth/beak_query_authorizer.dart';
import '../data/worm/worm_data_source.dart';
import 'beak_commit_receipts_migration.dart';
import 'beak_resource_service.dart';
import 'beak_revision_timestamp.dart';
import 'validation_service.dart';

/// Validates and enriches a graph within its database transaction.
///
/// The callback may add derived writes, but must retain the request identity and
/// original operation identities. All resulting operations still pass normal
/// authorization and model validation. Successful replay never runs it again.
typedef BeakSavePlanPreparer =
    Future<BeakSavePlan> Function(
      BeakSavePlan plan,
      WormDataSource transaction,
      BeakPrincipal? principal,
    );

/// Enqueues durable effects or reserves shared capacity in the save transaction.
///
/// Runs once for a successful save, after graph validation and before its receipt.
/// Throwing a [BeakException] rolls back both the graph and finalizer writes.
/// Network effects belong in an outbox worker, never in this callback.
typedef BeakSavePlanFinalizer =
    Future<void> Function(
      BeakSavePlan plan,
      BeakSaveResult result,
      WormDataSource transaction,
      BeakPrincipal? principal,
    );

/// Authenticated graph persistence with transactional or explicit staged receipts.
///
/// Apply [BeakCommitReceiptsMigration] before accepting commits. Receipts have no
/// automatic expiry: an old idempotency key never becomes a new write.
final class BeakGraphCommitService {
  /// Binds persistence and authorization once per backend.
  BeakGraphCommitService({
    required this.registry,
    required this.source,
    this.policy = const BeakAllowAllPolicy(),
    this.validation = const ValidationService(),
    this.preparePlan,
    this.finalizePlan,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Registered resource metadata.
  final BeakModelRegistry registry;

  /// Worm source whose adapter owns writes and receipts.
  final WormDataSource source;

  /// Authoritative policy, checked for every graph node.
  final BeakPolicy policy;

  /// Shared model validation.
  final ValidationService validation;

  /// Optional authoritative aggregate validation and derived-value calculation.
  /// Requires a transactional adapter; no partially prepared graph is accepted.
  final BeakSavePlanPreparer? preparePlan;

  /// Transactional post-validation writes, with resulting record identities.
  final BeakSavePlanFinalizer? finalizePlan;

  // Serializes in-process use of adapters whose transactions are snapshot based.
  // The receipt primary key independently protects concurrent server processes.
  static final Expando<Future<void>> _tails = Expando<Future<void>>();

  /// Guarantees of this adapter, without assuming every adapter can transact.
  BeakCommitCapabilities get commitCapabilities => BeakCommitCapabilities(
    atomicGraph: source.adapter.capabilities.supportsTransactions,
    durableReceipts: true,
    idempotentReplay: source.adapter.capabilities.supportsTransactions,
    conditionalWrites: true,
  );

  /// Saves or resumes a graph under the requesting principal's receipt namespace.
  Future<BeakSaveResult> commit(
    BeakSavePlan plan, {
    BeakPrincipal? principal,
  }) async {
    final adapter = source.adapter;
    final preceding = _tails[adapter] ?? Future<void>.value();
    final released = Completer<void>();
    _tails[adapter] = released.future;
    await preceding;
    try {
      final result = await _commit(plan, principal);
      final receipt = await _receipt(
        source.adapter,
        _key(plan.saveId, principal),
      );
      final prepared = receipt == null
          ? plan
          : BeakSavePlan.fromJson(_decodeMap(receipt['request_json']));
      return _redact(result, prepared, principal);
    } finally {
      released.complete();
    }
  }

  Future<BeakSaveResult> _commit(
    BeakSavePlan plan,
    BeakPrincipal? principal,
  ) async {
    final key = _key(plan.saveId, principal);
    final encoded = jsonEncode(_canonical(plan.toJson()));
    final hash = sha256.convert(utf8.encode(encoded)).toString();
    final existing = await _receipt(source.adapter, key);
    if (existing != null && existing['request_hash'] != hash) {
      throw const BeakConflictException(
        'Save identity was reused with different content.',
      );
    }
    plan.orderedOperations(registry);
    if (existing != null) {
      final prior = _decodeReceipt(existing);
      if (prior.complete ||
          prior.hasUnknown ||
          prior.mode == BeakSaveMode.atomic) {
        await _authorizeReceipt(
          BeakSavePlan.fromJson(_decodeMap(existing['request_json'])),
          principal,
          prior,
        );
        return prior;
      }
    }
    if (!source.adapter.capabilities.supportsTransactions) {
      if (preparePlan != null ||
          finalizePlan != null ||
          plan.action != null ||
          registry.all.any((model) => !model.behavior.isEmpty) ||
          registry.all.any(
            (model) => model.validationRules.any(
              (rule) => rule.relationLoads.isNotEmpty,
            ),
          )) {
        throw const BeakConfigurationException(
          'Graph preparation requires a transactional data source.',
        );
      }
      final previous = existing == null ? null : _decodeReceipt(existing);
      if (existing == null) {
        await _insertReceipt(
          source.adapter,
          key,
          encoded,
          hash,
          _pending(plan),
        );
      }
      var expectedReceipt = existing == null
          ? jsonEncode(_pending(plan).toJson())
          : switch (existing['result_json']) {
              final String value => value,
              _ => throw const BeakConfigurationException(
                'Malformed durable save receipt.',
              ),
            };
      return executeBeakSavePlan(
        plan: plan,
        registry: registry,
        previous: previous,
        run: (op, ids) => _run(op, ids, source, principal, input: op),
        checkpoint: (result) async {
          await _writeReceipt(
            source.adapter,
            key,
            result,
            expectedJson: expectedReceipt,
          );
          expectedReceipt = jsonEncode(result.toJson());
        },
      );
    }
    try {
      return await source.adapter.transaction((adapter) async {
        await _insertReceipt(adapter, key, encoded, hash, _pending(plan));
        final transactional = WormDataSource(registry, adapter: adapter);
        final prepared = await _prepare(plan, transactional, principal);
        final previousParents = await _validationParents(
          prepared.operations
              .map((operation) => operation.target)
              .where((ref) => ref.id != null),
          transactional,
        );
        _validatePreparedPlan(plan, prepared);
        if (preparePlan != null ||
            plan.action != null ||
            registry.all.any((model) => !model.behavior.isEmpty)) {
          await adapter.update(
            UpdateDescriptor(
              table: BeakCommitReceiptsMigration.table,
              values: {'request_json': jsonEncode(prepared.toJson())},
              where: const StringField('id').eq(key),
            ),
          );
        }
        final result = await executeBeakSavePlan(
          plan: prepared,
          registry: registry,
          mode: BeakSaveMode.atomic,
          run: (op, ids) => _run(
            op,
            ids,
            transactional,
            principal,
            input: plan.operations
                .where((input) => input.id == op.id)
                .firstOrNull,
          ),
        );
        if (!result.complete) throw _Rollback(result);
        await _validateFinalGraph(
          prepared,
          result,
          transactional,
          principal,
          previousParents,
        );
        try {
          await finalizePlan?.call(prepared, result, transactional, principal);
        } on BeakException catch (error) {
          throw _Rollback(
            BeakSaveResult(
              saveId: plan.saveId,
              mode: BeakSaveMode.atomic,
              outcomes: [
                for (final operation in prepared.orderedOperations(registry))
                  BeakOperationResult(
                    id: operation.id,
                    status: BeakWriteOutcome.unapplied,
                    error: operation.id == prepared.operations.first.id
                        ? BeakSaveError.fromException(error)
                        : null,
                  ),
              ],
            ),
          );
        }
        await _writeReceipt(adapter, key, result);
        return result;
      });
    } on _Rollback catch (abort) {
      final rolledBack = BeakSaveResult(
        saveId: plan.saveId,
        mode: BeakSaveMode.atomic,
        rootOperationId: abort.result.rootOperationId,
        outcomes: [
          for (final result in abort.result.outcomes)
            BeakOperationResult(
              id: result.id,
              status: BeakWriteOutcome.unapplied,
              error: result.error,
              reason: result.error == null ? 'rolledBack' : 'rejected',
            ),
        ],
      );
      await _insertReceipt(source.adapter, key, encoded, hash, rolledBack);
      return rolledBack;
    } on UniqueConstraintException {
      // A competing process committed this save while our insert waited.
      final winner = await _receipt(source.adapter, key);
      if (winner == null) rethrow;
      if (winner['request_hash'] != hash) {
        throw const BeakConflictException(
          'Save identity was reused with different content.',
        );
      }
      final result = _decodeReceipt(winner);
      await _authorizeReceipt(
        BeakSavePlan.fromJson(_decodeMap(winner['request_json'])),
        principal,
        result,
      );
      return result;
    }
  }

  void _authorizeInput(BeakSaveOperation op, BeakPrincipal? principal) {
    final access = BeakFieldAccess(
      registry: registry,
      policy: policy,
      principal: principal,
    );
    access.requireWrite(op.target.table, {
      ...op.values.values.keys,
      ...op.references.keys,
    });
    if (op.owner case final parent?) {
      access.requireWrite(parent.table, [op.relationKey!]);
    }
    if (op.related != null) {
      access.requireWrite(op.target.table, [op.relationKey!]);
    }
  }

  Future<BeakSavePlan> _prepare(
    BeakSavePlan plan,
    WormDataSource transactional,
    BeakPrincipal? principal,
  ) async {
    try {
      for (final operation in plan.operations) {
        _authorizeInput(operation, principal);
      }
      final prepared = await _prepareBehavior(plan, transactional, principal);
      return await preparePlan?.call(prepared, transactional, principal) ??
          prepared;
    } on BeakException catch (error) {
      // The transaction has not dispatched the prepared graph. Persist a
      // definite rejection so the client can edit instead of treating it as an
      // ambiguous network write and locking its draft for recovery.
      throw _Rollback(
        BeakSaveResult(
          saveId: plan.saveId,
          mode: BeakSaveMode.atomic,
          outcomes: [
            for (final operation in plan.orderedOperations(registry))
              BeakOperationResult(
                id: operation.id,
                status: BeakWriteOutcome.unapplied,
                error: operation.id == plan.operations.first.id
                    ? BeakSaveError.fromException(error)
                    : null,
              ),
          ],
        ),
      );
    }
  }

  Future<BeakSavePlan> _prepareBehavior(
    BeakSavePlan plan,
    WormDataSource transactional,
    BeakPrincipal? principal,
  ) async {
    if (plan.action == null &&
        registry.all.every((model) => model.behavior.isEmpty)) {
      return plan;
    }
    if (plan.operations.isEmpty) {
      throw const BeakValidationException(
        'A command needs a root update operation.',
      );
    }
    final graph = await BeakCandidateGraph.open(
      plan: plan,
      source: transactional,
      registry: registry,
      authorizeRead: (ref) async {
        await _read(ref, const {}, transactional, principal);
      },
    );
    for (final operation in plan.operations.where(
      (op) =>
          op.kind == BeakSaveOperationKind.attach ||
          op.kind == BeakSaveOperationKind.detach,
    )) {
      final node = await graph.load(operation.target);
      if (node.initial != null &&
          !(node.model.behavior.editableWhen?.call(node.initial!) ?? true)) {
        throw const BeakValidationException(
          'The relationship is locked by its record workflow.',
        );
      }
    }
    final root = await graph.load(plan.root);
    var arguments = plan.arguments;
    if (plan.action case final commandName?) {
      if (policy case final BeakActionPolicy actions) {
        _require(
          actions.canExecuteAction(
            principal,
            root.ref.table,
            root.ref.id,
            commandName,
          ),
          principal,
        );
      }
      final action = root.model.behavior.action(commandName);
      if (plan.root.id == null && !action.allowOnCreate) {
        throw const BeakValidationException(
          'Save the record before executing this action.',
        );
      }
      final original =
          root.initial ??
          root.model.behavior.initialize(
            const BeakValidation().applyDefaults(
              root.model,
              const BeakRecord(values: {}),
            ),
          );
      if (!action.isAvailable(original)) {
        throw const BeakValidationException(
          'This action is unavailable in the current state.',
        );
      }
      if (!plan.operations.any(
        (op) =>
            op.target == plan.root &&
            (op.kind == BeakSaveOperationKind.update ||
                (action.allowOnCreate &&
                    op.kind == BeakSaveOperationKind.create)),
      )) {
        throw const BeakValidationException(
          'A command needs a root update operation.',
        );
      }
      if (action.inputModel case final input?) {
        if (arguments.relations.isNotEmpty) {
          throw const BeakValidationException(
            'Action relationships are resolved from their selected identities.',
          );
        }
        arguments = const BeakValidation().applyDefaults(input, arguments);
        final authorizer = BeakQueryAuthorizer(
          registry: registry,
          policy: policy,
          principal: principal,
        );
        final relations = <String, List<BeakRecord>>{};
        for (final load in [
          for (final rule in input.validationRules) ...rule.relationLoads,
        ]) {
          final relation = input.relationshipByKey(load.relationKey);
          if (relation is! BeakBelongsTo) {
            throw const BeakConfigurationException(
              'Action inputs support belongs-to relationship constraints.',
            );
          }
          final id = arguments[relation.foreignKey]?.raw;
          if (id == null) {
            relations[relation.key] = [];
            continue;
          }
          final target = registry.byTableOrThrow(relation.relatedTable);
          final page = await transactional.query(
            authorizer.authorizeQuery(
              target.query(
                filter: BeakFieldFilter(
                  column: target.primaryKey,
                  operator: BeakOperator.eq,
                  value: BeakValue.of(id),
                ),
                relationLoads: load.nested,
                pagination: const BeakPagination(perPage: 1),
              ),
            ),
          );
          relations[relation.key] = page.items;
        }
        arguments = BeakRecord(values: arguments.values, relations: relations);
        validation.validate(input, arguments, isCreate: true);
        final report = await const BeakAsyncValidation().validate(
          input,
          arguments,
          registry: registry,
          query: (spec) => transactional.query(authorizer.authorizeQuery(spec)),
        );
        if (report.fieldErrors.isNotEmpty) {
          throw BeakValidationException(
            'Invalid action inputs.',
            fieldErrors: report.fieldErrors,
          );
        }
      } else if (arguments.values.isNotEmpty ||
          arguments.relations.isNotEmpty) {
        throw const BeakValidationException(
          'This action does not accept inputs.',
        );
      }
    } else if (arguments.values.isNotEmpty || arguments.relations.isNotEmpty) {
      throw const BeakValidationException(
        'Action inputs require a named action.',
      );
    }
    final scheduled = {
      for (final node in graph.nodes.where((node) => node.changed))
        node.ref: node,
    };
    var discovered = scheduled.values.toList();
    while (discovered.isNotEmpty) {
      final previous = discovered;
      discovered = [];
      final refs = await _validationParents(
        previous.map((node) => node.ref).where((ref) => ref.id != null),
        transactional,
      );
      for (final node in previous) {
        refs.addAll((await graph.parents(node)).map((parent) => parent.ref));
      }
      for (final ref in refs) {
        if (scheduled.containsKey(ref)) continue;
        final node = await graph.load(ref);
        if (!node.model.behavior.isEmpty) {
          scheduled[ref] = node;
          discovered.add(node);
        }
      }
    }
    final evaluating = <BeakRecordRef>{};
    final evaluated = <BeakRecordRef>{};
    Future<void> evaluate(BeakCandidateNode node) async {
      if (evaluated.contains(node.ref)) return;
      if (!evaluating.add(node.ref)) {
        throw const BeakConfigurationException(
          'A value dependency cycle crosses related records.',
        );
      }
      for (final owner
          in node.materiallyChanged()
              ? await graph.owners(node)
              : <BeakCandidateNode>[]) {
        if (owner.initial != null &&
            !(owner.model.behavior.editableWhen?.call(owner.initial!) ??
                true)) {
          throw const BeakValidationException(
            'The owning record is locked by its workflow.',
          );
        }
      }
      final behavior = node.model.behavior;
      if (behavior.isEmpty) {
        evaluating.remove(node.ref);
        evaluated.add(node.ref);
        return;
      }
      if (node.deleted) {
        if (node.initial != null &&
            !(behavior.deletableWhen?.call(node.initial!) ?? true)) {
          throw const BeakValidationException(
            'This record cannot be deleted in its current state.',
          );
        }
        evaluating.remove(node.ref);
        evaluated.add(node.ref);
        return;
      }
      final command = node.ref == plan.root ? plan.action : null;
      final fields = [
        for (final value in behavior.values) ...value.dependencies,
        if (command != null)
          for (final value in behavior.action(command).values)
            ...value.dependencies,
      ];
      for (final dependency in await graph.dependencies(node, fields)) {
        if (scheduled.containsKey(dependency.ref)) await evaluate(dependency);
      }
      var record = await graph.materialize(node, fields: fields);
      if (node.initial == null) {
        record = const BeakValidation().applyDefaults(node.model, record);
      }
      final initial = await graph.materializeInitial(node, fields: fields);
      final baseline =
          initial ??
          behavior.initialize(
            const BeakValidation().applyDefaults(
              node.model,
              const BeakRecord(values: {}),
            ),
          );
      behavior.validateEdits(
        record,
        initial: baseline,
        actionName: command,
        isCreate: node.initial == null,
      );
      final submitted = {
        for (final operation in plan.operations.where(
          (op) => op.target == node.ref,
        )) ...{...operation.values.values.keys, ...operation.references.keys},
      };
      if (initial == null) record = behavior.initialize(record);
      // A suggested foreign key can reveal another dependency (customer ->
      // default profile -> delivery location). Rehydrate between passes so the
      // next calculation reads the selected candidate, not its old relation.
      for (var pass = 0; ; pass++) {
        final calculated = behavior.apply(
          record,
          initial: initial,
          overriddenFields: submitted,
        );
        graph.patch(node, calculated);
        if (calculated.values.length == record.values.length &&
            calculated.values.entries.every(
              (entry) => entry.value == record[entry.key],
            )) {
          record = calculated;
          break;
        }
        if (pass > behavior.values.length) {
          throw const BeakConfigurationException(
            'Model values did not stabilize after resolving relationships.',
          );
        }
        for (final dependency in await graph.dependencies(node, fields)) {
          if (scheduled.containsKey(dependency.ref)) await evaluate(dependency);
        }
        record = await graph.materialize(node, fields: fields);
      }
      if (command != null) {
        graph.patch(
          node,
          behavior.apply(
            record,
            initial: initial,
            overriddenFields: submitted,
            action: command,
            arguments: arguments,
          ),
        );
      }
      evaluating.remove(node.ref);
      evaluated.add(node.ref);
    }

    for (final node in scheduled.values.toList()) {
      await evaluate(node);
    }
    return graph.build();
  }

  BeakSaveResult _redact(
    BeakSaveResult result,
    BeakSavePlan plan,
    BeakPrincipal? principal,
  ) {
    final access = BeakFieldAccess(
      registry: registry,
      policy: policy,
      principal: principal,
    );
    Object? readableId(BeakOperationResult outcome) {
      if (outcome.resolvedId == null) return null;
      final table = plan.operations
          .firstWhere((operation) => operation.id == outcome.id)
          .target
          .table;
      final identity = registry.byTableOrThrow(table).primaryKey.key;
      return policy.canView(principal, table) && access.canRead(table, identity)
          ? outcome.resolvedId
          : null;
    }

    return BeakSaveResult(
      saveId: result.saveId,
      mode: result.mode,
      rootOperationId: result.rootOperationId,
      outcomes: [
        for (final outcome in result.outcomes)
          BeakOperationResult(
            id: outcome.id,
            status: outcome.status,
            draftId: outcome.draftId,
            resolvedId: readableId(outcome),
            table: outcome.table,
            error: outcome.error,
            reason: outcome.reason,
            record: outcome.record == null
                ? null
                : access.redact(
                    plan.operations
                        .firstWhere((op) => op.id == outcome.id)
                        .target
                        .table,
                    outcome.record!,
                  ),
          ),
      ],
    );
  }

  // Resolve inverse dependencies from the rules themselves. This also handles
  // unidirectional has-many declarations and nested/many-to-many field paths.
  Future<List<BeakRecordRef>> _validationParents(
    Iterable<BeakRecordRef> targets,
    WormDataSource data,
  ) async {
    final parents = <BeakRecordRef>[];
    for (final target in targets) {
      for (final model in registry.all) {
        final paths = <String>{};
        void collect(
          BeakModel current,
          List<BeakRelationLoad> loads,
          List<String> path,
        ) {
          for (final load in loads) {
            final relation = current.relationships
                .where((item) => item.key == load.relationKey)
                .first;
            final related = registry.byTableOrThrow(relation.relatedTable);
            final next = [...path, relation.key];
            if (related.table == target.table) {
              paths.add([...next, related.primaryKey.key].join('.'));
            }
            collect(related, load.nested, next);
          }
        }

        collect(model, [
          for (final rule in model.validationRules) ...rule.relationLoads,
          // Suggestions are defaults for an editor, not inverse write triggers.
          // Only derived values must update when a referenced record changes.
          ...BeakModelBehavior(
            values: [
              for (final value in model.behavior.values)
                if (value.lifecycle == BeakValueLifecycle.derived) value,
            ],
          ).relationLoads,
        ], const []);
        if (paths.isEmpty) continue;
        var page = 1;
        while (true) {
          final matches = await data.query(
            model.query(
              filter: BeakOrFilter([
                for (final path in paths)
                  BeakFieldFilter.forKey(
                    path,
                    BeakOperator.eq,
                    BeakValue.of(target.id),
                  ),
              ]),
              pagination: BeakPagination(page: page, perPage: 100),
            ),
          );
          for (final row in matches.items) {
            parents.add(
              BeakRecordRef.existing(model.table, model.primaryKeyOf(row)!),
            );
          }
          if (matches.items.length < 100) break;
          page++;
        }
      }
    }
    return parents;
  }

  Future<void> _validateFinalGraph(
    BeakSavePlan plan,
    BeakSaveResult result,
    WormDataSource data,
    BeakPrincipal? principal,
    List<BeakRecordRef> previousParents,
  ) async {
    final refs = <(String, Object), BeakRecordRef>{};
    void add(BeakRecordRef ref) {
      final id = ref.resolve(result.identities);
      refs[(ref.table, id)] = BeakRecordRef.existing(ref.table, id);
    }

    add(plan.root);
    for (final parent in previousParents) {
      add(parent);
    }
    for (final op in plan.operations) {
      if (op.kind != BeakSaveOperationKind.delete) add(op.target);
      if (op.owner case final BeakRecordRef owner) add(owner);
      if (op.related case final BeakRecordRef related) add(related);
    }
    final affected = await _validationParents(
      refs.values.toList(growable: false),
      data,
    );
    for (final parent in affected) {
      add(parent);
    }
    final authorizer = BeakQueryAuthorizer(
      registry: registry,
      policy: policy,
      principal: principal,
    );
    for (final ref in refs.values) {
      final model = registry.byTableOrThrow(ref.table);
      if (model.validationRules.isEmpty &&
          !model.columns.any((column) => column.unique) &&
          !model.relationships.any((relation) => relation is BeakBelongsTo)) {
        continue;
      }
      final record = await data.getOne(ref.table, ref.id!);
      if (record == null) continue;
      try {
        await BeakResourceService(
          model,
          data,
          validation: validation,
          registry: registry,
        ).validateCandidate(
          record,
          recordId: ref.id,
          scope: authorizer.scopeFor(model.table),
          validationQuery: (spec) =>
              data.query(authorizer.authorizeQuery(spec)),
        );
      } on BeakException catch (error) {
        final operation = plan.operations
            .where(
              (op) =>
                  op.target.table == ref.table &&
                  op.target.resolve(result.identities) == ref.id,
            )
            .firstOrNull;
        final errorId = operation?.id ?? plan.operations.first.id;
        throw _Rollback(
          BeakSaveResult(
            saveId: plan.saveId,
            mode: BeakSaveMode.atomic,
            outcomes: [
              for (final outcome in result.outcomes)
                BeakOperationResult(
                  id: outcome.id,
                  status: BeakWriteOutcome.unapplied,
                  error: outcome.id == errorId
                      ? BeakSaveError.fromException(error)
                      : null,
                ),
            ],
          ),
        );
      }
    }
  }

  void _validatePreparedPlan(BeakSavePlan original, BeakSavePlan prepared) {
    if (original.action != prepared.action ||
        original.arguments != prepared.arguments ||
        original.saveId != prepared.saveId ||
        jsonEncode(original.root.toJson()) !=
            jsonEncode(prepared.root.toJson())) {
      throw const BeakConfigurationException(
        'Graph preparation must retain the save identity and root.',
      );
    }
    for (final operation in original.operations) {
      final matches = prepared.operations.where(
        (item) => item.id == operation.id,
      );
      if (matches.length != 1 ||
          matches.single.kind != operation.kind ||
          jsonEncode(matches.single.target.toJson()) !=
              jsonEncode(operation.target.toJson())) {
        throw const BeakConfigurationException(
          'Graph preparation must retain each original operation identity and kind.',
        );
      }
    }
    prepared.orderedOperations(registry);
  }

  /// Returns durable outcomes without executing business mutations.
  Future<BeakSaveResult> recover(
    String saveId, {
    BeakPrincipal? principal,
  }) async {
    final receipt = await _receipt(source.adapter, _key(saveId, principal));
    if (receipt == null) {
      throw BeakNotFoundException('No receipt for save "$saveId".');
    }
    final plan = BeakSavePlan.fromJson(_decodeMap(receipt['request_json']));
    final result = _decodeReceipt(receipt);
    await _authorizeReceipt(plan, principal, result);
    return _redact(result, plan, principal);
  }

  Future<void> _authorizeReceipt(
    BeakSavePlan plan,
    BeakPrincipal? principal,
    BeakSaveResult result,
  ) async {
    for (final table in {
      plan.root.table,
      ...plan.operations.map((op) => op.target.table),
    }) {
      _require(policy.canView(principal, table), principal);
    }
    for (final outcome in result.outcomes) {
      if (outcome.status != BeakWriteOutcome.applied ||
          outcome.record == null ||
          outcome.resolvedId == null) {
        continue;
      }
      final op = plan.operations.firstWhere((op) => op.id == outcome.id);
      final scope = _scope(op.target.table, principal);
      if (scope != null) {
        await _service(
          op.target.table,
          source,
        ).getOne(outcome.resolvedId!, scope: scope);
      }
    }
  }

  BeakResourceService _service(String table, WormDataSource data) =>
      BeakResourceService(
        registry.byTableOrThrow(table),
        data,
        validation: validation,
        deferRecordRules: commitCapabilities.atomicGraph,
        registry: registry,
        now: _now,
      );

  BeakFilter? _scope(String table, BeakPrincipal? principal) =>
      BeakQueryAuthorizer(
        registry: registry,
        policy: policy,
        principal: principal,
      ).scopeFor(table);

  Future<BeakRecord> _read(
    BeakRecordRef ref,
    Map<String, Object> identities,
    WormDataSource data,
    BeakPrincipal? principal,
  ) async {
    _require(policy.canView(principal, ref.table), principal);
    return _service(
      ref.table,
      data,
    ).getOne(ref.resolve(identities), scope: _scope(ref.table, principal));
  }

  Future<BeakOperationResult> _run(
    BeakSaveOperation op,
    Map<String, Object> identities,
    WormDataSource data,
    BeakPrincipal? principal, {
    BeakSaveOperation? input,
  }) async {
    var dispatched = false;
    try {
      if (input != null) _authorizeInput(input, principal);
      final model = registry.byTableOrThrow(op.target.table);
      final service = _service(model.table, data);
      final resolvedValues = op.resolveValues(registry, identities);
      final values = op.kind == BeakSaveOperationKind.create
          ? service.prepareCreate(resolvedValues)
          : resolvedValues;
      final id = op.kind == BeakSaveOperationKind.create
          ? null
          : op.target.resolve(identities);
      final allowed = switch (op.kind) {
        BeakSaveOperationKind.create => policy.canCreate(
          principal,
          model.table,
        ),
        BeakSaveOperationKind.delete => policy.canDelete(
          principal,
          model.table,
          id!,
        ),
        _ => policy.canUpdate(principal, model.table, id!),
      };
      _require(allowed, principal);
      final existing = id == null
          ? null
          : await _read(op.target, identities, data, principal);
      if (op.owner case final BeakRecordRef parent) {
        await _read(parent, identities, data, principal);
        _require(
          policy.canUpdate(principal, parent.table, parent.resolve(identities)),
          principal,
        );
        final ownership = registry
            .byTableOrThrow(parent.table)
            .relationshipByKey(op.relationKey!);
        if (op.kind == BeakSaveOperationKind.delete &&
            switch (ownership) {
              BeakHasMany(:final owned) || BeakHasOne(:final owned) => !owned,
              _ => true,
            }) {
          throw const BeakValidationException(
            'Only explicitly owned relationships may delete their rows.',
          );
        }
        if (op.kind != BeakSaveOperationKind.create) {
          await _requireMembership(
            parent,
            op.target,
            op.relationKey!,
            identities,
            data,
            principal,
          );
          final relation = registry
              .byTableOrThrow(parent.table)
              .relationshipByKey(op.relationKey!);
          final foreignKey = switch (relation) {
            BeakHasMany(:final foreignKey) ||
            BeakHasOne(:final foreignKey) => foreignKey,
            _ => null,
          };
          if (foreignKey != null &&
              values.values.containsKey(foreignKey) &&
              values[foreignKey]?.raw != parent.resolve(identities)) {
            throw const BeakValidationException(
              'An owned row cannot change its owner.',
            );
          }
        }
      }
      if (op.kind == BeakSaveOperationKind.create ||
          op.kind == BeakSaveOperationKind.update) {
        validation.validate(
          model,
          values,
          isCreate: op.kind == BeakSaveOperationKind.create,
          includeRecordRules: false,
        );
        for (final relation in model.relationships.whereType<BeakBelongsTo>()) {
          final foreign = values[relation.foreignKey]?.raw;
          if (foreign != null) {
            await _read(
              BeakRecordRef.existing(relation.relatedTable, foreign),
              identities,
              data,
              principal,
            );
          }
        }
        if (op.kind == BeakSaveOperationKind.create) {
          _validateCreateScope(values, _scope(model.table, principal));
        }
      }
      if (op.related case final BeakRecordRef related) {
        final child = await _read(related, identities, data, principal);
        final relation = model.relationshipByKey(op.relationKey!);
        if (relation is BeakHasMany) {
          _require(
            policy.canUpdate(
              principal,
              related.table,
              related.resolve(identities),
            ),
            principal,
          );
          final previousOwner = child[relation.foreignKey]?.raw;
          if (op.kind == BeakSaveOperationKind.attach &&
              previousOwner != null &&
              previousOwner != id) {
            throw const BeakValidationException(
              'The related row already belongs to another owner.',
            );
          }
          if (op.kind == BeakSaveOperationKind.detach &&
              registry
                      .byTableOrThrow(related.table)
                      .columnByKey(relation.foreignKey)
                      ?.rules
                      .any((rule) => rule is BeakRequired) ==
                  true) {
            throw const BeakValidationException(
              'This required relationship cannot be removed.',
            );
          }
        }
        if (op.kind == BeakSaveOperationKind.detach) {
          await _requireMembership(
            op.target,
            related,
            op.relationKey!,
            identities,
            data,
            principal,
          );
        }
      }
      if (op.expectedUpdatedAt != null &&
          op.kind != BeakSaveOperationKind.update &&
          op.kind != BeakSaveOperationKind.delete) {
        throw const BeakValidationException(
          'Version preconditions require an update or delete.',
        );
      }
      dispatched = true;
      BeakRecord? record;
      Object? resolvedId = id;
      switch (op.kind) {
        case BeakSaveOperationKind.create:
          record = await service.create(values);
          resolvedId = model.primaryKeyOf(record);
        case BeakSaveOperationKind.update:
          if (op.expectedUpdatedAt case final DateTime expected) {
            record = await _conditionalUpdate(
              model,
              id!,
              values,
              expected,
              data,
            );
          } else if (values.values.entries.every(
            (entry) => entry.value == existing?[entry.key],
          )) {
            // Populated forms also submit unchanged owned rows. Their receipt
            // remains applied, but there is no new revision or snapshot write.
            record = existing;
          } else {
            record = await service.update(
              id!,
              values,
              scope: _scope(model.table, principal),
            );
          }
        case BeakSaveOperationKind.delete:
          if (op.expectedUpdatedAt case final DateTime expected) {
            await _conditionalDelete(model, id!, expected, data);
          } else {
            await service.delete(id!, scope: _scope(model.table, principal));
          }
        case BeakSaveOperationKind.attach:
          await service.attach(id!, op.relationKey!, [
            op.related!.resolve(identities),
          ]);
        case BeakSaveOperationKind.detach:
          await service.detach(id!, op.relationKey!, [
            op.related!.resolve(identities),
          ]);
      }
      return BeakOperationResult(
        id: op.id,
        table: op.target.table,
        status: BeakWriteOutcome.applied,
        draftId: op.kind == BeakSaveOperationKind.create
            ? op.target.draftId
            : null,
        resolvedId: resolvedId,
        record: record,
      );
    } on Object catch (error) {
      final cause = switch (error) {
        _UnappliedWrite(:final error) => error,
        UniqueConstraintException() => const BeakConflictException(
          'A value that must be unique is already in use.',
        ),
        _ => error,
      };
      return BeakOperationResult(
        id: op.id,
        status: dispatched && error is! _UnappliedWrite
            ? BeakWriteOutcome.unknown
            : BeakWriteOutcome.unapplied,
        reason: dispatched && error is! _UnappliedWrite ? null : 'rejected',
        error: BeakSaveError.fromException(cause),
      );
    }
  }

  Future<DateTime> _requireRevision(
    BeakModel model,
    Object id,
    DateTime expected,
    WormDataSource data,
  ) async {
    if (model.columnByKey('updated_at') is! BeakDateTimeColumn) {
      throw const _UnappliedWrite(
        BeakValidationException(
          'This model does not have an update timestamp.',
        ),
      );
    }
    final current = await data.getOne(model.table, id);
    final stored = switch (current?['updated_at']) {
      BeakDateTimeValue(:final value) => value,
      _ => null,
    };
    if (stored == null || !beakRevisionMatches(expected, stored)) {
      throw const _UnappliedWrite(
        BeakConflictException('The record changed since it was loaded.'),
      );
    }
    return stored;
  }

  Future<void> _conditionalDelete(
    BeakModel model,
    Object id,
    DateTime expected,
    WormDataSource data,
  ) async {
    final stored = await _requireRevision(model, id, expected, data);
    final where = Field<Object>(
      model.primaryKey.key,
    ).eq(id).and(const Field<DateTime>('updated_at').eq(stored));
    final affected = model.softDeletes
        ? await data.adapter.update(
            UpdateDescriptor(
              table: model.table,
              values: {'deleted_at': _now()},
              where: where.and(const Field<DateTime>('deleted_at').isNull()),
            ),
          )
        : await data.adapter.delete(
            DeleteDescriptor(table: model.table, where: where),
          );
    if (affected == 0) {
      throw const _UnappliedWrite(
        BeakConflictException('The record changed since it was loaded.'),
      );
    }
  }

  Future<BeakRecord> _conditionalUpdate(
    BeakModel model,
    Object id,
    BeakRecord input,
    DateTime expected,
    WormDataSource data,
  ) async {
    final stored = await _requireRevision(model, id, expected, data);
    final current = await data.getOne(model.table, id);
    final unchanged = input.values.entries.every(
      (entry) => entry.value == current?[entry.key],
    );
    final values = unchanged
        ? <String, Object?>{}
        : ({...input.toRow()}..remove(model.primaryKey.key));
    // A no-op still checks the exact revision in SQL, so a concurrent change
    // rejects the graph. Retaining the stamp avoids invalidating other editors.
    values['updated_at'] = unchanged
        ? stored
        : beakRevisionTimestamp(_now(), previous: stored);
    final affected = await data.adapter.update(
      UpdateDescriptor(
        table: model.table,
        values: values,
        where: Field<Object>(
          model.primaryKey.key,
        ).eq(id).and(const Field<DateTime>('updated_at').eq(stored)),
      ),
    );
    if (affected == 0) {
      if (unchanged && current != null) {
        // Changed-row engines can report zero for a matched no-op. Only an
        // explicit current/locking read may disambiguate it: a normal SELECT
        // could return an obsolete REPEATABLE READ snapshot after a race.
        if (data.adapter case final CurrentReadCapable currentReads) {
          var where = Field<Object>(
            model.primaryKey.key,
          ).eq(id).and(const Field<DateTime>('updated_at').eq(stored));
          if (model.softDeletes) {
            where = where.and(const Field<DateTime>('deleted_at').isNull());
          }
          final matched = await currentReads.selectOneCurrent(
            QueryDescriptor(table: model.table, where: where),
          );
          if (matched != null) return current;
        }
      }
      throw const _UnappliedWrite(
        BeakConflictException('The record changed since it was loaded.'),
      );
    }
    return await data.getOne(model.table, id) ??
        (throw const BeakNotFoundException(
          'The updated record could not be read.',
        ));
  }

  Future<void> _requireMembership(
    BeakRecordRef parent,
    BeakRecordRef child,
    String relationKey,
    Map<String, Object> identities,
    WormDataSource data,
    BeakPrincipal? principal,
  ) async {
    final model = registry.byTableOrThrow(parent.table);
    final childModel = registry.byTableOrThrow(child.table);
    final result = await _service(parent.table, data).query(
      model.query(
        filter: BeakFieldFilter(
          column: model.primaryKey,
          operator: BeakOperator.eq,
          value: BeakValue.of(parent.resolve(identities)),
        ),
        relationLoads: [
          BeakRelationLoad(
            relationKey,
            filter: BeakFieldFilter(
              column: childModel.primaryKey,
              operator: BeakOperator.eq,
              value: BeakValue.of(child.resolve(identities)),
            ),
          ),
        ],
      ),
      scope: _scope(parent.table, principal),
    );
    if (result.items.isEmpty ||
        (result.items.first.relations[relationKey]?.isEmpty ?? true)) {
      throw const BeakNotFoundException(
        'The related record does not belong to this owner.',
      );
    }
  }

  void _validateCreateScope(BeakRecord values, BeakFilter? scope) {
    // Equality scopes cover owner/tenant constraints without issuing a write.
    // More complex policies must expose an explicit canCreate policy instead.
    bool matches(BeakFilter? filter) => switch (filter) {
      null => true,
      BeakAndFilter(:final filters) => filters.every(matches),
      BeakOrFilter(:final filters) => filters.any(matches),
      BeakFieldFilter(
        :final columnKey,
        operator: BeakOperator.eq,
        :final value,
      ) =>
        values[columnKey]?.raw == value.raw,
      BeakFieldFilter(:final columnKey, operator: BeakOperator.isNull) =>
        values[columnKey]?.raw == null,
      _ => throw const BeakValidationException(
        'Create scope must be expressible as equality constraints.',
      ),
    };
    if (!matches(scope)) {
      throw const BeakAuthorizationException(
        'The new record is outside your permitted scope.',
      );
    }
  }

  void _require(bool allowed, BeakPrincipal? principal) {
    if (allowed) return;
    if (principal == null) {
      throw const BeakAuthenticationException('Authentication is required.');
    }
    throw const BeakAuthorizationException('This operation is not permitted.');
  }

  BeakSaveResult _pending(BeakSavePlan plan) => BeakSaveResult(
    saveId: plan.saveId,
    mode: commitCapabilities.atomicGraph
        ? BeakSaveMode.atomic
        : BeakSaveMode.staged,
    outcomes: [
      for (final op in plan.orderedOperations(registry))
        BeakOperationResult(
          id: op.id,
          status: BeakWriteOutcome.unapplied,
          reason: 'notStarted',
        ),
    ],
  );

  String _key(String saveId, BeakPrincipal? principal) => sha256
      .convert(utf8.encode(jsonEncode([principal?.id, saveId])))
      .toString();

  Future<Map<String, Object?>?> _receipt(DatabaseAdapter adapter, String key) =>
      adapter.selectOne(
        QueryDescriptor(
          table: BeakCommitReceiptsMigration.table,
          where: const StringField('id').eq(key),
          limit: 1,
        ),
      );

  Future<void> _insertReceipt(
    DatabaseAdapter adapter,
    String key,
    String request,
    String hash,
    BeakSaveResult result,
  ) async {
    await adapter.insert(
      InsertDescriptor(
        table: BeakCommitReceiptsMigration.table,
        values: {
          'id': key,
          'request_hash': hash,
          'request_json': request,
          'result_json': jsonEncode(result.toJson()),
        },
      ),
    );
  }

  Future<void> _writeReceipt(
    DatabaseAdapter adapter,
    String key,
    BeakSaveResult result, {
    String? expectedJson,
  }) async {
    var predicate = const StringField('id').eq(key);
    if (expectedJson != null) {
      predicate = predicate.and(
        const StringField('result_json').eq(expectedJson),
      );
    }
    final affected = await adapter.update(
      UpdateDescriptor(
        table: BeakCommitReceiptsMigration.table,
        values: {'result_json': jsonEncode(result.toJson())},
        where: predicate,
      ),
    );
    if (affected != 1) {
      throw const BeakConflictException(
        'This save is already being resumed elsewhere.',
      );
    }
  }

  BeakSaveResult _decodeReceipt(Map<String, Object?> receipt) =>
      BeakSaveResult.fromJson(_decodeMap(receipt['result_json']));

  Map<String, Object?> _decodeMap(Object? value) {
    if (value is String) {
      final Object? decoded = jsonDecode(value);
      if (decoded is Map<String, Object?>) return decoded;
    }
    throw const BeakConfigurationException('Malformed durable save receipt.');
  }
}

final class _Rollback implements Exception {
  const _Rollback(this.result);
  final BeakSaveResult result;
}

final class _UnappliedWrite implements Exception {
  const _UnappliedWrite(this.error);
  final BeakException error;
}

Object? _canonical(Object? value) => switch (value) {
  final Map<String, Object?> map => {
    for (final key in map.keys.toList()..sort()) key: _canonical(map[key]),
  },
  final List<Object?> values => [for (final item in values) _canonical(item)],
  _ => value,
};
