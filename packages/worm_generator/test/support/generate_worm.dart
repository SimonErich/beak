import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:worm_generator/worm_generator.dart';

/// Runs the worm builder over [source], written to `_test|lib/[file]`, and
/// returns the text of the `.worm.dart` part it emits.
///
/// The real package sources (worm and its annotations) are loaded into the
/// in-memory build, so the annotations resolve exactly as in a project.
Future<String> generateWormPart(String file, String source) async {
  final readerWriter = TestReaderWriter(rootPackage: '_test');
  await readerWriter.testing.loadIsolateSources();
  final result = await testBuilder(
    PartBuilder(const <Generator>[WormTableGenerator()], '.worm.dart'),
    <String, String>{'_test|lib/$file': source},
    readerWriter: readerWriter,
    rootPackage: '_test',
    outputs: null,
    flattenOutput: true,
  );
  final output = AssetId(
    '_test',
    'lib/${file.replaceAll('.dart', '.worm.dart')}',
  );
  if (!result.outputs.contains(output)) {
    throw StateError('no ${output.path} output written: ${result.outputs}');
  }
  return readerWriter.testing.readString(output);
}
