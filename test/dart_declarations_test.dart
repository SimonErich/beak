import 'package:test/test.dart';

import '../tool/src/dart_declarations.dart';

void main() {
  group('publicNamesIn', () {
    test('finds type declarations of every kind', () {
      expect(
        publicNamesIn('''
final class BeakColumn<T extends Object> extends Base implements Other {}
abstract interface class Contract {}
mixin Sortable on Base {}
enum BeakOperation { read, create }
typedef Callback = void Function(int amount);
extension StringX on String {}
extension type Meters(int value) {}
sealed class Result {}
'''),
        containsAll(<String>{
          'BeakColumn',
          'Contract',
          'Sortable',
          'BeakOperation',
          'read',
          'create',
          'Callback',
          'StringX',
          'Meters',
          'Result',
        }),
      );
    });

    test('finds members: fields, methods, accessors, constructors', () {
      final Set<String> names = publicNamesIn('''
class BeakResource {
  const BeakResource({required this.title, this.navigationTitle});
  const BeakResource.named(String label) : title = label;
  factory BeakResource.fromRow(int row) => BeakResource(title: 'x');
  final String title;
  final String? navigationTitle;
  static const int defaultLimit = 25;
  String get displayName => title;
  set displayName(String value) {}
  Future<void> reload({bool force = false}) async {}
}
''');
      expect(
        names,
        containsAll(<String>{
          'BeakResource',
          'title',
          'navigationTitle',
          'named',
          'label',
          'fromRow',
          'defaultLimit',
          'displayName',
          'reload',
          'force',
        }),
      );
    });

    test('finds top-level functions and variables', () {
      final Set<String> names = publicNamesIn('''
Future<void> initializeBeakDatabase(String url) async {}
const String beakVersion = '1';
final int a = 1;
''');
      expect(
        names,
        containsAll(<String>{
          'initializeBeakDatabase',
          'url',
          'beakVersion',
          'a',
        }),
      );
    });

    test('ignores comments and strings, whatever they hold', () {
      final Set<String> names = publicNamesIn(r'''
/// Was viewModes, see [oldDoc].
// createFields
/* block oldBlock /* nested nestedOld */ still */
class Host {
  static const String message = 'use viewModes instead';
  static const String other = "a ${interpolatedOld} b 'q' c";
  static const String raw = r'rawOld\';
  static const String triple = """
    tripleOld "quoted" 'single' still
  """;
  final int keep = 1;
}
''');
      expect(names, containsAll(<String>{'Host', 'message', 'keep'}));
      for (final String ghost in const [
        'viewModes',
        'oldDoc',
        'createFields',
        'oldBlock',
        'nestedOld',
        'interpolatedOld',
        'rawOld',
        'tripleOld',
      ]) {
        expect(names, isNot(contains(ghost)), reason: ghost);
      }
    });

    test('ignores private names and the insides of a private class', () {
      final Set<String> names = publicNamesIn('''
class Host {
  final int _hidden = 1;
  void _helper(int hiddenParameter) {}
  Host._internal();
  factory Host._make(int hiddenToo) => Host._internal();
  int visible = 2;
}
class _Anchor {
  final int notPublic = 1;
}
final int _top = 1;
''');
      expect(names, contains('Host'));
      expect(names, contains('visible'));
      for (final String ghost in const [
        '_hidden',
        '_helper',
        'hiddenParameter',
        '_internal',
        'hiddenToo',
        '_Anchor',
        'notPublic',
        '_top',
      ]) {
        expect(names, isNot(contains(ghost)), reason: ghost);
      }
    });

    test('ignores locals, calls and closures inside a body', () {
      final Set<String> names = publicNamesIn('''
class Host {
  void build() {
    final graphOnlyTables = <String>{};
    final callback = () { inner(); };
    beakDashboard();
  }
  int get value => oldExpression.compute(argumentOld);
  final Object seeded = makeSeed(oldNamed: 1);
  final Map<String, int> table = {'a': 1, 'b': tableOld};
}
''');
      expect(names, containsAll(<String>{'Host', 'build', 'value', 'seeded'}));
      for (final String ghost in const [
        'graphOnlyTables',
        'callback',
        'inner',
        'beakDashboard',
        'oldExpression',
        'argumentOld',
        'oldNamed',
        'tableOld',
      ]) {
        expect(names, isNot(contains(ghost)), reason: ghost);
      }
    });

    test('an initializer list with = does not swallow the next member', () {
      final Set<String> names = publicNamesIn('''
class Host {
  Host(int seed) : first = seed, second = seed + 1 {
    ignored();
  }
  Host.other() : first = 1, second = 2;
  final int first;
  final int second;
  int afterwards = 3;
}
''');
      expect(
        names,
        containsAll(<String>{'first', 'second', 'other', 'afterwards'}),
      );
      expect(names, isNot(contains('ignored')));
    });

    test('reads annotations, records and function-typed parameters', () {
      final Set<String> names = publicNamesIn('''
class Host {
  @Deprecated('Use replacement instead')
  final int annotated = 1;
  @override
  String toString() => 'x';
  void run(void Function(int step) onStep, (int, String) pair) {}
  final (int, {String label}) record = (1, label: 'x');
}
''');
      expect(
        names,
        containsAll(<String>{
          'annotated',
          'toString',
          'run',
          'onStep',
          'record',
        }),
      );
      expect(names, isNot(contains('replacement')));
    });

    test('enum constants with arguments and members', () {
      final Set<String> names = publicNamesIn('''
enum BeakValueFormat {
  number(0),
  currency(2),
  percent(1);

  const BeakValueFormat(this.digits);
  final int digits;
  bool get isMoney => this == currency;
}
''');
      expect(
        names,
        containsAll(<String>{
          'BeakValueFormat',
          'number',
          'currency',
          'percent',
          'digits',
          'isMoney',
        }),
      );
    });

    test('an unterminated string does not hang or throw', () {
      expect(() => publicNamesIn("class A { final x = 'open"), returnsNormally);
    });
  });
}
