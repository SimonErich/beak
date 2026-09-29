import 'package:test/test.dart';

import '../tool/check_no_material.dart';

void main() {
  test('flags a material import', () {
    const source = '''
import 'package:flutter/material.dart';

void main() {}
''';
    expect(forbiddenImportsIn(source), ['package:flutter/material.dart']);
  });

  test('flags a cupertino export with double quotes', () {
    const source = 'export "package:flutter/cupertino.dart";\n';
    expect(forbiddenImportsIn(source), ['package:flutter/cupertino.dart']);
  });

  test('accepts core flutter widgets and foundation imports', () {
    const source = '''
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {}
''';
    expect(forbiddenImportsIn(source), isEmpty);
  });

  test('ignores non-directive lines that merely mention the uri', () {
    const source = '''
/// Never import 'package:flutter/material.dart' in Beak code.
const String rule = 'no material';
''';
    expect(forbiddenImportsIn(source), isEmpty);
  });

  test('recognises a pub workspace root and its Beak members', () {
    expect(isWorkspaceRoot('name: _\nworkspace:\n  - shop_server\n'), isTrue);
    expect(isWorkspaceRoot('name: shop\nresolution: workspace\n'), isFalse);
    expect(
      dependsOnBeak('dependencies:\n  beak_core:\n    path: ../beak_core\n'),
      isTrue,
    );
    expect(
      dependsOnBeak('dependencies:\n  serverpod_flutter: 4.0.3\n'),
      isFalse,
    );
  });
}
