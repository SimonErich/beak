import 'dart:convert';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:worm_postgres/worm_postgres.dart';

UndecodedBytes _undecoded(List<int> bytes, {bool isBinary = true}) =>
    UndecodedBytes(
      typeOid: 900001,
      isBinary: isBinary,
      bytes: Uint8List.fromList(bytes),
      encoding: utf8,
    );

void main() {
  group('decodeColumnValue', () {
    test('reads the label of a native enum as text', () {
      expect(
        decodeColumnValue(_undecoded(utf8.encode('published'))),
        'published',
      );
    });

    test('reads the same payload in the text format', () {
      expect(
        decodeColumnValue(_undecoded(utf8.encode('draft'), isBinary: false)),
        'draft',
      );
    });

    test('keeps non-ASCII text intact', () {
      expect(decodeColumnValue(_undecoded(utf8.encode('Ärger'))), 'Ärger');
    });

    test('leaves a payload that is not text as its bytes', () {
      expect(
        decodeColumnValue(_undecoded(const [0xFF, 0xFE, 0x00])),
        Uint8List.fromList(const [0xFF, 0xFE, 0x00]),
      );
    });

    test('passes every value the driver already typed through', () {
      for (final value in <Object?>[
        null,
        1,
        2.5,
        'text',
        true,
        DateTime.utc(2026),
      ]) {
        expect(decodeColumnValue(value), value);
      }
    });
  });
}
