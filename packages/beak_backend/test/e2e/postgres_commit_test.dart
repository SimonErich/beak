@Tags(['e2e'])
library;

import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../support/api_models.dart';

/// The Postgres endpoint under test, matching `docker-compose.yml`; override
/// via `DATABASE_URL`.
final Uri databaseUrl = Uri.parse(
  Platform.environment['DATABASE_URL'] ??
      'postgres://beak:beak@localhost:25432/beak',
);

Future<bool> postgresIsReachable() async {
  try {
    final socket = await Socket.connect(
      databaseUrl.host,
      databaseUrl.port,
      timeout: const Duration(seconds: 3),
    );
    await socket.close();
    return true;
  } on Object {
    return false;
  }
}

/// A tag whose name is unique, in the model and as an index in the database.
final class _Tag extends BeakModel {
  const _Tag();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name', unique: true),
  ];
}

SchemaColumn _key() =>
    const SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true);

SchemaColumn _column(String name, ColumnType type) =>
    SchemaColumn(name: name, type: type, nullable: true);

/// The tables the graphs below write, with every column but the key nullable
/// as the models declare them.
final List<SchemaDescriptor> _schema = [
  SchemaDescriptor.createTable(
    table: 'notes',
    columns: [
      _key(),
      _column('title', ColumnType.text),
      _column('body', ColumnType.text),
      _column('rating', ColumnType.integer),
      _column('status', ColumnType.text),
      _column('published', ColumnType.boolean),
      _column('author_email', ColumnType.text),
      _column('author_id', ColumnType.text),
      _column('created_at', ColumnType.dateTime),
      _column('updated_at', ColumnType.dateTime),
      _column('avatar', ColumnType.text),
      _column('attachment', ColumnType.text),
      _column('deleted_at', ColumnType.dateTime),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'comments',
    columns: [
      _key(),
      _column('note_id', ColumnType.text),
      _column('message', ColumnType.text),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'authors',
    columns: [_key(), _column('name', ColumnType.text)],
  ),
  SchemaDescriptor.createTable(
    table: 'tags',
    columns: [_key(), _column('name', ColumnType.text)],
    indexes: [
      const SchemaIndex(name: 'tags_name_key', columns: ['name'], unique: true),
    ],
  ),
];

/// A caller sees, and may write, only the notes they authored.
final class _OwnNotes extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _OwnNotes();

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is NoteModel && principal != null
      ? NoteModel.authorId.eq(principal.id)
      : null;
}

/// Refuses every write.
final class _DenyAll extends BeakAllowAllPolicy {
  const _DenyAll();

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) => false;
}

BeakSavePlan _createNote(String saveId, {String author = 'sam'}) =>
    BeakSavePlan(
      saveId: saveId,
      root: const BeakRecordRef.draft('notes', 'note'),
      operations: [
        BeakSaveOperation(
          id: 'note',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('notes', 'note'),
          values: BeakRecord.fromRow({'title': 'A note', 'author_id': author}),
        ),
        BeakSaveOperation(
          id: 'comment',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('comments', 'comment'),
          owner: const BeakRecordRef.draft('notes', 'note'),
          relationKey: 'comments',
          values: BeakRecord.fromRow({'message': 'A comment'}),
        ),
      ],
    );

