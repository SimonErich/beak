import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('Unique', () {
    late InMemoryAdapter adapter;

    setUp(() async {
      adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      await adapter.insert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{'id': 'u-1', 'email': 'taken@example.com'},
        ),
      );
    });

    test('accepts unused value', () async {
      final rule = Unique(adapter: adapter, table: 'users', column: 'email');
      final result = await rule.validate('free@example.com');
      expect(result.isValid, isTrue);
    });

    test('rejects duplicate value', () async {
      final rule = Unique(adapter: adapter, table: 'users', column: 'email');
      final result = await rule.validate('taken@example.com');
      expect(result.isInvalid, isTrue);
      expect(result.message, contains('email'));
    });

    test('excludes current model on update', () async {
      final rule = Unique(
        adapter: adapter,
        table: 'users',
        column: 'email',
        exceptId: 'u-1',
      );
      final result = await rule.validate('taken@example.com');
      expect(result.isValid, isTrue);
    });

    test('still rejects when another row owns the value', () async {
      await adapter.insert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{'id': 'u-2', 'email': 'other@example.com'},
        ),
      );
      final rule = Unique(
        adapter: adapter,
        table: 'users',
        column: 'email',
        exceptId: 'u-1',
      );
      final result = await rule.validate('other@example.com');
      expect(result.isInvalid, isTrue);
    });

    test('passes null without querying', () async {
      final rule = Unique(adapter: adapter, table: 'users', column: 'email');
      final result = await rule.validate(null);
      expect(result.isValid, isTrue);
    });
  });

  group('ValidationException.fromUniqueConstraint', () {
    test('builds aggregated error map', () {
      const violation = UniqueConstraintException(
        table: 'users',
        column: 'email',
        message: 'duplicate key',
      );
      final mapped = ValidationException.fromUniqueConstraint(violation);
      expect(mapped.errors['email'], isNotNull);
      expect(mapped.errors['email']!.first, contains('email'));
    });

    test('respects override message', () {
      const violation = UniqueConstraintException(
        table: 'users',
        column: 'email',
        message: 'dup',
      );
      final mapped = ValidationException.fromUniqueConstraint(
        violation,
        message: 'Pick another email.',
      );
      expect(mapped.errors['email'], <String>['Pick another email.']);
    });

    test('produces the exact AC errors shape with default message', () {
      const violation = UniqueConstraintException(
        table: 'users',
        column: 'email',
        message: '',
      );
      final mapped = ValidationException.fromUniqueConstraint(violation);
      expect(mapped.errors, <String, List<String>>{
        'email': <String>['The email has already been taken.'],
      });
    });
  });
}
