import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

final class _DenyComments extends BeakAllowAllPolicy {
  const _DenyComments();
  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) =>
      model is! CommentModel;
}

/// Admits a comment only when it reads "Visible": an operation the policy
/// refuses at dispatch, after the note before it was written.
final class _VisibleCommentsOnly extends BeakAllowAllPolicy
    implements BeakRowPolicy {
  const _VisibleCommentsOnly();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is CommentModel ? CommentModel.message.eq('Visible') : null;
}

final class _HiddenCommentScope extends BeakAllowAllPolicy
    implements BeakRowPolicy {
  const _HiddenCommentScope();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      switch (model) {
        NoteModel() => NoteModel.comments.any(
          CommentModel.message.eq('Hidden'),
        ),
        CommentModel() => CommentModel.message.eq('Visible'),
        _ => null,
      };
}

/// Admits only the notes titled "Mine".
final class _MineOnly extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _MineOnly();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is NoteModel ? NoteModel.title.eq('Mine') : null;
}

final class _OwnedNote extends BeakModel {
  const _OwnedNote();
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => NoteColumns.values;
  @override
  List<BeakRelationship> get relationships => const [
    BeakHasMany(
      key: 'comments',
      label: 'Comments',
      relatedTable: 'comments',
      displayColumnKey: 'message',
      foreignKey: 'note_id',
      owned: true,
    ),
  ];
}

