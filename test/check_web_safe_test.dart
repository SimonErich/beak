import 'dart:io';

import 'package:test/test.dart';

import '../tool/check_web_safe.dart';

/// Reads a real repo file, or `null` when it does not exist.
String? _readRepoFile(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

void main() {
  group('webUnsafeReason', () {
    test('flags dart:io, which compiles on web but throws at runtime', () {
      expect(webUnsafeReason('dart:io'), contains('dart:io'));
      expect(webUnsafeReason('dart:ffi'), isNotNull);
      expect(webUnsafeReason('dart:mirrors'), isNotNull);
    });

    test('flags server packages by prefix, including their variants', () {
      expect(webUnsafeReason('package:shelf/shelf.dart'), isNotNull);
      expect(
        webUnsafeReason('package:shelf_router/shelf_router.dart'),
        isNotNull,
      );
      expect(webUnsafeReason('package:worm/worm.dart'), isNotNull);
      expect(
        webUnsafeReason('package:worm_postgres/worm_postgres.dart'),
        isNotNull,
      );
      expect(
        webUnsafeReason('package:beak_backend/beak_backend.dart'),
        isNotNull,
      );
      expect(
        webUnsafeReason('package:beak_storage_s3/beak_storage_s3.dart'),
        isNotNull,
      );
      expect(webUnsafeReason('package:minio/minio.dart'), isNotNull);
    });

    test('accepts the panel stack', () {
      expect(webUnsafeReason('dart:async'), isNull);
      expect(webUnsafeReason('dart:typed_data'), isNull);
      expect(webUnsafeReason('package:beak_core/beak_core.dart'), isNull);
      expect(webUnsafeReason('package:obers_ui/obers_ui.dart'), isNull);
      expect(webUnsafeReason('package:flutter/widgets.dart'), isNull);
      expect(webUnsafeReason('src/columns/beak_column.dart'), isNull);
    });
  });

  group('referencedUrisIn', () {
    test('collects import, export and part directives', () {
      const source = '''
import 'dart:async';
export "package:beak_core/beak_core.dart";
part 'beak_string_column.dart';
''';
      expect(referencedUrisIn(source), [
        'dart:async',
        'package:beak_core/beak_core.dart',
        'beak_string_column.dart',
      ]);
    });

    test('ignores `part of` and URIs merely mentioned in comments', () {
      const source = '''
part of 'beak_column.dart';

/// Never import 'dart:io' from the panel graph.
const String rule = 'package:shelf/shelf.dart';
''';
      expect(referencedUrisIn(source), isEmpty);
    });
  });

  group('resolveWalkableUri', () {
    const from = 'packages/beak_core/lib/beak_core.dart';

    test('maps a beak package URI onto its lib directory', () {
      expect(
        resolveWalkableUri(
          'package:beak_frontend/src/panel/x.dart',
          fromFilePath: from,
        ),
        'packages/beak_frontend/lib/src/panel/x.dart',
      );
    });

    test('resolves a relative URI against the importing file', () {
      expect(
        resolveWalkableUri('src/columns/beak_column.dart', fromFilePath: from),
        'packages/beak_core/lib/src/columns/beak_column.dart',
      );
    });

    test('treats sdk and third-party URIs as boundary nodes', () {
      expect(resolveWalkableUri('dart:io', fromFilePath: from), isNull);
      expect(
        resolveWalkableUri(
          'package:obers_ui/obers_ui.dart',
          fromFilePath: from,
        ),
        isNull,
      );
    });
  });

  group('webSafetyViolations', () {
    test('follows exports transitively and reports the chain', () {
      // The exact shape of the bug this guard exists for: a web-safe-looking
      // barrel re-exporting a driver that imports dart:io three hops down.
      const files = {
        'packages/beak_frontend/lib/beak_frontend.dart':
            "export 'package:beak_core/beak_core.dart';",
        'packages/beak_core/lib/beak_core.dart':
            "export 'src/storage/drivers/local.dart';",
        'packages/beak_core/lib/src/storage/drivers/local.dart':
            "import 'dart:io';",
      };

      final violations = webSafetyViolations(
        'packages/beak_frontend/lib/beak_frontend.dart',
        readFile: (path) => files[path],
      );

      expect(violations, hasLength(1));
      expect(violations.single.uri, 'dart:io');
      expect(violations.single.importChain, [
        'packages/beak_frontend/lib/beak_frontend.dart',
        'packages/beak_core/lib/beak_core.dart',
        'packages/beak_core/lib/src/storage/drivers/local.dart',
      ]);
    });

    test('terminates on an import cycle', () {
      const files = {
        'a.dart': "import 'b.dart';",
        'b.dart': "import 'a.dart';\nimport 'dart:io';",
      };
      final violations = webSafetyViolations(
        'a.dart',
        readFile: (path) => files[path],
      );
      expect(violations.map((v) => v.uri), ['dart:io']);
    });

    test('tolerates a missing file rather than crashing the gate', () {
      final violations = webSafetyViolations(
        'packages/beak_core/lib/generated.dart',
        readFile: (_) => null,
      );
      expect(violations, isEmpty);
    });
  });

  group('the real panel entrypoints', () {
    test('are web-safe', () {
      for (final entrypoint in panelEntrypoints) {
        expect(
          _readRepoFile(entrypoint),
          isNotNull,
          reason:
              '$entrypoint should exist; update panelEntrypoints if it moved',
        );
        expect(
          webSafetyViolations(entrypoint, readFile: _readRepoFile),
          isEmpty,
          reason: '$entrypoint reaches server-side code',
        );
      }
    });

    test('include the annotation libraries a model file imports', () {
      // `package:beak/schema.dart` and `package:beak_core/schema.dart` are
      // imported by every model file, and the panel compiles those files, so
      // a server import behind either one breaks the web build.
      expect(
        panelEntrypoints,
        containsAll(<String>[
          'packages/beak/lib/schema.dart',
          'packages/beak_core/lib/schema.dart',
        ]),
      );
    });

    test('include the Serverpod libraries a panel imports', () {
      expect(
        panelEntrypoints,
        containsAll(<String>[
          'packages/beak_serverpod/lib/wire.dart',
          'packages/beak_serverpod_flutter/lib/beak_serverpod_flutter.dart',
          'packages/beak_serverpod_flutter/lib/tunnel.dart',
        ]),
      );
    });

    test('leave no public library unclassified', () {
      // A library added under lib/ is either panel-side, and walked, or
      // deliberately server-side, and listed. One that is neither is a
      // library nothing guards, which is how schema.dart went unwatched.
      const packages = [
        'beak',
        'beak_core',
        'beak_frontend',
        'beak_serverpod',
        'beak_serverpod_flutter',
      ];
      final unclassified = <String>[];
      for (final package in packages) {
        for (final entity in Directory('packages/$package/lib').listSync()) {
          if (entity is! File || !entity.path.endsWith('.dart')) {
            continue;
          }
          final String path = entity.path;
          if (!panelEntrypoints.contains(path) &&
              !serverEntrypoints.contains(path)) {
            unclassified.add(path);
          }
        }
      }
      expect(
        unclassified,
        isEmpty,
        reason:
            'add each to panelEntrypoints (web-safe) or serverEntrypoints '
            '(server-side on purpose) in tool/check_web_safe.dart',
      );
    });

    test('never list a library as both panel-side and server-side', () {
      expect(
        panelEntrypoints.toSet().intersection(serverEntrypoints.toSet()),
        isEmpty,
      );
    });

    test('reach the panel stack, so the walk is not vacuously clean', () {
      final walked = <String>{};
      webSafetyViolations(
        'packages/beak_frontend/lib/beak_frontend.dart',
        readFile: (path) {
          final source = _readRepoFile(path);
          if (source != null) {
            walked.add(path);
          }
          return source;
        },
      );
      expect(walked, contains('packages/beak_core/lib/beak_core.dart'));
      expect(walked.length, greaterThan(100));
    });
  });
}
