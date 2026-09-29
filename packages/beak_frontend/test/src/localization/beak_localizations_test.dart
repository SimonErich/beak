import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/src/localization/beak_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('translates labels and rule failures without changing validity', () {
    const en = BeakLocalizations(Locale('en'));
    const de = BeakLocalizations(Locale('de', 'AT'));
    expect(en.save, 'Save');
    expect(en.editTitle('Categories'), 'Edit Categories');
    expect(de.editTitle('Kategorien'), 'Kategorien bearbeiten');
    expect(en.editTitle('Categories', 'old-id'), 'Edit Categories · old-id');
    expect(de.save, 'Speichern');
    expect(
      de.validate(const BeakRequired(), ''),
      'Dieses Feld ist erforderlich.',
    );
    expect(
      de.validate(const BeakMinLength(3), 'a'),
      'Mindestens 3 Zeichen erforderlich.',
    );
    expect(de.validate(const BeakMinLength(3), 'abc'), isNull);
    expect(
      de.validate(const BeakPattern('x', message: 'Domain message'), 'y'),
      'Domain message',
    );
    expect(const BeakLocalizations(Locale('fr')).save, en.save);
  });

  test('German strings address the user formally', () {
    const de = BeakLocalizations(Locale('de'));
    expect(de.actionDenied, 'Sie haben keine Berechtigung für diese Aktion.');
    expect(de.actionDenied, isNot(contains('Du ')));
  });

  test(
    'infrastructure failures show the generic text, never their message',
    () {
      const en = BeakLocalizations.english;
      const secret = 'postgres://admin:hunter2@db/internal';
      for (final BeakException error in const [
        BeakConfigurationException(secret),
        BeakStorageException(secret),
        BeakInternalException(secret),
        BeakTransportException(secret),
      ]) {
        expect(en.errorMessage(error), en.operationFailed);
      }
      expect(
        en.errorMessage(const BeakPayloadTooLargeException('Body too large.')),
        'Body too large.',
      );
      expect(
        en.errorMessage(const BeakValidationException('Fix the title.')),
        'Fix the title.',
      );
    },
  );

  testWidgets('resolves context language without requiring the delegate', (
    tester,
  ) async {
    late BeakLocalizations strings;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('de'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            strings = BeakLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(strings.retry, 'Erneut versuchen');
    expect(
      await BeakLocalizations.delegate.load(const Locale('en')),
      isA<BeakLocalizations>(),
    );
  });
}
