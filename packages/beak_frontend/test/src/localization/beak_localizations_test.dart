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
