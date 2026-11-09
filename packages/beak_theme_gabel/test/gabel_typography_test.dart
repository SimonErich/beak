import 'dart:ui' as ui;

import 'package:beak_theme_gabel/beak_theme_gabel.dart';
import 'package:beak_theme_gabel/testing.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _raster(TextStyle style) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final painter = TextPainter(
    text: TextSpan(text: 'Beetroot risotto · Tobias Wagner', style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, Offset.zero);
  painter.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(350, 40);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return bytes?.buffer.asUint8List().toList() ?? const [];
}

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
  final body = GabelTheme().light.textTheme.body;

  test(
    'native hundred weights rasterize exactly as their variable axes',
    () async {
      List<int>? previous;
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      ]) {
        final native = await _raster(body.copyWith(fontWeight: weight));
        final axis = await _raster(
          body.copyWith(
            fontWeight: weight,
            fontVariations: [
              FontVariation('wght', weight.value.toDouble()),
              const FontVariation('wdth', 100),
            ],
          ),
        );

        expect(
          native,
          orderedEquals(axis),
          reason:
              'Native ${weight.value} must use the glyphs of wght ${weight.value}.',
        );
        if (previous != null) {
          expect(
            native,
            isNot(orderedEquals(previous)),
            reason: 'The next weight must not fall back to the previous face.',
          );
        }
        previous = native;
      }
    },
  );

  test('semantic emphasis changes the rendered variable font weight', () {
    expect(
      _width(
        body.copyWith(fontWeight: FontWeight.w700),
        'Orders that need attention',
      ),
      greaterThan(_width(body, 'Orders that need attention')),
      reason: 'A stale wght axis must not defeat component emphasis.',
    );
    expect(
      GabelTheme().light.textTheme.h1.fontVariations,
      contains(const FontVariation('wght', 560)),
      reason:
          'Fractional display weights still need an explicit variable axis.',
    );
  });

  test('midweight labels use the same glyphs as the variable 500 axis', () {
    final regular = _width(
      body.copyWith(fontWeight: FontWeight.w400),
      'Tobias Wagner',
    );
    final medium = _width(
      body.copyWith(fontWeight: FontWeight.w500),
      'Tobias Wagner',
    );
    final explicit = _width(
      body.copyWith(
        fontWeight: FontWeight.w500,
        fontVariations: const [
          FontVariation('wght', 500),
          FontVariation('wdth', 100),
        ],
      ),
      'Tobias Wagner',
    );

    expect(
      medium,
      closeTo(explicit, .01),
      reason: 'regular=$regular, medium=$medium, explicit=$explicit',
    );
    expect(medium, greaterThan(regular));
  });

  test('the bundled font is the one that renders, not a fallback', () {
    final label = GabelTheme().light.textTheme.caption;

    expect(
      _width(label, 'Tobias Wagner'),
      isNot(
        closeTo(
          _width(label.copyWith(fontFamily: 'Missing'), 'Tobias Wagner'),
          .01,
        ),
      ),
    );
  });
}
