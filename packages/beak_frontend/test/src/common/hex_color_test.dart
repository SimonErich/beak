import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses hex strings with and without the leading hash', () {
    expect(parseBeakHexColor('#663399'), const Color(0xFF663399));
    expect(parseBeakHexColor('663399'), const Color(0xFF663399));
  });

  test('rejects malformed input', () {
    expect(parseBeakHexColor('#66339'), isNull);
    expect(parseBeakHexColor('#zzzzzz'), isNull);
    expect(parseBeakHexColor(''), isNull);
  });

  test('formats a color as lowercase #rrggbb, dropping alpha', () {
    expect(formatBeakHexColor(const Color(0xFF663399)), '#663399');
    expect(formatBeakHexColor(const Color(0x80000ABC)), '#000abc');
  });

  test('round-trips through parse and format', () {
    expect(
      formatBeakHexColor(
        parseBeakHexColor('#a1b2c3') ?? const Color(0x00000000),
      ),
      '#a1b2c3',
    );
  });
}
