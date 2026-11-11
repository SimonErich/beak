import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  group('BeakThemeController', () {
    test('starts from the fallback when nothing is stored', () async {
      final store = OiInMemorySettingsDriver();
      final controller = BeakThemeController.withStore(
        store,
        initialMode: OiThemeMode.light,
      );
      await controller.restore();

      expect(controller.value, OiThemeMode.light);
      expect(store.store, isEmpty);
    });

    test(
      'persists the chosen mode and restores it for a new controller',
      () async {
        final store = OiInMemorySettingsDriver();
        final first = BeakThemeController.withStore(
          store,
          initialMode: OiThemeMode.system,
        );
        await first.restore();

        first.value = OiThemeMode.dark;
        await pumpEventQueue();

        final second = BeakThemeController.withStore(
          store,
          initialMode: OiThemeMode.light,
        );
        await second.restore();

        expect(second.value, OiThemeMode.dark);
        first.dispose();
        second.dispose();
      },
    );

    test('a live write wins over an in-flight restore', () async {
      final store = OiInMemorySettingsDriver()
        ..store['theme'] = {'schemaVersion': 1, 'mode': OiThemeMode.dark.name};
      final controller = BeakThemeController.withStore(
        store,
        initialMode: OiThemeMode.system,
      );

      controller.value = OiThemeMode.light;
      await controller.restore();

      expect(controller.value, OiThemeMode.light);
      controller.dispose();
    });

    test('ignores corrupt stored preferences', () async {
      final store = OiInMemorySettingsDriver()
        ..store['theme'] = {'schemaVersion': 1, 'mode': 'neon'};
      final controller = BeakThemeController.withStore(
        store,
        initialMode: OiThemeMode.system,
      );
      await controller.restore();

      expect(controller.value, OiThemeMode.system);
      controller.dispose();
    });
  });
}
