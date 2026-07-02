import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test('exposes exactly the documented intents, in stable order', () {
    expect(BeakRenderIntent.values.map((intent) => intent.name), const [
      'text',
      'number',
      'currency',
      'badge',
      'image',
      'thumbnail',
      'boolean',
      'date',
      'relativeDate',
      'relationLink',
      'relationBadges',
      'richText',
      'color',
      'json',
      'custom',
    ]);
  });
}
