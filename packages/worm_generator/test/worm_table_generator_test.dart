@TestOn('vm')
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_generator/worm_generator.dart';

const String _annotatedSource = '''
import 'package:worm/annotations.dart';
import 'package:worm/worm.dart';

part 'user.worm.dart';

@Table()
@Fillable(['first_name', 'last_name'])
@Guarded(['password'])
class User {
  @PrimaryKey()
  final String id;

  @Column()
  @Hidden()
  final String password;

  @Column(name: 'session_duration')
  @CastAs(DurationCast)
  final int sessionDuration;

  User({required this.id, required this.password, required this.sessionDuration});
}
''';

const String _connectionSource = '''
import 'package:worm/annotations.dart';
import 'package:worm/worm.dart';

part 'event.worm.dart';

@Table(connection: 'analytics')
class Event {
  @PrimaryKey()
  final String id;

  Event({required this.id});
}
''';

void main() {
  group('WormTableGenerator', () {
    test('is constructable as const', () {
      const generator = WormTableGenerator();
      expect(generator, isNotNull);
    });

    test('worm codegen produces valid file from descriptor', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(
            dartName: 'id',
            dbName: 'id',
            dartType: 'String',
            isPrimaryKey: true,
          ),
          ColumnDescriptor(
            dartName: 'firstName',
            dbName: 'first_name',
            dartType: 'String',
            fieldKind: FieldKind.string,
          ),
        ],
      );
      final source = const WormFileGenerator(descriptor).generate();
      expect(source, contains('GENERATED CODE'));
      expect(source, contains('class User\$'));
      expect(source, contains('first_name'));
      expect(source, isNot(contains(' as String')));
    });

    test(
      'emits annotations mixin wiring @Hidden, @CastAs, @Fillable, @Guarded, '
      'and a describe() override',
      () async {
        final reader = await PackageAssetReader.currentIsolate();
        final builder = PartBuilder(const <Generator>[
          WormTableGenerator(),
        ], '.worm.dart');
        final writer = InMemoryAssetWriter();
        await testBuilder(
          builder,
          const <String, String>{'_test|lib/user.dart': _annotatedSource},
          reader: reader,
          writer: writer,
          rootPackage: '_test',
        );
        final generated = writer.assets[AssetId('_test', 'lib/user.worm.dart')];
        expect(generated, isNotNull, reason: 'no .worm.dart output written');
        final source = String.fromCharCodes(generated!);

        // Mixin header.
        expect(source, contains('mixin _\$UserAnnotations on Model {'));

        // @Hidden('password') → hiddenFromSerialization includes
        // the snake_case DB column name.
        expect(
          source,
          contains(
            'Set<String> get hiddenFromSerialization => '
            "const <String>{'password'};",
          ),
        );

        // @Fillable(['first_name', 'last_name']) → fillable getter.
        expect(
          source,
          contains(
            'List<String> get fillable => '
            "const <String>['first_name', 'last_name'];",
          ),
        );

        // @Guarded(['password']) → guarded getter.
        expect(
          source,
          contains("List<String> get guarded => const <String>['password'];"),
        );

        // @CastAs(DurationCast) → castManager registers the cast by
        // the column's snake_case DB name.
        expect(source, contains('CastManager get castManager => CastManager('));
        expect(source, contains("'session_duration': const DurationCast(),"));

        // describe() override — required by AC even though the
        // Model default produces the same shape.
        expect(source, contains('SerializationDescriptor describe() => '));
        expect(source, contains('hidden: hiddenFromSerialization,'));
        expect(source, contains('appended: computedAttributes,'));

        // Constitution: zero as-casts in the emitted code.
        expect(source, isNot(contains(' as ')));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'emits a connectionName override for a non-default @Table(connection:)',
      () async {
        final reader = await PackageAssetReader.currentIsolate();
        final builder = PartBuilder(const <Generator>[
          WormTableGenerator(),
        ], '.worm.dart');
        final writer = InMemoryAssetWriter();
        await testBuilder(
          builder,
          const <String, String>{'_test|lib/event.dart': _connectionSource},
          reader: reader,
          writer: writer,
          rootPackage: '_test',
        );
        final generated =
            writer.assets[AssetId('_test', 'lib/event.worm.dart')];
        expect(generated, isNotNull, reason: 'no .worm.dart output written');
        final source = String.fromCharCodes(generated!);

        expect(source, contains('mixin _\$EventAnnotations on Model {'));
        expect(source, contains("String get connectionName => 'analytics';"));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