final class _LostInsertAdapter extends DatabaseAdapter {
  _LostInsertAdapter(this.inner);
  final DatabaseAdapter inner;
  int businessWrites = 0;
  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor query) =>
      inner.selectOne(query);
  @override
  Future<int> update(UpdateDescriptor update) => inner.update(update);
  @override
  Future<Map<String, Object?>> insert(InsertDescriptor insert) async {
    final result = await inner.insert(insert);
    if (insert.table == 'notes') {
      businessWrites++;
      throw StateError('connection disappeared after insert');
    }
    return result;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BeakSavePlan _plan({String saveId = 'save', bool invalid = false}) =>
    BeakSavePlan(
      saveId: saveId,
      root: const BeakRecordRef.draft('notes', 'note'),
      operations: [
        BeakSaveOperation(
          id: 'note',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('notes', 'note'),
          values: BeakRecord.fromRow({'title': 'A note'}),
        ),
        BeakSaveOperation(
          id: 'comment',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('comments', 'comment'),
          owner: const BeakRecordRef.draft('notes', 'note'),
          relationKey: 'comments',
          values: BeakRecord.fromRow({'message': invalid ? 42 : 'A comment'}),
        ),
      ],
    );

void main() {
  late InMemoryAdapter adapter;
  late WormDataSource source;
  late BeakGraphCommitService service;
  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    source = WormDataSource(createApiRegistry(), adapter: adapter);
    service = BeakGraphCommitService(
      registry: createApiRegistry(),
      source: source,
    );
  });
  tearDown(Worm.reset);

  test(
    'finalizer receives persisted identities and effects replay only once',
    () async {
      await const BeakOutboxMigration().up(adapter);
      var calls = 0;
      service = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: source,
        finalizePlan: (plan, result, transaction, principal) async {
          calls++;
          expect(
            await transaction.getOne('notes', result.identities['note']!),
            isNotNull,
          );
          await BeakOutbox.enqueue(
            transaction.adapter,
            key: '${plan.saveId}:email',
            kind: 'email',
            payload: BeakRecord.fromRow({'noteId': result.identities['note']}),
          );
        },
      );
      expect((await service.commit(_plan())).complete, isTrue);
      expect((await service.commit(_plan())).complete, isTrue);
      expect(calls, 1);
      expect(
        await adapter.count(
          const AggregateDescriptor.count(table: BeakOutboxMigration.table),
        ),
        1,
      );
    },
  );

  test(
    'finalizer rejection rolls back graph and effect with definite receipt',
    () async {
      await const BeakOutboxMigration().up(adapter);
      service = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: source,
        finalizePlan: (plan, result, transaction, principal) async {
          await BeakOutbox.enqueue(
            transaction.adapter,
            key: '${plan.saveId}:email',
            kind: 'email',
            payload: BeakRecord.fromRow({'noteId': result.identities['note']}),
          );
          throw const BeakValidationException(
            'Capacity is no longer available.',
          );
        },
      );
      final result = await service.commit(_plan());
      expect(result.complete, isFalse);
      expect(result.hasUnknown, isFalse);
      expect(
        await adapter.count(const AggregateDescriptor.count(table: 'notes')),
        0,
      );
      expect(
        await adapter.count(
          const AggregateDescriptor.count(table: BeakOutboxMigration.table),
        ),
        0,
      );
      expect((await service.commit(_plan())).toJson(), result.toJson());
    },
  );

  test(
    'parent and child save atomically and recover after service restart',
    () async {
      final result = await service.commit(_plan());
      expect(result.complete, isTrue);
      expect(result.mode, BeakSaveMode.atomic);
      final comment = await source.getOne(
        'comments',
        result.identities['comment']!,
      );
      expect(comment?['note_id']?.raw, result.identities['note']);
      final restarted = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: source,
      );
      expect((await restarted.recover('save')).toJson(), result.toJson());
      expect((await restarted.commit(_plan())).toJson(), result.toJson());
      expect(
        (await source.query(const BeakQuerySpec(table: 'notes'))).total,
        1,
      );
    },
  );

  test('later validation failure rolls back every write', () async {
    final result = await service.commit(_plan(invalid: true));
    expect(result.complete, isFalse);
    expect(
      result.outcomes.every(
        (entry) => entry.status == BeakWriteOutcome.unapplied,
      ),
      isTrue,
    );
    expect((await source.query(const BeakQuerySpec(table: 'notes'))).total, 0);
    expect(result.outcomes.last.error?.code, 'validation');
  });

  test('nested permission denial leaves no parent behind', () async {
    service = BeakGraphCommitService(
      registry: createApiRegistry(),
      source: source,
      policy: const _DenyComments(),
    );
    final result = await service.commit(_plan());
    expect(result.complete, isFalse);
    expect((await source.query(const BeakQuerySpec(table: 'notes'))).total, 0);
  });

  test('an existing child cannot be edited through another owner', () async {
    final first = await service.commit(_plan());
    final second = await service.commit(_plan(saveId: 'second'));
    final result = await service.commit(
      BeakSavePlan(
        saveId: 'spoof',
        root: BeakRecordRef.existing('notes', first.identities['note']!),
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: BeakRecordRef.existing(
              'comments',
              second.identities['comment']!,
            ),
            owner: BeakRecordRef.existing('notes', first.identities['note']!),
            relationKey: 'comments',
            values: BeakRecord.fromRow({'message': 'stolen'}),
          ),
        ],
      ),
    );
    expect(result.complete, isFalse);
    final child = await source.getOne(
      'comments',
      second.identities['comment']!,
    );
    expect(child?['message']?.raw, 'A comment');
  });

  test(
    'graph writes cannot satisfy a row policy through a hidden child',
    () async {
      final note = await source.create(
        'notes',
        BeakRecord.fromRow({'id': 'scoped-note', 'title': 'Original'}),
      );
      final noteId = const NoteModel().primaryKeyOf(note)!;
      await source.create(
        'comments',
        BeakRecord.fromRow({
          'id': 'hidden-comment',
          'note_id': noteId,
          'message': 'Hidden',
        }),
      );
      final scoped = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: source,
        policy: const _HiddenCommentScope(),
      );
      final ref = BeakRecordRef.existing('notes', noteId);
      final result = await scoped.commit(
        BeakSavePlan(
          saveId: 'scoped-edit',
          root: ref,
          operations: [
            BeakSaveOperation(
              id: 'edit',
              kind: BeakSaveOperationKind.update,
              target: ref,
              values: BeakRecord.fromRow({'title': 'Changed'}),
            ),
          ],
        ),
      );
      expect(result.complete, isFalse);
      expect((await source.getOne('notes', noteId))?['title']?.raw, 'Original');
    },
  );

  test(
    'concurrent duplicate requests execute once and changed payload conflicts',
    () async {
      final results = await Future.wait([
        service.commit(_plan()),
        service.commit(_plan()),
      ]);
      expect(results[0].toJson(), results[1].toJson());
      expect(
        (await source.query(const BeakQuerySpec(table: 'notes'))).total,
        1,
      );
      expect(
        () => service.commit(_plan(invalid: true)),
        throwsA(isA<BeakConflictException>()),
      );
    },
  );

  test('receipts belong to the authenticated principal', () async {
    await service.commit(_plan(), principal: const BeakPrincipal(id: 'alice'));
    expect(
      () => service.recover('save', principal: const BeakPrincipal(id: 'bob')),
      throwsA(isA<BeakNotFoundException>()),
    );
  });

  test(
    'nontransactional backend preserves partial success and resumes pending writes',
    () async {
      final stagedAdapter = InMemoryAdapter(
        capabilities: const AdapterCapabilities(),
      );
      await stagedAdapter.connect();
      addTearDown(stagedAdapter.close);
      for (final descriptor in apiSchema) {
        await stagedAdapter.executeSchema(descriptor);
      }
      await const BeakCommitReceiptsMigration().up(stagedAdapter);
      final stagedSource = WormDataSource(
        createApiRegistry(),
        adapter: stagedAdapter,
      );
      final denied = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: stagedSource,
        policy: const _VisibleCommentsOnly(),
      );
      final partial = await denied.commit(_plan());
      expect(partial.mode, BeakSaveMode.staged);
      expect(partial.outcomes.first.status, BeakWriteOutcome.applied);
      expect(partial.outcomes.last.status, BeakWriteOutcome.unapplied);
      expect(
        (await stagedSource.query(const BeakQuerySpec(table: 'notes'))).total,
        1,
      );
      final resumed = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: stagedSource,
      );
      final result = await resumed.commit(_plan());
      expect(result.complete, isTrue);
      expect(result.identities['note'], partial.identities['note']);
      expect(
        (await stagedSource.query(const BeakQuerySpec(table: 'notes'))).total,
        1,
      );
      expect(
        (await stagedSource.query(
          const BeakQuerySpec(table: 'comments'),
        )).total,
        1,
      );
    },
  );

  test(
    'nested delete refuses shared relations even with delete permission',
    () async {
      final created = await service.commit(_plan());
      final root = BeakRecordRef.existing('notes', created.identities['note']!);
      final child = BeakRecordRef.existing(
        'comments',
        created.identities['comment']!,
      );
      final result = await service.commit(
        BeakSavePlan(
          saveId: 'remove',
          root: root,
          operations: [
            BeakSaveOperation(
              id: 'remove-child',
              kind: BeakSaveOperationKind.delete,
              target: child,
              owner: root,
              relationKey: 'comments',
            ),
          ],
        ),
      );
      expect(result.complete, isFalse);
      expect(await source.getOne('comments', child.id!), isNotNull);
    },
  );

  test('a detach checks that the child belongs to the owner', () async {
    for (final (note, comment) in [
      ('mine', 'c-mine'),
      ('theirs', 'c-theirs'),
    ]) {
      await source.create(
        'notes',
        BeakRecord.fromRow({
          'id': note,
          'title': note == 'mine' ? 'Mine' : 'Theirs',
        }),
      );
      await source.create(
        'comments',
        BeakRecord.fromRow({'id': comment, 'note_id': note, 'message': 'Hi'}),
      );
    }
    final scoped = BeakGraphCommitService(
      registry: createApiRegistry(),
      source: source,
      policy: const _MineOnly(),
    );
    const mine = BeakRecordRef.existing('notes', 'mine');
    Future<BeakSaveResult> detach(String comment) => scoped.commit(
      BeakSavePlan(
        saveId: 'detach-$comment',
        root: mine,
        operations: [
          BeakSaveOperation(
            id: 'unlink',
            kind: BeakSaveOperationKind.detach,
            target: mine,
            related: BeakRecordRef.existing('comments', comment),
            relationKey: 'comments',
          ),
        ],
      ),
    );

    expect((await detach('c-mine')).complete, isTrue);
    expect((await detach('c-theirs')).complete, isFalse);
    expect(
      (await source.getOne('comments', 'c-theirs'))?['note_id']?.raw,
      'theirs',
      reason: 'a comment of another note is not this owner\'s to detach',
    );
  });

  test(
    'the membership query of a scoped detach carries the row scope',
    () async {
      // Every caller has already read the owner through the scope, so no
      // outcome tells a scoped membership query from an unscoped one; the
      // query itself does. The scope value 'Mine' differs from the id 'mine'.
      final logger = InMemoryQueryLogger();
      final logged = WormDataSource(
        createApiRegistry(),
        adapter: LoggingAdapter(
          inner: adapter,
          logger: logger,
          strictness: const StrictnessConfig(),
          adapterName: 'InMemory',
        ),
      );
      await logged.create(
        'notes',
        BeakRecord.fromRow({'id': 'mine', 'title': 'Mine'}),
      );
      await logged.create(
        'comments',
        BeakRecord.fromRow({
          'id': 'c-mine',
          'note_id': 'mine',
          'message': 'Hi',
        }),
      );
      final seeded = logger.entries.length;
      const mine = BeakRecordRef.existing('notes', 'mine');

      final result =
          await BeakGraphCommitService(
            registry: createApiRegistry(),
            source: logged,
            policy: const _MineOnly(),
          ).commit(
            BeakSavePlan(
              saveId: 'detach-logged',
              root: mine,
              operations: [
                BeakSaveOperation(
                  id: 'unlink',
                  kind: BeakSaveOperationKind.detach,
                  target: mine,
                  related: const BeakRecordRef.existing('comments', 'c-mine'),
                  relationKey: 'comments',
                ),
              ],
            ),
          );

      expect(result.complete, isTrue);
      // Single-row reads (`LIMIT 1`) are the scoped owner read and the
      // re-read that validates the final state; the one page query on the
      // owner table, loading the relation, is the membership check.
      final membership = [
        for (final entry in logger.entries.skip(seeded))
          if (entry.table == 'notes' &&
              entry.statement.startsWith('SELECT') &&
              !entry.statement.endsWith('LIMIT 1'))
            entry,
      ];
      expect(membership, hasLength(1));
      expect(
        membership.single.parameters,
        contains('Mine'),
        reason: membership.single.statement,
      );
    },
  );

  test('relationship detach and reattach preserve the child record', () async {
    final created = await service.commit(_plan());
    final parent = BeakRecordRef.existing('notes', created.identities['note']!);
    final child = BeakRecordRef.existing(
      'comments',
      created.identities['comment']!,
    );
    Future<BeakSaveResult> link(BeakSaveOperationKind kind) => service.commit(
      BeakSavePlan(
        saveId: kind.name,
        root: parent,
        operations: [
          BeakSaveOperation(
            id: 'link',
            kind: kind,
            target: parent,
            related: child,
            relationKey: 'comments',
          ),
        ],
      ),
    );
    expect((await link(BeakSaveOperationKind.detach)).complete, isTrue);
    final detached = await source.getOne('comments', child.id!);
    expect(detached?['note_id']?.raw, isNull);
    expect(detached?['message']?.raw, 'A comment');
    expect((await link(BeakSaveOperationKind.attach)).complete, isTrue);
    expect(
      (await source.getOne('comments', child.id!))?['note_id']?.raw,
      parent.id,
    );
  });

  test(
    'relationship linking cannot silently steal another owner child',
    () async {
      final first = await service.commit(_plan());
      final second = await service.commit(_plan(saveId: 'second'));
      final parent = BeakRecordRef.existing('notes', first.identities['note']!);
      final child = BeakRecordRef.existing(
        'comments',
        second.identities['comment']!,
      );
      final result = await service.commit(
        BeakSavePlan(
          saveId: 'steal-link',
          root: parent,
          operations: [
            BeakSaveOperation(
              id: 'link',
              kind: BeakSaveOperationKind.attach,
              target: parent,
              related: child,
              relationKey: 'comments',
            ),
          ],
        ),
      );
      expect(result.complete, isFalse);
      expect(result.outcomes.single.error?.code, 'validation');
      expect(
        (await source.getOne('comments', child.id!))?['note_id']?.raw,
        second.identities['note'],
      );
    },
  );

  test(
    'owned deletion removes a member after explicit ownership authorization',
    () async {
      final created = await service.commit(_plan());
      final parent = BeakRecordRef.existing(
        'notes',
        created.identities['note']!,
      );
      final child = BeakRecordRef.existing(
        'comments',
        created.identities['comment']!,
      );
      final owned = BeakGraphCommitService(
        registry: BeakModelRegistry()
          ..register(const _OwnedNote())
          ..register(const CommentModel()),
        source: source,
      );
      final result = await owned.commit(
        BeakSavePlan(
          saveId: 'owned-delete',
          root: parent,
          operations: [
            BeakSaveOperation(
              id: 'delete',
              kind: BeakSaveOperationKind.delete,
              target: child,
              owner: parent,
              relationKey: 'comments',
            ),
          ],
        ),
      );
      expect(result.complete, isTrue);
      expect(await source.getOne('comments', child.id!), isNull);
      expect(await source.getOne('notes', parent.id!), isNotNull);
    },
  );

  test('conditional update uses the version in the actual mutation', () async {
    final created = await service.commit(_plan());
    final root = BeakRecordRef.existing('notes', created.identities['note']!);
    final stamp = switch (created.rootRecord!['updated_at']) {
      BeakDateTimeValue(:final value) => value,
      _ => fail('Expected the saved record to include an update timestamp.'),
    };
    BeakSavePlan patch(String saveId, String title) => BeakSavePlan(
      saveId: saveId,
      root: root,
      operations: [
        BeakSaveOperation(
          id: 'edit',
          kind: BeakSaveOperationKind.update,
          target: root,
          expectedUpdatedAt: stamp,
          values: BeakRecord.fromRow({'title': title}),
        ),
      ],
    );
    expect(
      (await service.commit(patch('first-edit', 'First'))).complete,
      isTrue,
    );
    final stale = await service.commit(patch('stale-edit', 'Second'));
    expect(stale.complete, isFalse);
    expect(stale.outcomes.single.error?.code, 'conflict');
    expect((await source.getOne('notes', root.id!))?['title']?.raw, 'First');
  });

  test(
    'a staged lost write response remains unknown after restart and is never replayed',
    () async {
      final lost = _LostInsertAdapter(adapter);
      final uncertainSource = WormDataSource(
        createApiRegistry(),
        adapter: lost,
      );
      final uncertain = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: uncertainSource,
      );
      final result = await uncertain.commit(_plan());
      expect(result.mode, BeakSaveMode.staged);
      expect(result.outcomes.first.status, BeakWriteOutcome.unknown);
      expect(result.outcomes.last.status, BeakWriteOutcome.unapplied);
      expect(
        (await source.query(const BeakQuerySpec(table: 'notes'))).total,
        1,
      );
      final restarted = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: uncertainSource,
      );
      expect((await restarted.recover('save')).hasUnknown, isTrue);
      expect((await restarted.commit(_plan())).hasUnknown, isTrue);
      expect(lost.businessWrites, 1);
      expect(
        (await source.query(const BeakQuerySpec(table: 'comments'))).total,
        0,
      );
    },
  );
}
