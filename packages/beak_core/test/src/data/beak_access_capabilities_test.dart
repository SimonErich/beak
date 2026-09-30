import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'allowlists retain unrestricted and deny-all semantics through JSON',
    () {
      for (final access in [
        const BeakAccessCapabilities(),
        const BeakAccessCapabilities(readableFields: {}, writableFields: {}),
        const BeakAccessCapabilities(
          readableFields: {'name'},
          writableFields: {'title'},
        ),
      ]) {
        final decoded = BeakAccessCapabilities.fromJson(access.toJson());
        expect(decoded.canRead('name'), access.canRead('name'));
        expect(decoded.canWrite('title'), access.canWrite('title'));
        expect(decoded.toJson(), access.toJson());
      }
      for (final malformed in [
        1,
        ['name', 1],
        {'name': true},
      ]) {
        expect(
          () => BeakAccessCapabilities.fromJson({'readableFields': malformed}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'action allowlists distinguish unrestricted, deny-all and named commands',
    () {
      for (final actions in <Set<String>?>[
        null,
        {},
        {'issue', 'cancel'},
      ]) {
        final access = BeakAccessCapabilities(executableActions: actions);
        final decoded = BeakAccessCapabilities.fromJson(access.toJson());
        expect(
          decoded.canExecuteAction('issue'),
          actions == null || actions.contains('issue'),
        );
        expect(decoded.canExecuteAction('delete'), actions == null);
        expect(decoded.executableActions, actions);
        if (decoded.executableActions != null) {
          expect(
            () => decoded.executableActions!.add('forged'),
            throwsUnsupportedError,
          );
        }
      }
      expect(
        () => BeakAccessCapabilities.fromJson({
          'executableActions': ['issue', 42],
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'creating and deleting are allowed unless the server says otherwise',
    () {
      const unrestricted = BeakAccessCapabilities();
      expect(unrestricted.canCreate, isTrue);
      expect(unrestricted.canDelete, isTrue);
      expect(unrestricted.toJson()['canCreate'], isTrue);
      expect(unrestricted.toJson()['canDelete'], isTrue);
    },
  );

  test('create and delete permissions survive the JSON round trip', () {
    for (final (create, delete) in [
      (true, true),
      (true, false),
      (false, true),
      (false, false),
    ]) {
      final decoded = BeakAccessCapabilities.fromJson(
        BeakAccessCapabilities(canCreate: create, canDelete: delete).toJson(),
      );
      expect(decoded.canCreate, create);
      expect(decoded.canDelete, delete);
    }
  });

  test('a server that reports neither leaves both allowed', () {
    final decoded = BeakAccessCapabilities.fromJson({
      'readableFields': ['name'],
    });

    expect(decoded.canCreate, isTrue);
    expect(decoded.canDelete, isTrue);
  });

  test('a create or delete permission that is not a boolean is refused', () {
    for (final key in ['canCreate', 'canDelete']) {
      expect(
        () => BeakAccessCapabilities.fromJson({key: 'no'}),
        throwsFormatException,
        reason: key,
      );
    }
  });
}
