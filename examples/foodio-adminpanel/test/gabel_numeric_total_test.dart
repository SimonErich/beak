import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/theme/gabel_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'body, medium, caption and metric amounts render tabular digits',
    () async {
      await (FontLoader(
        'Mona Sans',
      )..addFont(rootBundle.load('assets/fonts/MonaSans.ttf'))).load();
      final body = gabelTheme().textTheme.body;
      for (final role in [
        gabelNumericBodyStyle,
        gabelNumericMediumStyle,
        gabelNumericCaptionStyle,
        gabelNumericMetricStyle,
      ]) {
        final style = body.merge(role);
        double width(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
          )..layout();
          final value = painter.width;
          painter.dispose();
          return value;
        }

        expect(
          width('€41.31'),
          closeTo(width('€48.60'), .01),
          reason: 'Every monetary role gives every digit equal width.',
        );
      }
    },
  );

  test(
    'monetary totals share the wide heading role with tabular digits',
    () async {
      await (FontLoader(
        'Mona Sans',
      )..addFont(rootBundle.load('assets/fonts/MonaSans.ttf'))).load();
      final style = gabelNumericTotalStyle;
      expect(style.fontSize, 22);
      expect(style.height, 28 / 22);
      expect(style.letterSpacing, -.22);
      expect(style.fontVariations, const [
        FontVariation('wght', 580),
        FontVariation('wdth', 106),
      ]);
      expect(style.fontFeatures, const [FontFeature.tabularFigures()]);
      for (final dark in [false, true]) {
        final heading = gabelTheme(dark: dark).textTheme.h2;
        expect(heading.fontSize, style.fontSize);
        expect(heading.fontVariations, style.fontVariations);
        expect(heading.letterSpacing, style.letterSpacing);
      }
      double width(String amount) {
        final painter = TextPainter(
          text: TextSpan(text: amount, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final result = painter.width;
        expect(painter.height, closeTo(28, .01));
        painter.dispose();
        return result;
      }

      expect(
        width('€41.31'),
        closeTo(width('€48.60'), .01),
        reason: 'Equal-length currencies keep the same width for every digit.',
      );
      expect(
        width('€41.31'),
        closeTo(77.6875, .5),
        reason:
            'The supplied total role matches the reference font axes and spacing.',
      );
    },
  );
}
