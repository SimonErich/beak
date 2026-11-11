import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_theme_gabel/beak_theme_gabel.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  final theme = GabelTheme();

  group('GabelTheme', () {
    test('is a BeakTheme with a light and a dark theme', () {
      expect(theme, isA<BeakTheme>());
      expect(theme.light.colors.background, GabelLight.canvas);
      expect(theme.dark.colors.background, GabelDark.canvas);
    });

    test('maps the tokens of each brightness onto the color scheme', () {
      for (final (OiThemeData data, canvas, sheet, ink, primary) in [
        (
          theme.light,
          GabelLight.canvas,
          GabelLight.sheet,
          GabelLight.ink,
          GabelLight.primary,
        ),
        (
          theme.dark,
          GabelDark.canvas,
          GabelDark.sheet,
          GabelDark.ink,
          GabelDark.primary,
        ),
      ]) {
        expect(data.colors.background, canvas);
        expect(data.colors.surface, sheet);
        expect(data.colors.text, ink);
        expect(data.colors.primary.base, primary);
      }
      expect(theme.light.colors.chart, [
        GabelLight.chart1,
        GabelLight.chart2,
        GabelLight.chart3,
        GabelLight.chart4,
        GabelLight.chart5,
        GabelLight.chart6,
      ]);
      expect(theme.dark.colors.chart.first, GabelDark.chart1);
    });

    test('builds a fresh, equal theme every time', () {
      expect(GabelTheme().light, theme.light);
      expect(GabelTheme().dark, theme.dark);
    });

    test('routes the icon set through the theme', () {
      expect(theme.light.components.icon?.sources, same(gabelIconSources));
      expect(gabelIconSources, contains(OiIcons.search));
    });
  });

  group('field label role', () {
    for (final (name, data) in [('light', theme.light), ('dark', theme.dark)]) {
      test(
        '$name: caption and the input label share the subtle 12/16 role',
        () {
          final role = data.textTheme.caption;

          expect(role.fontSize, 12);
          expect(role.height, 16 / 12);
          expect(role.color, data.colors.textSubtle, reason: name);
          expect(data.components.textInput?.labelStyle, role);
          expect(data.components.textInput?.labelGap, 4);
          expect(data.components.fieldDisplay?.labelStyle, role);
        },
      );

      test('$name: tiny and overline read in subtle ink', () {
        expect(data.textTheme.tiny.color, data.colors.textSubtle, reason: name);
        expect(
          data.textTheme.overline.color,
          data.colors.textSubtle,
          reason: name,
        );
      });
    }
  });

  group('components', () {
    test('the compact sidebar is 64 wide next to the 264 full width', () {
      expect(theme.light.components.sidebar?.compactWidth, 64);
      expect(theme.light.components.sidebar?.width, 264);
    });

    test('field values read in body text with a link style', () {
      final display = theme.light.components.fieldDisplay;

      expect(display?.valueStyle, theme.light.textTheme.body);
      expect(display?.linkStyle?.color, GabelLight.primaryInk);
    });

    test('badges use the swatch colors', () {
      expect(theme.light.components.badge?.useSwatchColors, isTrue);
    });
  });

  group('numeric styles', () {
    test('every amount role switches on tabular figures', () {
      for (final style in [
        gabelNumericBodyStyle,
        gabelNumericMediumStyle,
        gabelNumericCaptionStyle,
        gabelNumericMetricStyle,
        gabelNumericTotalStyle,
      ]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test('the total is the heading 2 role', () {
      expect(gabelNumericTotalStyle.fontSize, gabelHeading2Style.fontSize);
      expect(gabelHeading2Style.fontFamily, gabelSansFamily);
    });
  });
}
