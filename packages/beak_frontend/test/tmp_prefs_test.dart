import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  testWidgets('load swallows a missing plugin', (tester) async {
    const store = OiLocalStorageDriver(prefix: 'x');
    final result = await store.load<OiSettingsData>(
      namespace: 'n',
      deserialize: (json) => throw StateError('nope'),
    );
    expect(result, isNull);
  });
}
