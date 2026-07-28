/// The version comparison the SQLite feature gates are decided by.
///
/// It exists as a named function precisely so this can pin it down: text
/// ordering sorts `3.9.0` above `3.35.0` and would wave a decade-old library
/// straight past the 3.35 floor for `DROP COLUMN`.
library;

import 'package:test/test.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

void main() {
  test('a multi-digit component compares as a number, not as text', () {
    expect(sqliteVersionAtLeast('3.9.0', minimum: '3.35'), isFalse);
    expect(sqliteVersionAtLeast('3.34.9', minimum: '3.35'), isFalse);
    expect(sqliteVersionAtLeast('3.35.0', minimum: '3.35'), isTrue);
    expect(sqliteVersionAtLeast('3.45.1', minimum: '3.35'), isTrue);
    expect(sqliteVersionAtLeast('3.100.0', minimum: '3.35'), isTrue);
  });

  test('a higher major wins regardless of the minor', () {
    expect(sqliteVersionAtLeast('4.0.0', minimum: '3.35'), isTrue);
    expect(sqliteVersionAtLeast('10.2.0', minimum: '3.35'), isTrue);
    expect(sqliteVersionAtLeast('2.99.99', minimum: '3.35'), isFalse);
  });

  test('a component the minimum declares and the version omits is zero', () {
    expect(sqliteVersionAtLeast('3.35', minimum: '3.35.0'), isTrue);
    expect(sqliteVersionAtLeast('3.35', minimum: '3.35.1'), isFalse);
  });

  test('an unreadable version fails the check rather than passing it', () {
    expect(sqliteVersionAtLeast('', minimum: '3.35'), isFalse);
    expect(sqliteVersionAtLeast('unknown', minimum: '3.35'), isFalse);
  });
}
