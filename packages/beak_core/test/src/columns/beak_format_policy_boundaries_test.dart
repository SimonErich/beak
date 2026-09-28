import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

enum _State { draft, sent }

void main() {
  const us = BeakFormatPolicy(useLocalTime: false);
  const german = BeakFormatPolicy(
    locale: 'de_DE',
    currency: 'EUR',
    useGrouping: false,
    currencyPrecision: 3,
  );
  String cell(
    BeakColumn column,
    Object? value, {
    BeakFormatPolicy policy = us,
  }) => policy.formatCell(column, BeakRecord.fromRow({column.key: value}));

  test('calendar and elapsed values stay independent of timestamp offsets', () {
    const offset = BeakFormatPolicy(timeZoneOffsetMinutes: 120);
    expect(us.dateTime(DateTime.utc(2026, 9, 27, 12)), '2026-09-27 12:00');
    expect(offset.calendarDate(const BeakDate(2026, 9, 27)), '2026-09-27');
    expect(offset.clockTime(const BeakTime(23, 59)), '23:59');
    expect(offset.dateTime(DateTime.utc(2026, 9, 27, 23)), '2026-09-28 01:00');
    expect(us.date(DateTime.utc(2026, 9, 27, 23)), '2026-09-27');
    expect(us.time(DateTime.utc(2026, 9, 27, 23)), '23:00');
    expect(
      offset.format(DateTime.utc(2026, 9, 27, 23), BeakValueFormat.time),
      '01:00',
    );
    expect(
      offset.format('2026-09-27T23:00:00Z', BeakValueFormat.time),
      '01:00',
    );
    expect(
      offset.format(const BeakTime(23, 59), BeakValueFormat.time),
      '23:59',
    );
    final local = DateTime(2026, 9, 27, 12);
    expect(const BeakFormatPolicy().dateTime(local), '2026-09-27 12:00');
    expect(
      us.duration(const Duration(hours: 27, minutes: 2, seconds: 3)),
      '27:02:03',
    );
    expect(
      us.duration(const Duration(microseconds: -1000001)),
      '-00:00:01.000001',
    );
    expect(us.fileSize(23), '23 B');
    expect(us.fileSize(1536), '1.50 KiB');
  });
  test(
    'locale parsing, grouping, currencies and calculated formats are consistent',
    () {
      expect(us.number(1234.5), '1,234.50');
      expect(german.number(1234.5), '1234,50');
      expect(us.number(1234, grouping: false), '1234');
      expect(us.currency(1234.5), r'$1,234.50');
      expect(us.currency(1, symbol: 'X', precision: 0), 'X1');
      expect(german.currency(1, symbol: 'X'), contains('1,000'));
      expect(german.currency(1234.5), contains('1234,500'));
      expect(us.currencySymbol, r'$');
      expect(german.decimalSeparator, ',');
      expect(german.groupingSeparator, '.');
      expect(us.moneyPrecision, 2);
      expect(german.moneyPrecision, 3);
      expect(const BeakFormatPolicy(currency: 'JPY').moneyPrecision, 0);
      expect(german.parseNumber(' 1.234,50 '), 1234.5);
      expect(us.parseNumber('-1,234.5'), -1234.5);
      for (final malformed in ['1.2.3', 'word', '1.x', '1,23', ',,,', '']) {
        expect(us.parseNumber(malformed), isNull, reason: malformed);
      }
      expect(us.percent(0.125), '12.5%');
      expect(german.percent(10), '1000 %');
      expect(us.format(null, BeakValueFormat.text), '—');
      expect(us.format(1234, BeakValueFormat.number), '1,234');
      expect(us.format('1.5', BeakValueFormat.currency), r'$1.50');
      expect(
        us.format('2026-09-27T12:00:00Z', BeakValueFormat.date),
        '2026-09-27',
      );
      expect(
        us.format(DateTime.utc(2026, 9, 27, 12), BeakValueFormat.dateTime),
        '2026-09-27 12:00',
      );
      expect(us.format('0.5', BeakValueFormat.percent), '50%');
      expect(us.format(true, BeakValueFormat.number), 'true');
      expect(us.format(const BeakDecimal(123), BeakValueFormat.text), '1.23');
      expect(us.format(const BeakDecimal(123), BeakValueFormat.number), '1.23');
      expect(
        us.format(const BeakDecimal(123), BeakValueFormat.currency),
        r'$1.23',
      );
      expect(
        us.format(const BeakDate(2026, 9, 27), BeakValueFormat.date),
        '2026-09-27',
      );
      expect(us.format('not a date', BeakValueFormat.date), 'not a date');
      expect(us.exactDecimal(const BeakDecimal(-123456)), '-1,234.56');
      expect(us.exactDecimal(const BeakDecimal(123, scale: 0)), '123');
      expect(
        german.exactCurrency(const BeakDecimal(-123), symbol: 'X'),
        contains('1,23'),
      );
    },
  );
  test(
    'every physical cell kind formats typed values and safe malformed fallbacks',
    () {
      final instant = DateTime.utc(2026, 9, 27, 12, 30);
      for (final (format, expected) in <(BeakDateFormat, String)>[
        (BeakDateFormat.dateOnly, '2026-09-27'),
        (BeakDateFormat.timeOnly, '12:30'),
        (BeakDateFormat.iso, instant.toIso8601String()),
        (BeakDateFormat.standard, '2026-09-27 12:30'),
      ]) {
        expect(
          cell(
            BeakDateTimeColumn(key: 'v', label: 'V', format: format),
            instant,
          ),
          expected,
        );
      }
      expect(
        cell(const BeakDateTimeColumn(key: 'v', label: 'V'), 'bad-date'),
        'bad-date',
      );
      expect(
        cell(const BeakDecimalColumn(key: 'v', label: 'V'), 1234.5),
        '1,234.50',
      );
      expect(
        cell(
          const BeakDecimalColumn(
            key: 'v',
            label: 'V',
            prefix: '€',
            suffix: '/kg',
          ),
          1.5,
        ),
        '€1.50/kg',
      );
      expect(
        cell(const BeakDecimalColumn(key: 'v', label: 'V'), 'bad-number'),
        'bad-number',
      );
      expect(
        cell(
          const BeakIntColumn(key: 'v', label: 'V', prefix: '+', suffix: 'kg'),
          1234,
        ),
        '+1,234kg',
      );
      expect(
        cell(const BeakIntColumn(key: 'v', label: 'V'), 'bad-int'),
        'bad-int',
      );
      expect(cell(const BeakBoolColumn(key: 'v', label: 'V'), true), 'Yes');
      expect(cell(const BeakBoolColumn(key: 'v', label: 'V'), false), 'No');
      expect(
        cell(
          const BeakBoolColumn(
            key: 'v',
            label: 'V',
            trueLabel: 'Enabled',
            falseLabel: 'Disabled',
          ),
          true,
        ),
        'Enabled',
      );
      expect(cell(const BeakBoolColumn(key: 'v', label: 'V'), 'bad-bool'), '—');
      const states = BeakEnumColumn<_State>(
        key: 'v',
        label: 'V',
        values: _State.values,
      );
      expect(cell(states, 'draft'), 'draft');
      expect(cell(states, 'unknown'), 'unknown');
      expect(
        cell(const BeakStringColumn(key: 'v', label: 'V'), 'plain'),
        'plain',
      );
      expect(cell(const BeakStringColumn(key: 'v', label: 'V'), null), '—');
    },
  );
  test(
    'semantic cells reuse one policy for physical storage representations',
    () {
      for (final (semantic, raw, expected) in <(BeakSemantic, Object, String)>[
        (const BeakSemantic.calendarDate(), '2026-09-27', '2026-09-27'),
        (const BeakSemantic.time(), '09:30:00', '09:30'),
        (const BeakSemantic.duration(), 60000000, '00:01:00'),
        (const BeakSemantic.exactDecimal(), 1234, '12.34'),
        (const BeakSemantic.money(currency: 'EUR'), 1234, '€12.34'),
        (const BeakSemantic.percentage(), 12.5, '12.5%'),
        (const BeakSemantic.quantity(unit: 'kg'), 12, '12 kg'),
        (const BeakSemantic.quantity(), 12, '12'),
        (const BeakSemantic.fileSize(), 1024, '1.00 KiB'),
        (
          const BeakSemantic.list(BeakPrimitiveType.string),
          '["a","b"]',
          'a, b',
        ),
        (
          const BeakSemantic.object(BeakObjectSchema(columns: [])),
          '{"a":1}',
          '{"a":1}',
        ),
        (const BeakSemantic.email(), 'a@example.com', 'a@example.com'),
        (const BeakSemantic.password(), 'secret', '••••••••'),
        (const BeakSemantic.calendarDate(), 'bad-date', 'bad-date'),
      ]) {
        expect(
          cell(BeakStringColumn(key: 'v', label: 'V', semantic: semantic), raw),
          expected,
        );
      }
    },
  );
  test('portable policy rejects malformed types and invalid bounds', () {
    final roundTrip = BeakFormatPolicy.fromJson(german.toJson());
    expect(roundTrip.currencyCode, 'EUR');
    expect(roundTrip.useLocalTime, isFalse);
    expect(BeakFormatPolicy.fromJson({}).numberPrecision, 2);
    for (final malformed in <Map<String, Object?>>[
      {'locale': 1},
      {'locale': 'not_A_LOCALE'},
      {'currencyPrecision': '2'},
      {'numberPrecision': -1},
      {'numberPrecision': 13},
      {'currencyPrecision': -1},
      {'currencyPrecision': 13},
      {'timeZoneOffsetMinutes': 1441},
      {'useGrouping': 'yes'},
    ]) {
      expect(() => BeakFormatPolicy.fromJson(malformed), throwsFormatException);
    }
  });
}
