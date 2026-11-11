import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => BeakLabels.language = null);

  BeakRecord record() => BeakRecord(
    values: const {'id': BeakStringValue('1')},
    relations: {
      'translations': [
        BeakRecord.fromRow({'locale': 'en', 'name': 'Drinks'}),
        BeakRecord.fromRow({'locale': 'de', 'name': 'Getränke'}),
      ],
    },
  );

  test('picks the panel language from the translation rows', () {
    const display = BeakTranslationDisplay(
      relationKey: 'translations',
      columnKey: 'name',
    );
    BeakLabels.language = 'de';

    expect(display.labelOf(record()), 'Getränke');
  });

  test('falls back to the first translation for a missing language', () {
    const display = BeakTranslationDisplay(
      relationKey: 'translations',
      columnKey: 'name',
    );
    BeakLabels.language = 'fr';

    expect(display.labelOf(record()), 'Drinks');
  });

  test('is empty without loaded translations', () {
    const display = BeakTranslationDisplay(
      relationKey: 'translations',
      columnKey: 'name',
    );

    expect(display.labelOf(const BeakRecord(values: {})), '');
  });
}
