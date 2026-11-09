import 'package:beak_theme_gabel/beak_theme_gabel.dart';
import 'package:beak_theme_gabel/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import 'support/theme_showcase.dart';

void main() {
  setUpAll(loadGabelFonts);

  for (final mode in ['light', 'dark']) {
    testWidgets('the $mode showcase matches its golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 440));
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        return tester.binding.setSurfaceSize(null);
      });
      final theme = GabelTheme();
      await tester.pumpWidget(
        OiApp(
          theme: mode == 'dark' ? theme.dark : theme.light,
          themeMode: mode == 'dark' ? OiThemeMode.dark : OiThemeMode.light,
          debugShowCheckedModeBanner: false,
          home: themeShowcase(),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(OiApp),
        matchesGoldenFile('goldens/showcase_$mode.png'),
      );
    });
  }
}
