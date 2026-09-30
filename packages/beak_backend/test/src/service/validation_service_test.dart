import 'package:beak_backend/src/service/validation_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/api_models.dart';

void main() {
  const model = NoteModel();
  const validation = ValidationService();

  Map<String, List<String>> errorsOf(
    BeakRecord input, {
    required bool isCreate,
  }) {
    try {
      validation.validate(model, input, isCreate: isCreate);
    } on BeakValidationException catch (exception) {
      return exception.fieldErrors;
    }
    fail('expected a BeakValidationException');
  }

  BeakRecord record(Map<String, Object?> row) => BeakRecord.fromRow(row);

  group('create', () {
    test('accepts a fully valid record', () {
      expect(
        () => validation.validate(
          model,
          record({
            'title': 'Grocery run',
            'rating': 4,
            'status': 'draft',
            'published': false,
            'author_email': 'cat@example.com',
          }),
          isCreate: true,
        ),
        returnsNormally,
      );
    });

    test('a missing required column fails on create', () {
      final errors = errorsOf(record({'rating': 3}), isCreate: true);
      expect(errors, {
        'title': ['This field is required.'],
      });
    });

    test('an explicit null also fails the required rule', () {
      final errors = errorsOf(
        record({'title': null, 'rating': 3}),
        isCreate: true,
      );
      expect(errors.keys, ['title']);
    });

    test('rule violations aggregate per column', () {
      final errors = errorsOf(
        record({
          'title': 'x' * 41,
          'rating': 0,
          'author_email': 'not-an-email',
        }),
        isCreate: true,
      );
      expect(errors.keys, unorderedEquals(['title', 'rating', 'author_email']));
      expect(errors['title']?.single, contains('40'));
      expect(errors['rating']?.single, contains('1'));
    });

    test('unknown keys are rejected', () {
      final errors = errorsOf(
        record({'title': 'Ok', 'bogus': 1}),
        isCreate: true,
      );
      expect(errors.keys, ['bogus']);
      expect(errors['bogus']?.single, contains('bogus'));
    });
  });

  group('type checks', () {
    test('mistyped values fail before rules run', () {
      final errors = errorsOf(
        record({
          'title': 'Ok',
          'rating': 'five',
          'published': 'yes',
          'created_at': 17,
        }),
        isCreate: true,
      );
      expect(
        errors.keys,
        unorderedEquals(['rating', 'published', 'created_at']),
      );
      expect(errors['rating']?.single, contains('integer'));
    });

    test('a decimal column accepts integer JSON numbers', () {
      const priceModel = _PricedModel();
      expect(
        () => validation.validate(
          priceModel,
          record({'id': 'p1', 'price': 3}),
          isCreate: true,
        ),
        returnsNormally,
      );
    });

    test('an enum column only accepts declared names', () {
      final errors = errorsOf(
        record({'title': 'Ok', 'status': 'archived'}),
        isCreate: true,
      );
      expect(errors.keys, ['status']);
      expect(errors['status']?.single, contains('draft'));
    });
  });

  group('update', () {
    test('absent columns are not validated (partial semantics)', () {
      expect(
        () =>
            validation.validate(model, record({'rating': 5}), isCreate: false),
        returnsNormally,
      );
    });

    test('provided columns are still fully validated', () {
      final errors = errorsOf(record({'rating': 9}), isCreate: false);
      expect(errors.keys, ['rating']);
    });

    test('an explicit null still fails a required rule on update', () {
      final errors = errorsOf(record({'title': null}), isCreate: false);
      expect(errors.keys, ['title']);
    });
  });
}

final class _PricedModel extends BeakModel {
  const _PricedModel();

  @override
  String get table => 'priced';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakDecimalColumn(key: 'price', label: 'Price'),
  ];
}
