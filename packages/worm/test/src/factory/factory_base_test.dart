import 'package:test/test.dart';
import 'package:worm/src/exception/factory_exception.dart';
import 'package:worm/src/factory/factory_base.dart';
import 'package:worm/src/model/model.dart';

final class _Counter extends Model {
  _Counter(this.value, {this.tag = 'plain'}) {
    setAttribute('value', value);
    setAttribute('tag', tag);
  }

  final int value;
  final String tag;

  @override
  String get tableName => 'counters';

  @override
  Object get id => value;

  @override
  Map<String, Object?> toRow() => <String, Object?>{...state.attributes};
}

final class _CounterFactory extends Factory<_Counter> {
  _CounterFactory();
  int _next = 0;
  @override
  _Counter definition() {
    final value = _next;
    _next++;
    return _Counter(value);
  }

  @override
  Map<String, FactoryState<_Counter>> get stateVariations =>
      <String, FactoryState<_Counter>>{
        'admin': (base) => _Counter(base.value, tag: 'admin'),
        'guest': (base) => _Counter(base.value, tag: 'guest'),
      };
}

void main() {
  group('Factory', () {
    test('make returns one fresh instance per call', () {
      final factory = _CounterFactory();
      final first = factory.make();
      final second = factory.make();
      expect(first.value, 0);
      expect(second.value, 1);
    });

    test('makeMany returns N sequential instances', () {
      final factory = _CounterFactory();
      final batch = factory.makeMany(3);
      expect(batch.map((c) => c.value), [0, 1, 2]);
    });

    test('state(name) applies a registered variation', () {
      final factory = _CounterFactory();
      final instance = factory.state('admin').make();
      expect(instance.tag, 'admin');
      expect(instance.value, 0);
    });

    test('state variations compose across chained calls', () {
      final factory = _CounterFactory();
      final guest = factory.state('admin').state('guest').make();
      expect(guest.tag, 'guest');
    });

    test('state(unknown) throws FactoryException', () {
      final factory = _CounterFactory();
      expect(() => factory.state('missing'), throwsA(isA<FactoryException>()));
    });

    test('withTransform applies an inline variation', () {
      final factory = _CounterFactory();
      final tagged = factory
          .withTransform((base) => _Counter(base.value, tag: 'inline'))
          .make();
      expect(tagged.tag, 'inline');
    });
  });
}
