import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// Pins the documented 1:1 mapping onto worm's `OnDelete` enum without
/// importing worm (beak_core stays ORM-free): adding a `BeakOnDelete` value
/// breaks compilation here, and renaming one breaks the expectation, forcing
/// the `beak_backend` mapper to be revisited.
String wormOnDeleteNameOf(BeakOnDelete onDelete) => switch (onDelete) {
  BeakOnDelete.cascade => 'cascade',
  BeakOnDelete.ormCascade => 'ormCascade',
  BeakOnDelete.restrict => 'restrict',
  BeakOnDelete.setNull => 'setNull',
  BeakOnDelete.setDefault => 'setDefault',
  BeakOnDelete.noAction => 'noAction',
};

void main() {
  test('maps 1:1 onto worm OnDelete names, exhaustively', () {
    expect(BeakOnDelete.values.map(wormOnDeleteNameOf), const [
      'cascade',
      'ormCascade',
      'restrict',
      'setNull',
      'setDefault',
      'noAction',
    ]);
  });
}
