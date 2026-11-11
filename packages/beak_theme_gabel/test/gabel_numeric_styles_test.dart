import 'package:beak_theme_gabel/beak_theme_gabel.dart';
import 'package:beak_theme_gabel/testing.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _width(TextStyle style, String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final result = painter.width;
  painter.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadGabelFonts);

  test('body, medium, caption and metric amounts render tabular digits', () {
    final body = GabelTheme().light.textTheme.body;
    for (final role in [
      gabelNumericBodyStyle,
      gabelNumericMediumStyle,
      gabelNumericCaptionStyle,
      gabelNumericMetricStyle,
    ]) {
      final style = body.merge(role);

      expect(
        _width(style, '€41.31'),
        closeTo(_width(style, '€48.60'), .01),
        reason: 'Every monetary role gives every digit equal width.',
      );
    }
  });

  test('monetary totals share the wide heading role with tabular digits', () {
    final style = gabelNumericTotalStyle;

    expect(style.fontSize, 22);
    expect(style.height, 28 / 22);
    expect(style.letterSpacing, -.22);
    expect(style.fontVariations, const [
      FontVariation('wght', 580),
      FontVariation('wdth', 106),
    ]);
    expect(style.fontFeatures, const [FontFeature.tabularFigures()]);
    for (final theme in [GabelTheme().light, GabelTheme().dark]) {
      final heading = theme.textTheme.h2;

      expect(heading.fontSize, style.fontSize);
      expect(heading.fontVariations, style.fontVariations);
      expect(heading.letterSpacing, style.letterSpacing);
    }
    expect(
      _width(style, '€41.31'),
      closeTo(_width(style, '€48.60'), .01),
      reason: 'Equal-length currencies keep the same width for every digit.',
    );
    expect(
      _width(style, '€41.31'),
      closeTo(77.6875, .5),
      reason: 'The total role matches the reference font axes and spacing.',
    );
  });
}
