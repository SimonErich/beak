import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source roots the Flutter-side packages ship.
const List<String> _libraryRoots = ['lib', '../beak_serverpod_flutter/lib'];

/// The forms of state class the HookWidget-only rule forbids.
final RegExp _statefulDeclaration = RegExp(
  r'extends\s+(StatefulWidget|State<|StatefulElement)',
);

Iterable<File> _sources() sync* {
  for (final root in _libraryRoots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) yield entity;
    }
  }
}

void main() {
  test(
    'the library roots exist, so the guard cannot pass on an empty scan',
    () {
      expect(Directory('lib').existsSync(), isTrue);
      expect(_sources().length, greaterThan(100));
    },
  );

  test('widgets are HookWidgets: no library file extends a State class', () {
    final offenders = <String>[
      for (final file in _sources())
        for (final (index, line) in file.readAsLinesSync().indexed)
          if (!line.trimLeft().startsWith('//') &&
              _statefulDeclaration.hasMatch(line))
            '${file.path}:${index + 1}: ${line.trim()}',
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'CLAUDE.md 2.1: StatefulWidget is forbidden, use a HookWidget with '
          'flutter_hooks.',
    );
  });
}
