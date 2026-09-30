import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  // --8<-- [start:dateInputPolicyTest]
  test('date input pattern defaults and explicit policy JSON roundtrip', () {
    const inherited = BeakFormatPolicy(datePattern: 'dd.MM.yyyy');
    expect(inherited.dateInputPattern, inherited.datePattern);
    final legacy = BeakFormatPolicy.fromJson({'datePattern': 'd MMM yyyy'});
    expect(legacy.dateInputPattern, 'd MMM yyyy');
    const separate = BeakFormatPolicy(
      locale: 'de_AT',
      datePattern: 'EEE d MMM',
      dateInputPattern: 'd MMMM yyyy',
    );
    final decoded = BeakFormatPolicy.fromJson(separate.toJson());
    expect(decoded.dateInputPattern, 'd MMMM yyyy');
    expect(decoded.datePattern, 'EEE d MMM');
    expect(decoded.toJson(), separate.toJson());
    expect(
      () => BeakFormatPolicy.fromJson({'dateInputPattern': 3}),
      throwsFormatException,
    );
  });
  // --8<-- [end:dateInputPolicyTest]

  test(
    'exact decimal localization uses the same numeral and sign conventions as numbers',
    () {
      for (final locale in ['en_US', 'de_DE', 'fa']) {
        final policy = BeakFormatPolicy(locale: locale);
        expect(
          policy.exactCurrency(BeakDecimal.parse('-12.34')),
          policy.currency(-12.34),
          reason: locale,
        );
        expect(
          policy.exactDecimal(BeakDecimal.parse('-12.34')),
          policy.number(-12.34, precision: 2),
          reason: locale,
        );
      }
    },
  );

  const policy = BeakFormatPolicy(
    locale: 'de_AT',
    currency: 'EUR',
    datePattern: 'dd.MM.yyyy',
    useLocalTime: false,
    emptyValue: '(empty)',
  );

  test(
    'exact money formatting retains every unit at the precision boundary',
    () {
      const currency = BeakStringColumn(key: 'currency', label: 'Currency');
      const amount = BeakIntColumn(
        key: 'amount',
        label: 'Amount',
        semantic: BeakSemantic.money(scale: 3, currencyColumn: currency),
      );
      final row = BeakRecord.fromRow({
        'amount': 9007199254740991,
        'currency': 'EUR',
      });
      expect(
        policy.formatColumn(amount, row),
        '€\u00a09\u00a0007\u00a0199\u00a0254\u00a0740,991',
      );
      expect(
        policy.exactDecimal(BeakDecimal.parse('-0.001', scale: 3)),
        '-0,001',
      );
    },
  );

  test('calendar values ignore timestamp timezone display preferences', () {
    const date = BeakStringColumn(
      key: 'date',
      label: 'Date',
      semantic: BeakSemantic.calendarDate(),
    );
    expect(
      policy.formatColumn(date, BeakRecord.fromRow({'date': '2026-02-28'})),
      '28.02.2026',
    );
    expect(policy.formatColumn(date, const BeakRecord(values: {})), '(empty)');
  });

  // --8<-- [start:portablePolicyTest]
  test(
    'serialized display policy uses explicit offset, never server local timezone',
    () {
      const original = BeakFormatPolicy(
        locale: 'en_US',
        timeZoneOffsetMinutes: 120,
        dateTimePattern: 'yyyy-MM-dd HH:mm',
      );
      final decoded = BeakFormatPolicy.fromJson(original.toJson());
      expect(
        decoded.dateTime(DateTime.utc(2026, 1, 1, 23)),
        '2026-01-02 01:00',
      );
      expect(decoded.useLocalTime, isFalse);
      expect(decoded.toJson(), original.toJson());
    },
  );
  // --8<-- [end:portablePolicyTest]

  test('semantic percentages, units and passwords share display behavior', () {
    const percent = BeakDecimalColumn(
      key: 'rate',
      label: 'Rate',
      semantic: BeakSemantic.percentage(scale: 100),
    );
    const secret = BeakStringColumn(
      key: 'secret',
      label: 'Secret',
      semantic: BeakSemantic.password(),
    );
    final row = BeakRecord.fromRow({'rate': 19, 'secret': 'never export me'});
    expect(policy.formatColumn(percent, row), '19\u00a0%');
    expect(policy.formatColumn(secret, row), '••••••••');
  });
}
