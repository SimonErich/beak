/// Verifies that the fluent QueryBuilder produces correct
/// descriptors for at least 15 distinct query shapes via golden
/// snapshots checked in under `test/goldens/qb/`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_descriptor.dart';

import '_fixtures.dart';

const _encoder = JsonEncoder.withIndent('  ');

/// Compare the fluent-builder produced [descriptor] against a
/// checked-in `.golden` file under `test/goldens/qb/`.
///
/// Set `UPDATE_GOLDENS=true` to regenerate locally.
void _expectGolden(String name, QueryDescriptor descriptor) {
  final json = _encoder.convert(descriptor.toMap());
  final file = File('test/goldens/qb/$name.golden');
  final update = Platform.environment['UPDATE_GOLDENS'] == 'true';
  if (update || !file.existsSync()) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$json\n');
  }
  final expected = file.readAsStringSync().trimRight();
  expect(json, equals(expected));
}

QueryBuilder<TestUser> _builder() {
  final adapter = InMemoryAdapter();
  return QueryBuilder<TestUser>.from(userContext(adapter));
}

const _name = StringField('name');
const _age = ComparableField<int>('age');
const _userId = ComparableField<int>('id');
const _role = StringField('role');

void main() {
  group('Fluent QueryBuilder descriptors (golden snapshots)', () {
    test('01_plain_select_all', () {
      _expectGolden('01_plain_select_all', _builder().descriptor);
    });

    test('02_where_eq', () {
      final qb = _builder().where(_name.eq('Alice'));
      _expectGolden('02_where_eq', qb.descriptor);
    });

    test('03_where_gte', () {
      final qb = _builder().where(_age.gte(18));
      _expectGolden('03_where_gte', qb.descriptor);
    });

    test('04_where_and_chain', () {
      final qb = _builder().where(_age.gte(18)).where(_name.eq('Alice'));
      _expectGolden('04_where_and_chain', qb.descriptor);
    });

    test('05_or_where', () {
      final qb = _builder().where(_name.eq('Alice')).orWhere(_name.eq('Bob'));
      _expectGolden('05_or_where', qb.descriptor);
    });

    test('06_in_list', () {
      final qb = _builder().where(_userId.inList(<int>[1, 2, 3]));
      _expectGolden('06_in_list', qb.descriptor);
    });

    test('07_between', () {
      final qb = _builder().where(_age.between(18, 65));
      _expectGolden('07_between', qb.descriptor);
    });

    test('08_string_contains', () {
      final qb = _builder().where(_name.contains('al'));
      _expectGolden('08_string_contains', qb.descriptor);
    });

    test('09_starts_with', () {
      final qb = _builder().where(_name.startsWith('Al'));
      _expectGolden('09_starts_with', qb.descriptor);
    });

    test('10_is_null', () {
      final qb = _builder().where(const Field<Object?>('deleted_at').isNull());
      _expectGolden('10_is_null', qb.descriptor);
    });

    test('11_not_predicate', () {
      final qb = _builder().where(_age.gte(18).not());
      _expectGolden('11_not_predicate', qb.descriptor);
    });

    test('12_grouped_or_and', () {
      final group = _name.eq('Alice').or(_name.eq('Bob')).group();
      final qb = _builder().where(group).where(_age.gte(18));
      _expectGolden('12_grouped_or_and', qb.descriptor);
    });

    test('13_order_by_desc', () {
      final qb = _builder().orderBy(_age, descending: true);
      _expectGolden('13_order_by_desc', qb.descriptor);
    });

    test('14_limit_offset', () {
      final qb = _builder().limit(10).offset(20);
      _expectGolden('14_limit_offset', qb.descriptor);
    });

    test('15_select_distinct', () {
      final qb = _builder().select(const <Field<Object?>>[
        Field<Object?>('name'),
        Field<Object?>('age'),
      ]).distinct();
      _expectGolden('15_select_distinct', qb.descriptor);
    });

    test('16_composite_pipeline', () {
      final qb = _builder()
          .where(_age.gte(18))
          .where(_role.eq('admin'))
          .orderBy(_age, descending: true)
          .limit(5)
          .offset(10)
          .distinct();
      _expectGolden('16_composite_pipeline', qb.descriptor);
    });

    test('17_not_in_list', () {
      final qb = _builder().where(_userId.notInList(<int>[7, 8]));
      _expectGolden('17_not_in_list', qb.descriptor);
    });
  });
}
