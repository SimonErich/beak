import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:beak_backend/beak_backend.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

import '../../support/api_models.dart';
import '../../support/json_mutation.dart';

/// A posted spec is hostile input: however it is mangled, the endpoint
/// answers 200 or a 4xx and never a 500, which would mean the caller's
/// mistake reached the database as a statement it could not run.
///
/// Set `BEAK_FUZZ_DATABASE_URL` to a Postgres URL (a scratch database: the
/// suite creates and drops its own tables) to run the same requests where
/// types are strict.
void main() {
  final documents = <String, Map<String, Object?>>{
    '/api/notes/query': {
      'table': 'notes',
      'filter': {
        'type': 'and',
        'filters': [
          {'type': 'field', 'column': 'rating', 'operator': 'gt', 'value': 1},
          {
            'type': 'or',
            'filters': [
              {
                'type': 'field',
                'column': 'created_at',
                'operator': 'lt',
                'value': {'type': 'dateTime', 'value': '2026-01-01T00:00:00Z'},
              },
              {
                'type': 'relation',
                'relation': 'author',
                'filter': {
                  'type': 'field',
                  'column': 'name',
                  'operator': 'contains',
                  'value': 'a',
                },
              },
              {
                'type': 'field',
                'column': 'status',
                'operator': 'inList',
                'value': ['draft', 'published'],
              },
            ],
          },
        ],
      },
      'sorts': [
        {'column': 'rating', 'descending': true},
      ],
      'search': {
        'term': 'x',
        'columns': ['title', 'author.name'],
      },
      'relations': [
        {'relation': 'author', 'filter': null, 'nested': <Object?>[]},
        {'relation': 'labels', 'filter': null, 'nested': <Object?>[]},
      ],
      'pagination': {'page': 2, 'perPage': 10},
      'withTrashed': false,
    },
    '/api/notes/aggregate': {
      'table': 'notes',
      'function': 'sum',
      'column': 'rating',
      'filter': {
        'type': 'field',
        'column': 'rating',
        'operator': 'between',
        'value': [1, 5],
      },
      'withTrashed': false,
    },
    '/api/notes/summary': {
      'table': 'notes',
      'groupBy': 'status',
      'measures': [
        {'key': 'n', 'column': null},
        {
          'key': 's',
          'column': 'rating',
          'filter': {
            'type': 'field',
            'column': 'published',
            'operator': 'eq',
            'value': true,
          },
        },
      ],
      'filter': null,
      'search': {
        'term': 'x',
        'columns': ['title'],
      },
      'limit': 100,
      'withTrashed': false,
    },
  };

  const iterations = 600;
  final postgresUrl = Platform.environment['BEAK_FUZZ_DATABASE_URL'];

  for (final kind in [
    'in-memory',
    'sqlite',
    if (postgresUrl != null) 'postgres',
  ]) {
    group(kind, () {
      late DatabaseAdapter adapter;
      late Handler handler;
      final unexpected = <Object>[];

      setUp(() async {
        Worm.seedRandom(42);
        final registry = createApiRegistry();
        switch (kind) {
          case 'sqlite':
            final sqlite = SqliteAdapter.memory();
            await sqlite.connect();
            for (final descriptor in apiSchema) {
              await sqlite.executeSchema(
                SchemaDescriptor.createTable(
                  table: descriptor.table,
                  columns: [
                    for (final column in descriptor.columns)
                      SchemaColumn(
                        name: column.name,
                        type: column.type,
                        isPrimaryKey: column.isPrimaryKey,
                        nullable: !column.isPrimaryKey,
                      ),
                  ],
                ),
              );
            }
            adapter = sqlite;
          case 'postgres':
            adapter = adapterFromUrl(Uri.parse(postgresUrl!));
            await adapter.connect();
            for (final table in apiSchema.map((s) => s.table)) {
              await adapter.rawExecute('DROP TABLE IF EXISTS $table', const []);
            }
            for (final statement in _postgresSchema) {
              await adapter.rawExecute(statement, const []);
            }
          default:
            adapter = await createApiTestDatabase();
        }
        if (kind != 'in-memory') {
          await Worm.initialize(
            config: const WormConfig(),
            adapters: <String, DatabaseAdapter>{'default': adapter},
          );
        }
        handler = const Pipeline()
            .addMiddleware(beakJsonMiddleware())
            .addMiddleware(
              beakErrorMappingMiddleware(
                onUnexpectedError: (error, stack) => unexpected.add(error),
              ),
            )
            .addHandler(
              beakApiRouter(
                registry: registry,
                dataSource: WormDataSource(registry, adapter: adapter),
              ),
            );
        Future<void> post(String path, Map<String, Object?> body) async {
          await handler(
            Request(
              'POST',
              Uri.parse('http://localhost$path'),
              body: jsonEncode(body),
            ),
          );
        }

        await post('/api/authors', {'id': 'a1', 'name': 'Ann'});
        await post('/api/notes', {
          'id': 'n1',
          'title': 'First x',
          'rating': 3,
          'status': 'draft',
          'published': true,
          'author_id': 'a1',
        });
        unexpected.clear();
      });

      tearDown(() async {
        if (kind == 'postgres') {
          for (final table in apiSchema.map((s) => s.table)) {
            await adapter.rawExecute('DROP TABLE IF EXISTS $table', const []);
          }
        }
        await Worm.reset();
        if (kind != 'in-memory') await adapter.disconnect();
      });

      for (final MapEntry(key: path, value: document) in documents.entries) {
        test('$path never answers a 500 for a mangled spec', () async {
          final random = Random(20260930);
          for (var i = 0; i < iterations; i++) {
            final mutated = mutateJson(document, random);
            final response = await handler(
              Request(
                'POST',
                Uri.parse('http://localhost$path'),
                body: jsonEncode(mutated),
              ),
            );
            final body = await response.readAsString();
            expect(
              response.statusCode,
              anyOf(200, 401, 403, 404, 409, 413, 422),
              reason: '${jsonEncode(mutated)} -> $body ($unexpected)',
            );
          }
        });
      }
    });
  }
}

const _postgresSchema = [
  'CREATE TABLE notes (id text PRIMARY KEY, title text, body text, '
      'rating integer, status text, published boolean, author_email text, '
      'author_id text, created_at timestamptz, updated_at timestamptz, '
      'avatar text, attachment text, deleted_at timestamptz)',
  'CREATE TABLE labels (id text PRIMARY KEY, name text)',
  'CREATE TABLE note_label (note_id text, label_id text)',
  'CREATE TABLE comments (id text PRIMARY KEY, note_id text, message text)',
  'CREATE TABLE authors (id text PRIMARY KEY, name text)',
];