/// Graph commits on the database they are meant for: real transactions, real
/// unique violations, and two connections that race for one save id.
void main() {
  late bool reachable;
  late DatabaseAdapter admin;
  late DatabaseAdapter first;
  late DatabaseAdapter second;
  late String scratchName;
  late BeakModelRegistry registry;

  setUpAll(() async {
    reachable = await postgresIsReachable();
    if (!reachable) return;
    admin = adapterFromUrl(databaseUrl);
    await admin.connect();
    scratchName = 'beak_commit_e2e_${DateTime.now().microsecondsSinceEpoch}';
    await admin.rawQuery('CREATE DATABASE $scratchName', const []);
    first = adapterFromUrl(databaseUrl.replace(path: '/$scratchName'));
    await first.connect();
    second = adapterFromUrl(databaseUrl.replace(path: '/$scratchName'));
    await second.connect();
    for (final descriptor in _schema) {
      await first.executeSchema(descriptor);
    }
    await const BeakCommitReceiptsMigration().up(first);
    registry = createApiRegistry()..register(const _Tag());
    await first.insert(
      const InsertDescriptor(
        table: 'authors',
        values: {'id': 'sam', 'name': 'Sam'},
      ),
    );
    await first.insert(
      const InsertDescriptor(
        table: 'authors',
        values: {'id': 'mia', 'name': 'Mia'},
      ),
    );
  });

  tearDownAll(() async {
    if (!reachable) return;
    await first.disconnect();
    await second.disconnect();
    await admin.rawQuery('DROP DATABASE IF EXISTS $scratchName', const []);
    await admin.disconnect();
  });

  bool guarded() {
    if (!reachable) {
      markTestSkipped(
        'Postgres is unreachable at ${databaseUrl.host}:${databaseUrl.port}.',
      );
    }
    return reachable;
  }

  BeakGraphCommitService serviceOn(
    DatabaseAdapter adapter, {
    BeakPolicy policy = const BeakAllowAllPolicy(),
  }) => BeakGraphCommitService(
    registry: registry,
    source: WormDataSource(registry, adapter: adapter),
    policy: policy,
  );

  Future<int> count(String table) =>
      first.count(AggregateDescriptor.count(table: table));

  test('two connections racing for one save id write it once', () async {
    if (!guarded()) return;
    final before = await count('notes');
    final plan = _createNote('race');

    final results = await Future.wait([
      serviceOn(first).commit(plan),
      serviceOn(second).commit(plan),
    ]);

    expect(results[0].complete, isTrue);
    expect(results[1].complete, isTrue);
    expect(results[1].toJson(), results[0].toJson());
    expect(await count('notes'), before + 1);
  });

  test('two connections racing for a save that is rejected agree on the '
      'rejection', () async {
    if (!guarded()) return;
    final before = await count('notes');
    final plan = BeakSavePlan(
      saveId: 'race-rejected',
      root: const BeakRecordRef.draft('notes', 'note'),
      operations: [
        BeakSaveOperation(
          id: 'note',
          kind: BeakSaveOperationKind.create,
          target: const BeakRecordRef.draft('notes', 'note'),
          values: BeakRecord.fromRow({'title': 'x' * 41}),
        ),
      ],
    );

    final results = await Future.wait([
      serviceOn(first).commit(plan),
      serviceOn(second).commit(plan),
    ]);

    expect(results[0].complete, isFalse);
    expect(results[0].outcomes.single.error?.code, 'validation');
    expect(results[1].toJson(), results[0].toJson());
    expect(await count('notes'), before);
  });

  test('and a changed plan under that id is a conflict', () async {
    if (!guarded()) return;

    await expectLater(
      serviceOn(second).commit(_createNote('race', author: 'mia')),
      throwsA(isA<BeakConflictException>()),
    );
  });

  test('a refused save stores no receipt on Postgres either', () async {
    if (!guarded()) return;
    final before = await count(BeakCommitReceiptsMigration.table);

    final result = await serviceOn(
      first,
      policy: const _DenyAll(),
    ).commit(_createNote('denied'));

    expect(result.complete, isFalse);
    expect(result.outcomes.first.error?.code, 'authentication');
    expect(await count(BeakCommitReceiptsMigration.table), before);
  });

  test(
    'a rejected save that rolled back leaves no rows and one receipt',
    () async {
      if (!guarded()) return;
      final notes = await count('notes');
      final receipts = await count(BeakCommitReceiptsMigration.table);
      final plan = BeakSavePlan(
        saveId: 'invalid',
        root: const BeakRecordRef.draft('notes', 'note'),
        operations: [
          BeakSaveOperation(
            id: 'note',
            kind: BeakSaveOperationKind.create,
            target: const BeakRecordRef.draft('notes', 'note'),
            values: BeakRecord.fromRow({'title': 'x' * 41}),
          ),
        ],
      );

      final result = await serviceOn(first).commit(plan);
      final replay = await serviceOn(second).commit(plan);

      expect(result.outcomes.single.error?.code, 'validation');
      expect(replay.toJson(), result.toJson());
      expect(await count('notes'), notes);
      expect(await count(BeakCommitReceiptsMigration.table), receipts + 1);
    },
  );

  test('a scoped caller cannot hand a row to another owner', () async {
    if (!guarded()) return;
    const sam = BeakPrincipal(id: 'sam');
    await first.insert(
      const InsertDescriptor(
        table: 'notes',
        values: {'id': 'scoped', 'title': 'Mine', 'author_id': 'sam'},
      ),
    );

    final result = await serviceOn(first, policy: const _OwnNotes()).commit(
      BeakSavePlan(
        saveId: 'give-away',
        root: const BeakRecordRef.existing('notes', 'scoped'),
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: const BeakRecordRef.existing('notes', 'scoped'),
            values: BeakRecord.fromRow({'author_id': 'mia'}),
          ),
        ],
      ),
      principal: sam,
    );

    expect(result.complete, isFalse);
    expect(result.outcomes.single.error?.code, 'authorization');
    final row = await first.selectOne(
      QueryDescriptor(
        table: 'notes',
        where: const StringField('id').eq('scoped'),
      ),
    );
    expect(row?['author_id'], 'sam');
  });

  test(
    'a unique index that fires mid-graph rolls the whole graph back',
    () async {
      if (!guarded()) return;
      final plan = BeakSavePlan(
        saveId: 'twin-tags',
        root: const BeakRecordRef.draft('tags', 'one'),
        operations: [
          for (final draft in ['one', 'two'])
            BeakSaveOperation(
              id: draft,
              kind: BeakSaveOperationKind.create,
              target: BeakRecordRef.draft('tags', draft),
              values: BeakRecord.fromRow({'name': 'red'}),
            ),
        ],
      );

      final result = await serviceOn(first).commit(plan);

      expect(result.complete, isFalse);
      expect(result.hasUnknown, isFalse);
      expect(result.outcomes.map((outcome) => outcome.error?.code).nonNulls, [
        'conflict',
      ]);
      expect(await count('tags'), 0);
      expect((await serviceOn(second).commit(plan)).toJson(), result.toJson());
    },
  );
}
