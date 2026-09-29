import 'package:test/test.dart';

import '../support/beak_cli_internals.dart';

void main() {
  group('pluralOf', () {
    test('appends s, and es after a sibilant', () {
      expect(pluralOf('Product'), 'Products');
      expect(pluralOf('Box'), 'Boxes');
      expect(pluralOf('Class'), 'Classes');
      expect(pluralOf('Batch'), 'Batches');
      expect(pluralOf('dish'), 'dishes');
      expect(pluralOf('buzz'), 'buzzes');
    });

    test('turns a consonant and y into ies', () {
      expect(pluralOf('Category'), 'Categories');
      expect(pluralOf('company'), 'companies');
    });

    test('keeps the y after a vowel', () {
      expect(pluralOf('Day'), 'Days');
      expect(pluralOf('Key'), 'Keys');
      expect(pluralOf('boy'), 'boys');
      expect(pluralOf('gateway'), 'gateways');
      expect(pluralOf('survey'), 'surveys');
    });

    test('knows the irregular plurals a table is likely to need', () {
      expect(pluralOf('Person'), 'People');
      expect(pluralOf('person'), 'people');
      expect(pluralOf('man'), 'men');
      expect(pluralOf('Woman'), 'Women');
      expect(pluralOf('Child'), 'Children');
      expect(pluralOf('quiz'), 'quizzes');
    });

    test('leaves a word that has no plural alone', () {
      expect(pluralOf('Staff'), 'Staff');
      expect(pluralOf('equipment'), 'equipment');
      expect(pluralOf('Media'), 'Media');
      expect(pluralOf('series'), 'series');
    });

    test('inflects only the last word of a compound name', () {
      expect(pluralOf('sales_person'), 'sales_people');
      expect(pluralOf('OrderPerson'), 'OrderPeople');
      expect(pluralOf('order_key'), 'order_keys');
      expect(pluralOf('personal_note'), 'personal_notes');
    });

    test('does not mistake a word that merely ends in an irregular one', () {
      expect(pluralOf('human'), 'humans');
      expect(pluralOf('german'), 'germans');
      expect(pluralOf('ox_cart'), 'ox_carts');
    });
  });

  group('tableNameOf', () {
    test('snake-cases, then pluralises the last word', () {
      expect(tableNameOf('OrderItem'), 'order_items');
      expect(tableNameOf('Person'), 'people');
      expect(tableNameOf('SalesPerson'), 'sales_people');
      expect(tableNameOf('Day'), 'days');
      expect(tableNameOf('Key'), 'keys');
      expect(tableNameOf('Category'), 'categories');
    });
  });

  group('singularOf', () {
    test('undoes every regular plural pluralOf makes', () {
      for (final word in const [
        'product',
        'box',
        'class',
        'batch',
        'dish',
        'category',
        'day',
        'key',
        'order_item',
      ]) {
        expect(singularOf(pluralOf(word)), word, reason: word);
      }
    });

    test('undoes the irregular plurals', () {
      expect(singularOf('people'), 'person');
      expect(singularOf('sales_people'), 'sales_person');
      expect(singularOf('children'), 'child');
      expect(singularOf('quizzes'), 'quiz');
      expect(singularOf('staff'), 'staff');
    });

    test('leaves a singular that ends in s alone', () {
      expect(singularOf('status'), 'status');
      expect(singularOf('address'), 'address');
      expect(singularOf('analysis'), 'analysis');
      expect(singularOf('statuses'), 'status');
    });
  });
}
