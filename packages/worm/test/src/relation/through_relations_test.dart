import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/relation/has_many_through.dart';
import 'package:worm/src/relation/has_one_through.dart';

T _read<T>(Map<String, Object?> row, String key, T fallback) {
  final value = row[key];
  if (value is T) return value;
  return fallback;
}

final class _Country extends Model {
  _Country({required this.countryId, required this.name});
  final int countryId;
  final String name;
  @override
  Object get id => countryId;
  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': countryId,
    'name': name,
  };
}

final class _Post extends Model {
  _Post({required this.postId, required this.userId, required this.title});
  factory _Post.fromRow(Map<String, Object?> row) => _Post(
    postId: _read<int>(row, 'id', 0),
    userId: _read<int>(row, 'user_id', 0),
    title: _read<String>(row, 'title', ''),
  );
  final int postId;
  final int userId;
  final String title;
  @override
  Object get id => postId;
  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': postId,
    'user_id': userId,
    'title': title,
  };
}

Future<InMemoryAdapter> throughAdapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'countries'),
  );
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'posts'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'countries',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'US'},
        <String, Object?>{'id': 2, 'name': 'DE'},
      ],
    ),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'users',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 10, 'country_id': 1, 'name': 'Alice'},
        <String, Object?>{'id': 11, 'country_id': 1, 'name': 'Bob'},
        <String, Object?>{'id': 12, 'country_id': 2, 'name': 'Carol'},
      ],
    ),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'posts',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 100, 'user_id': 10, 'title': 'Alice Post'},
        <String, Object?>{'id': 101, 'user_id': 11, 'title': 'Bob Post'},
        <String, Object?>{'id': 102, 'user_id': 12, 'title': 'Carol Post'},
      ],
    ),
  );
  return adapter;
}

void main() {
  group('HasManyThrough', () {
    test('loads grouped children across two FKs in 2 queries', () async {
      final adapter = await throughAdapter();
      const relation = HasManyThroughRelation<Model, Model>(
        name: 'posts',
        throughTable: 'users',
        childTable: 'posts',
        firstKey: 'country_id',
        secondKey: 'user_id',
        hydrateChild: _Post.fromRow,
      );
      final countries = <Model>[
        _Country(countryId: 1, name: 'US'),
        _Country(countryId: 2, name: 'DE'),
      ];
      final result = await relation.load(adapter, countries);
      expect(result.stats.queriesExecuted, 2);
      for (final c in countries) {
        result.setOnParent(c);
      }
      final us = countries.whereType<_Country>().firstWhere(
        (c) => c.countryId == 1,
      );
      if (us.relations['posts'] case final List<Model> list) {
        expect(list, hasLength(2));
      } else {
        fail('Expected List<Model>');
      }
    });
  });

  group('HasOneThrough', () {
    test('loads first matching child via the through table', () async {
      final adapter = await throughAdapter();
      const relation = HasOneThroughRelation<Model, Model>(
        name: 'post',
        throughTable: 'users',
        childTable: 'posts',
        firstKey: 'country_id',
        secondKey: 'user_id',
        hydrateChild: _Post.fromRow,
      );
      final countries = <Model>[_Country(countryId: 1, name: 'US')];
      final result = await relation.load(adapter, countries);
      expect(result.stats.queriesExecuted, 2);
      for (final c in countries) {
        result.setOnParent(c);
      }
      final country = countries.whereType<_Country>().first;
      expect(country.relations['post'], isA<Model>());
    });
  });
}
