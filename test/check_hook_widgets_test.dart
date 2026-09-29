import 'dart:io';

import 'package:test/test.dart';

import '../tool/check_hook_widgets.dart';

void main() {
  group('statefulClassesIn', () {
    test('flags a StatefulWidget subclass', () {
      const source = '''
import 'package:flutter/widgets.dart';

class Anchor extends StatefulWidget {
  const Anchor({super.key});
  @override
  State<Anchor> createState() => _AnchorState();
}
''';
      expect(statefulClassesIn(source), ['Anchor extends StatefulWidget']);
    });

    test('flags the State class, generic or private', () {
      const source = '''
class _AnchorState extends State<Anchor> {}
final class _Other<T extends Object> extends State<Anchor> {}
''';
      expect(statefulClassesIn(source), [
        '_AnchorState extends State',
        '_Other extends State',
      ]);
    });

    test('flags the hooks variants of both', () {
      const source = '''
class A extends StatefulHookWidget {}
class B extends HookState<A, int> {}
''';
      expect(statefulClassesIn(source), [
        'A extends StatefulHookWidget',
        'B extends HookState',
      ]);
    });

    test('reads a declaration split over lines and with modifiers', () {
      const source = '''
abstract base class VeryLongWidgetNameThatWraps<T extends Map<String, Object>>
    extends StatefulWidget {}
''';
      expect(statefulClassesIn(source), [
        'VeryLongWidgetNameThatWraps extends StatefulWidget',
      ]);
    });

    test('accepts HookWidget, StatelessWidget and plain classes', () {
      const source = '''
class A extends HookWidget {}
class B extends StatelessWidget {}
class C<T extends State> extends Object {}
class D implements StatefulWidget {}
class E extends StateController {}
''';
      expect(statefulClassesIn(source), isEmpty);
    });

    test('ignores comments and strings that mention the rule', () {
      const source = r'''
/// Never write `class X extends StatefulWidget`; it extends State<X> otherwise.
// class Y extends State<Y> {}
/* class Z extends StatefulWidget {} */
const String template = 'class W extends StatefulWidget {}';
const String other = """
class V extends State<V> {}
""";
class Fine extends HookWidget {}
''';
      expect(statefulClassesIn(source), isEmpty);
    });

    test('reports each offender once, in order', () {
      const source = '''
class First extends StatefulWidget {}
class Second extends HookWidget {}
class Third extends StatefulWidget {}
''';
      expect(statefulClassesIn(source), [
        'First extends StatefulWidget',
        'Third extends StatefulWidget',
      ]);
    });
  });

  group('the files it scans', () {
    late Directory repo;

    void write(String path, String content) {
      File('${repo.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    setUp(() {
      repo = Directory.systemTemp.createTempSync('hook_widgets_');
      addTearDown(() => repo.deleteSync(recursive: true));
    });

    test('scans lib/ of packages and examples, not tests or vendored code', () {
      write('packages/beak_a/pubspec.yaml', 'name: beak_a\n');
      write(
        'packages/beak_a/lib/src/a.dart',
        'class A extends StatefulWidget {}',
      );
      write('packages/beak_a/test/a_test.dart', 'class T extends State<T> {}');
      write('packages/worm_x/pubspec.yaml', 'name: worm_x\n');
      write('packages/worm_x/lib/x.dart', 'class X extends StatefulWidget {}');
      write('examples/shop/pubspec.yaml', 'name: shop\n');
      write('examples/shop/lib/main.dart', 'class S extends StatefulWidget {}');
      write('examples/shop/.dart_tool/lib/n.dart', 'class N {}');
      write('examples/shop/build/lib/b.dart', 'class B {}');

      final List<String> found = [
        for (final file in statefulViolations(repoRoot: repo.path))
          file.substring(repo.path.length + 1),
      ];
      expect(
        found,
        unorderedEquals([
          'examples/shop/lib/main.dart: S extends StatefulWidget',
          'packages/beak_a/lib/src/a.dart: A extends StatefulWidget',
        ]),
      );
    });

    test('a clean tree has no violations', () {
      write('packages/beak_a/pubspec.yaml', 'name: beak_a\n');
      write('packages/beak_a/lib/a.dart', 'class A extends HookWidget {}');
      expect(statefulViolations(repoRoot: repo.path), isEmpty);
    });

    test('only the Beak members of a workspace root are scanned', () {
      write(
        'examples/sp/pubspec.yaml',
        'name: _\nworkspace:\n  - admin\n  - app\n',
      );
      write(
        'examples/sp/admin/pubspec.yaml',
        'name: admin\ndependencies:\n  beak_frontend:\n    path: x\n',
      );
      write(
        'examples/sp/admin/lib/a.dart',
        'class A extends StatefulWidget {}',
      );
      write(
        'examples/sp/app/pubspec.yaml',
        'name: app\ndependencies:\n  serverpod_flutter: 4.0.3\n',
      );
      write('examples/sp/app/lib/a.dart', 'class B extends StatefulWidget {}');

      expect(
        [
          for (final file in statefulViolations(repoRoot: repo.path))
            file.substring(repo.path.length + 1),
        ],
        ['examples/sp/admin/lib/a.dart: A extends StatefulWidget'],
      );
    });
  });
}
