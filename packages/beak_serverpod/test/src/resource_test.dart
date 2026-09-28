import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid_value.dart';

void main() {
  final id = UuidValue.fromString('c4263bc1-cad9-453f-b4fa-e49891f8f824');
  const codec = _UserCodec();
  const model = ServerpodModel(
    resource: 'users',
    columns: [
      BeakStringColumn(key: 'id', label: 'ID'),
      BeakStringColumn(key: 'name', label: 'Name'),
    ],
    primaryKey: BeakStringColumn(key: 'id', label: 'ID'),
    displayColumn: BeakStringColumn(key: 'name', label: 'Name'),
  );

  test(
    'routes a typed page and decodes a UUID route before mutation',
    () async {
      var queries = 0;
      UuidValue? updatedId;
      _User? submitted;
      final source = ServerpodDataSource(
        resources: [
          ServerpodResource<_User, UuidValue, _User, _User>(
            model: model,
            codec: codec,
            idCodec: ServerpodCodecs.uuid,
            identify: (user) => user.id,
            query: (spec) async {
              queries += 1;
              expect(spec.pagination.page, 2);
              return BeakPage(
                items: [_User(id, 'Ada')],
                total: 40,
                page: 2,
                perPage: 10,
              );
            },
            get: (requested) async => _User(requested, 'Ada'),
            updateCodec: codec,
            update: (requested, input) async {
              updatedId = requested;
              submitted = input;
              return input;
            },
          ),
        ],
      );
      final page = await source.query(
        const BeakQuerySpec(table: 'users').paginate(page: 2, perPage: 10),
      );
      expect(page.total, 40);
      expect(page.items.single['id']?.raw, id.uuid);
      expect(queries, 1);
      await source.update('users', id.uuid, codec.encode(_User(id, 'Grace')));
      expect(updatedId, id);
      expect(submitted?.name, 'Grace');
    },
  );

  test(
    'rejects malformed route IDs, unknown resources and unbound writes',
    () async {
      final source = ServerpodDataSource(
        resources: [
          ServerpodResource<_User, UuidValue, Never, Never>(
            model: model,
            codec: codec,
            idCodec: ServerpodCodecs.uuid,
            identify: (user) => user.id,
            query: (_) async =>
                const BeakPage(items: [], total: 0, page: 1, perPage: 20),
            get: (_) async => null,
          ),
        ],
      );
      expect(
        () => source.getOne('users', 'wrong'),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        () => source.getOne('other', id),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => source.delete('users', id),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        () => source.restore('users', id),
        throwsA(isA<BeakValidationException>()),
      );
      expect(await source.getOne('users', id), isNull);
      expect(source.binding('users').operations, {
        ServerpodOperation.query,
        ServerpodOperation.get,
      });
      final unsupported = <Future<Object?> Function()>[
        () => source.create('users', const BeakRecord(values: {})),
        () => source.update('users', id, const BeakRecord(values: {})),
        () => source.delete('users', id, force: true),
        () => source.batchGet('users', [id]),
        () => source.aggregate(const BeakAggregateSpec.count(table: 'users')),
        () => source.loadEditValues('users', id),
        () => source.attach('users', id, 'roles', [id]),
        () => source.detach('users', id, 'roles', [id]),
      ];
      for (final run in unsupported) {
        await expectLater(run(), throwsA(isA<BeakValidationException>()));
      }
    },
  );

  test(
    'edit prefill shares domain error mapping with CRUD operations',
    () async {
      final failure = Exception('transport detail');
      final source = ServerpodDataSource(
        resources: [
          ServerpodResource<_User, UuidValue, _User, _User>(
            model: model,
            codec: codec,
            idCodec: ServerpodCodecs.uuid,
            identify: (user) => user.id,
            query: (_) async =>
                const BeakPage(items: [], total: 0, page: 1, perPage: 20),
            get: (_) async => throw failure,
            updateCodec: codec,
            editValues: (user) => user,
          ),
        ],
        mapException: (error, _) => identical(error, failure)
            ? const BeakNotFoundException('Safe message')
            : null,
      );
      await expectLater(
        source.loadEditValues('users', id.uuid),
        throwsA(isA<BeakNotFoundException>()),
      );
    },
  );

  test(
    'bound commands retain identity, edit shape and explicit delete semantics',
    () async {
      var archived = false;
      var purged = false;
      final user = _User(id, 'Ada');
      final binding = ServerpodResource<_User, UuidValue, _User, _User>(
        model: model,
        codec: codec,
        idCodec: ServerpodCodecs.uuid,
        identify: (user) => user.id,
        query: (_) async =>
            BeakPage(items: [user], total: 1, page: 1, perPage: 20),
        get: (key) async => key == id ? user : null,
        createCodec: codec,
        create: (input) async => input,
        updateCodec: codec,
        update: (_, input) async => input,
        editValues: (user) => _User(user.id, '${user.name} edit'),
        archive: (key) async {
          expect(key, id);
          archived = true;
        },
        forceDelete: (key) async {
          expect(key, id);
          purged = true;
        },
        restore: (_) async => user,
        batchGet: (keys) async {
          expect(keys, [id]);
          return [user];
        },
        aggregate: (spec) async {
          expect(spec.table, 'users');
          return 7;
        },
      );
      final source = ServerpodDataSource(resources: [binding]);
      expect(binding.operations, ServerpodOperation.values.toSet());
      expect(binding.capabilities, BeakOperation.values.toSet());
      expect(binding.table, model.table);
      expect(binding.primaryKey, model.primaryKey);
      expect(binding.columns, model.columns);
      expect(binding.displayColumnKey, model.displayColumnKey);
      expect(binding.relationships, isEmpty);
      expect(binding.permissions.allows(BeakOperation.read), isTrue);
      expect(identical(binding.dataSource, binding.dataSource), isTrue);
      expect(
        (await source.create('users', codec.encode(user)))['id']?.raw,
        id.uuid,
      );
      expect(
        (await source.loadEditValues('users', id.uuid))['name']?.raw,
        'Ada edit',
      );
      expect((await source.getOne('users', id))?['name']?.raw, 'Ada');
      await source.delete('users', id.uuid);
      expect(archived, isTrue);
      expect(purged, isFalse);
      await source.delete('users', id, force: true);
      expect(purged, isTrue);
      expect((await source.restore('users', id))['id']?.raw, id.uuid);
      expect(
        (await source.batchGet('users', [id.uuid])).single['id']?.raw,
        id.uuid,
      );
      expect(
        await source.aggregate(const BeakAggregateSpec.count(table: 'users')),
        7,
      );
      await expectLater(
        source.loadEditValues('users', '509d28ed-f009-41ef-8d46-84a728f3f019'),
        throwsA(isA<BeakNotFoundException>()),
      );
      expect(
        () => ServerpodDataSource(resources: [binding, binding]),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'integer routes decode without truncating and unknown failures propagate',
    () async {
      final failure = Exception('unexpected');
      int? requested;
      final source = ServerpodDataSource(
        resources: [
          ServerpodResource<_User, int, Never, Never>(
            model: model,
            codec: codec,
            idCodec: ServerpodCodecs.integer,
            identify: (_) => 42,
            query: (_) async => throw failure,
            get: (id) async {
              requested = id;
              return null;
            },
          ),
        ],
        mapException: (_, _) => null,
      );
      await source.getOne('users', '42');
      expect(requested, 42);
      await expectLater(
        source.getOne('users', '42.5'),
        throwsA(isA<BeakValidationException>()),
      );
      await expectLater(
        source.query(const BeakQuerySpec(table: 'users')),
        throwsA(same(failure)),
      );
    },
  );
}

final class _User {
  const _User(this.id, this.name);
  final UuidValue id;
  final String name;
}

final class _UserCodec extends ServerpodCodec<_User> {
  const _UserCodec();
  @override
  BeakRecord encode(_User value) => BeakRecord(
    values: {
      'id': ServerpodCodecs.uuid.encode(value.id),
      'name': ServerpodCodecs.string.encode(value.name),
    },
  );
  @override
  _User decode(BeakRecord value) => _User(
    ServerpodCodecs.uuid.decode(value['id']),
    ServerpodCodecs.string.decode(value['name']),
  );
}
