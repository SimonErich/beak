import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import '../commands/prepare_command_test.dart'
    show environmentFor, projectWith, read;
import 'beak_schema_test.dart' show categorySchema, modelsWith;

void main() {
  group('the part directive of a schema file', () {
    List<BeakDiscoveryIssue> issuesFor(Map<String, String> files) {
      final reader = BeakSchemaReader(modelsWith(files));
      final (schemas, _) = reader.read();
      return reader.partDirectiveIssues(schemas);
    }

    test('is required, and a schema without it is named', () {
      // With the directive gone the generated part belongs to no library, and
      // prepare said "up to date" about a project that did not compile.
      final issues = issuesFor({
        'category.dart': categorySchema.replaceFirst(
          "part 'category.beak.dart';\n",
          '',
        ),
      });

      expect(issues, hasLength(1));
      expect(issues.single.path, 'lib/models/category.dart');
      expect(issues.single.message, contains('Category'));
      expect(issues.single.message, contains("part 'category.beak.dart';"));
    });

    test('present, in either quote style, is fine', () {
      expect(issuesFor({'category.dart': categorySchema}), isEmpty);
      expect(
        issuesFor({
          'category.dart': categorySchema.replaceFirst(
            "part 'category.beak.dart';",
            'part "category.beak.dart";',
          ),
        }),
        isEmpty,
      );
    });

    test('naming another file is as good as none', () {
      final issues = issuesFor({
        'category.dart': categorySchema.replaceFirst(
          "part 'category.beak.dart';",
          "part 'categories.beak.dart';",
        ),
      });

      expect(issues, hasLength(1));
      expect(issues.single.message, contains("part 'category.beak.dart';"));
    });

    test('is asked for once per file, however many schemas it holds', () {
      final issues = issuesFor({
        'pair.dart': '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

@Resource()
final class Alpha extends BeakSchema {
  @Display()
  late final String name;
}

@Resource()
final class Beta extends BeakSchema {
  @Display()
  late final String name;
}
''',
      });

      expect(issues, hasLength(1));
    });
  });

  group('beak prepare', () {
    test(
      'refuses a schema without the directive and writes no part for it',
      () {
        final root = projectWith({
          'lib/models/category.dart': categorySchema.replaceFirst(
            "part 'category.beak.dart';\n",
            '',
          ),
        });
        final out = StringBuffer();

        final result = runPrepare(environmentFor(root, out: out));

        expect(result.isSuccess, isFalse);
        expect(out.toString(), contains('Cannot generate: fix these first:'));
        expect(out.toString(), contains("part 'category.beak.dart';"));
        expect(
          File('${root.path}/lib/models/category.beak.dart').existsSync(),
          isFalse,
        );
      },
    );

    test('still generates when the directive is there', () {
      final root = projectWith({'lib/models/category.dart': categorySchema});

      final result = runPrepare(environmentFor(root));

      expect(result.isSuccess, isTrue);
      expect(read(root, 'lib/models/category.beak.dart'), isNotEmpty);
    });
  });

  group('beak doctor', () {
    test('fails on a schema without the directive', () async {
      final root = projectWith({
        'lib/models/category.dart': categorySchema.replaceFirst(
          "part 'category.beak.dart';\n",
          '',
        ),
      });

      final checks = await diagnose(
        environmentFor(root),
        readSchema: (url, {String schema = 'public'}) async => const [],
      );

      final failed = checks.where(
        (check) => check.status == BeakCheckStatus.fail,
      );
      expect(
        failed.map((check) => check.label),
        contains(contains("part 'category.beak.dart';")),
      );
    });
  });
}
