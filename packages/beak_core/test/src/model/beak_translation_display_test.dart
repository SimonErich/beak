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

  test('a model reads its display column without a translation display', () {
    final record = BeakRecord.fromRow({'name': 'Plain'});

    expect(const _PlainModel().displayValueOf(record), 'Plain');
    expect(
      const _PlainModel().displayValueOf(const BeakRecord(values: {})),
      '',
    );
  });

  test('a model with a translation display reads it instead of the column', () {
    BeakLabels.language = 'de';

    expect(
      const _DisplayModel(
        translation: BeakTranslationDisplay(
          relationKey: 'translations',
          columnKey: 'name',
        ),
      ).displayValueOf(record()),
      'Getränke',
    );
  });

  test('is empty without loaded translations', () {
    const display = BeakTranslationDisplay(
      relationKey: 'translations',
      columnKey: 'name',
    );

    expect(display.labelOf(const BeakRecord(values: {})), '');
  });
}

final class _PlainModel extends BeakModel {
  const _PlainModel();

  @override
  String get table => 'plain_model';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [];
}

final class _DisplayModel extends BeakModel {
  const _DisplayModel({this.translation});

  final BeakTranslationDisplay? translation;

  @override
  String get table => 'display_model';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [];

  @override
  BeakTranslationDisplay? get translationDisplay => translation;
}
