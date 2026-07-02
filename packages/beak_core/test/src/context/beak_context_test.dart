import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test('covers exactly the table, form, detail and filter render sites', () {
    expect(BeakContext.values.map((context) => context.name), const [
      'table',
      'form',
      'detail',
      'filter',
    ]);
  });
}
