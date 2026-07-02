import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test('maps every context to its configured intent', () {
    const config = BeakRenderConfig(
      table: BeakRenderIntent.thumbnail,
      form: BeakRenderIntent.image,
      detail: BeakRenderIntent.image,
      filter: BeakRenderIntent.custom,
    );
    expect(config.intentFor(BeakContext.table), BeakRenderIntent.thumbnail);
    expect(config.intentFor(BeakContext.form), BeakRenderIntent.image);
    expect(config.intentFor(BeakContext.detail), BeakRenderIntent.image);
    expect(config.intentFor(BeakContext.filter), BeakRenderIntent.custom);
  });

  test('uniform applies one intent to every context', () {
    const config = BeakRenderConfig.uniform(BeakRenderIntent.text);
    for (final context in BeakContext.values) {
      expect(config.intentFor(context), BeakRenderIntent.text);
    }
  });
}
