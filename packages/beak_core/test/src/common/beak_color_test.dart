import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test('exposes exactly the documented semantic tokens, in stable order', () {
    expect(BeakColor.values.map((color) => color.name), const [
      'primary',
      'secondary',
      'success',
      'warning',
      'error',
      'info',
      'muted',
    ]);
  });
}
