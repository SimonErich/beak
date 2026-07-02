import 'dart:convert';

import 'package:test/test.dart';
import 'package:worm/worm.dart';

enum Role { admin, editor, viewer }

enum Status { active, inactive }

final class _ReversingEncryptedCast extends EncryptedCast {
  const _ReversingEncryptedCast();

  @override
  Object encryptString(String plaintext) =>
      base64Encode(plaintext.codeUnits.reversed.toList());

  @override
  String decryptString(Object ciphertext) {
    if (ciphertext is! String) {
      throw const FormatException('ciphertext must be a String');
    }
    return String.fromCharCodes(base64Decode(ciphertext).reversed);
  }
}

void main() {
  group('DateTimeCast', () {
    const cast = DateTimeCast();
    test('null round-trip', () {
      expect(cast.decode(cast.encode(null)), isNull);
    });
    test('round-trips DateTime in UTC', () {
      final value = DateTime.utc(2026, 5, 22, 12, 30, 45);
      final encoded = cast.encode(value);
      expect(encoded, '2026-05-22T12:30:45.000Z');
      final decoded = cast.decode(encoded);
      expect(decoded, value);
    });
    test('decodes epoch millis', () {
      final value = DateTime.utc(2026);
      final ms = value.millisecondsSinceEpoch;
      expect(cast.decode(ms), value);
    });
    test('throws on garbage input', () {
      expect(() => cast.decode('not-a-date'), throwsA(isA<CastException>()));
    });
  });

  group('DecimalCast', () {
    const cast = DecimalCast();
    test('round-trips preserving precision', () {
      final value = Decimal.parse('123.456789012345678901234567890');
      final encoded = cast.encode(value);
      expect(encoded, value.value);
      expect(cast.decode(encoded), value);
    });
    test('decodes int as Decimal', () {
      expect(cast.decode(42), Decimal.parse('42'));
    });
    test('throws on garbage', () {
      expect(() => cast.decode('abc'), throwsA(isA<CastException>()));
    });
  });

  group('EnumCast', () {
    const cast = EnumCast<Role>(Role.values);
    test('round-trips by name', () {
      final encoded = cast.encode(Role.editor);
      expect(encoded, 'editor');
      expect(cast.decode(encoded), Role.editor);
    });
    test('decodes by integer index', () {
      expect(cast.decode(0), Role.admin);
    });
    test('rejects unknown name', () {
      expect(() => cast.decode('ghost'), throwsA(isA<CastException>()));
    });
  });

  group('JsonMapCast', () {
    const cast = JsonMapCast();
    test('round-trips nested map', () {
      final value = <String, Object?>{
        'a': 1,
        'b': <Object?>['x', 2, true],
        'c': <String, Object?>{'d': null},
      };
      final encoded = cast.encode(value);
      expect(encoded, isA<String>());
      expect(cast.decode(encoded), value);
    });
    test('throws on non-map input', () {
      expect(() => cast.decode(42), throwsA(isA<CastException>()));
    });
  });

  group('JsonListCast', () {
    const cast = JsonListCast();
    test('round-trips list of mixed values', () {
      final value = <Object?>[1, 'two', null, true];
      final encoded = cast.encode(value);
      expect(cast.decode(encoded), value);
    });
  });

  group('UriCast', () {
    const cast = UriCast();
    test('round-trips an absolute URL', () {
      final uri = Uri.parse('https://worm.dev/docs?x=1');
      expect(cast.decode(cast.encode(uri)), uri);
    });
  });

  group('BigIntCast', () {
    const cast = BigIntCast();
    test('round-trips beyond 2^64', () {
      final value = BigInt.parse('123456789012345678901234567890');
      expect(cast.decode(cast.encode(value)), value);
    });
  });

  group('BoolCast', () {
    const cast = BoolCast();
    test('round-trips true', () {
      expect(cast.decode(cast.encode(true)), isTrue);
    });
    test('decodes int 1', () {
      expect(cast.decode(1), isTrue);
    });
    test('decodes string false', () {
      expect(cast.decode('false'), isFalse);
    });
  });

  group('IntCast / DoubleCast / StringCast', () {
    test('IntCast accepts numeric string', () {
      expect(const IntCast().decode('123'), 123);
    });
    test('DoubleCast accepts int', () {
      expect(const DoubleCast().decode(5), 5.0);
    });
    test('StringCast coerces num', () {
      expect(const StringCast().decode(42), '42');
    });
  });

  group('CastManager', () {
    test('decodes registered fields and passes through others', () {
      final manager = CastManager(<String, AttributeCast>{
        'createdAt': const DateTimeCast(),
        'amount': const DecimalCast(),
      });
      final raw = <String, Object?>{
        'id': 'u-1',
        'createdAt': '2026-01-01T00:00:00Z',
        'amount': '10.50',
      };
      final decoded = manager.decodeAll(raw);
      expect(decoded['id'], 'u-1');
      expect(decoded['createdAt'], isA<DateTime>());
      expect(decoded['amount'], Decimal.parse('10.50'));
    });
  });

  group('Cast literal examples', () {
    test('DateTimeCast round-trips DateTime.utc(2024,1,15)', () {
      const cast = DateTimeCast();
      final value = DateTime.utc(2024, 1, 15);
      expect(cast.decode(cast.encode(value)), value);
    });

    test("IntCast.decode('42') == 42", () {
      expect(const IntCast().decode('42'), 42);
    });

    test('IntCast round-trips max int 2147483647', () {
      const cast = IntCast();
      expect(cast.decode(cast.encode(2147483647)), 2147483647);
    });

    test('BoolCast decodes 1 to true and "false" to false', () {
      const cast = BoolCast();
      expect(cast.decode(1), isTrue);
      expect(cast.decode('false'), isFalse);
    });

    test('UriCast round-trips https://example.com', () {
      const cast = UriCast();
      final uri = Uri.parse('https://example.com');
      expect(cast.decode(cast.encode(uri)), uri);
    });

    test("DecimalCast.decode('123.456').toString() == '123.456'", () {
      final decoded = const DecimalCast().decode('123.456');
      expect(decoded.toString(), '123.456');
    });

    test('EnumCast(Status.values).decode("active") == Status.active', () {
      const cast = EnumCast<Status>(Status.values);
      expect(cast.decode('active'), Status.active);
    });

    test('JsonListCast.decode([1,2,3]) returns List with [1,2,3]', () {
      const cast = JsonListCast();
      final decoded = cast.decode(<Object?>[1, 2, 3]);
      expect(decoded, isA<List<Object?>>());
      expect(decoded, <Object?>[1, 2, 3]);
    });

    test('CastException thrown for incompatible IntCast input', () {
      expect(
        () => const IntCast().decode(<Object?>[1]),
        throwsA(isA<CastException>()),
      );
    });

    test('CastManager.decodeOne returns DateTime for ISO string', () {
      final manager = CastManager(<String, AttributeCast>{
        'created_at': const DateTimeCast(),
      });
      final decoded = manager.decodeOne(
        'created_at',
        '2024-01-01T00:00:00.000Z',
      );
      expect(decoded, isA<DateTime>());
      expect(decoded, DateTime.utc(2024));
    });
  });

  group('EncryptedCast', () {
    const cast = _ReversingEncryptedCast();

    test('round-trips a plaintext string via the subclass cipher', () {
      const plaintext = 'top-secret';
      final encrypted = cast.encode(plaintext);
      expect(encrypted, isA<String>());
      expect(encrypted, isNot(equals(plaintext)));
      expect(cast.decode(encrypted), plaintext);
    });

    test('null round-trips as null', () {
      expect(cast.encode(null), isNull);
      expect(cast.decode(null), isNull);
    });

    test('encoding a non-String throws CastException', () {
      expect(() => cast.encode(42), throwsA(isA<CastException>()));
    });

    test('decode wraps cipher FormatException in CastException', () {
      expect(
        () => cast.decode(<Object?>[1, 2, 3]),
        throwsA(isA<CastException>()),
      );
    });

    test('is an AttributeCast', () {
      expect(cast, isA<AttributeCast>());
    });
  });

  group('CustomCast', () {
    final cast = CustomCast<Uri>(
      fromDb: (raw) => Uri.parse(raw! as String),
      toDb: (uri) => uri.toString(),
    );

    test('round-trips a domain value through the closures', () {
      final encoded = cast.encode(Uri.parse('https://example.com/a'));
      expect(encoded, 'https://example.com/a');
      expect(cast.decode(encoded), Uri.parse('https://example.com/a'));
    });

    test('null short-circuits both directions', () {
      expect(cast.encode(null), isNull);
      expect(cast.decode(null), isNull);
    });

    test('encode rejects a value of the wrong type', () {
      expect(() => cast.encode(42), throwsA(isA<CastException>()));
    });

    test('is an AttributeCast', () {
      expect(cast, isA<AttributeCast>());
    });
  });
}
