import 'package:beak_backend/src/service/beak_scope_match.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/api_models.dart';

BeakRecord _note(Map<String, Object?> row) => BeakRecord.fromRow(row);

void main() {
  group('beakScopeAdmits', () {
    test('no scope admits every record', () {
      expect(beakScopeAdmits(null, _note({})), isTrue);
    });

    test('equality compares the value the write leaves behind', () {
      final scope = NoteModel.authorId.eq('a1');
      expect(beakScopeAdmits(scope, _note({'author_id': 'a1'})), isTrue);
      expect(beakScopeAdmits(scope, _note({'author_id': 'a2'})), isFalse);
      expect(beakScopeAdmits(scope, _note({})), isFalse);
    });

    test('a missing field satisfies only isNull, like SQL', () {
      const unowned = BeakFieldFilter.forKey('author_id', BeakOperator.isNull);
      const owned = BeakFieldFilter.forKey('author_id', BeakOperator.isNotNull);
      final other = BeakFieldFilter.forKey(
        'author_id',
        BeakOperator.neq,
        BeakValue.of('a1'),
      );
      expect(beakScopeAdmits(unowned, _note({})), isTrue);
      expect(beakScopeAdmits(owned, _note({})), isFalse);
      expect(beakScopeAdmits(other, _note({})), isFalse);
      expect(beakScopeAdmits(other, _note({'author_id': 'a2'})), isTrue);
    });

    test('lists, and, or and orderings combine', () {
      final inList = BeakFieldFilter.forKey(
        'author_id',
        BeakOperator.inList,
        BeakValue.of(['a1', 'a2']),
      );
      final notInList = BeakFieldFilter.forKey(
        'author_id',
        BeakOperator.notInList,
        BeakValue.of(['a1', 'a2']),
      );
      final minRating = BeakFieldFilter.forKey(
        'rating',
        BeakOperator.gte,
        BeakValue.of(3),
      );
      final maxRating = BeakFieldFilter.forKey(
        'rating',
        BeakOperator.lt,
        BeakValue.of(5),
      );
      final image = _note({'author_id': 'a2', 'rating': 4});

      expect(beakScopeAdmits(inList, image), isTrue);
      expect(beakScopeAdmits(notInList, image), isFalse);
      expect(
        beakScopeAdmits(BeakAndFilter([minRating, maxRating]), image),
        isTrue,
      );
      expect(
        beakScopeAdmits(
          BeakAndFilter([minRating, notInList]),
          _note({'author_id': 'a2', 'rating': 4}),
        ),
        isFalse,
      );
      expect(
        beakScopeAdmits(BeakOrFilter([notInList, minRating]), image),
        isTrue,
      );
      expect(
        beakScopeAdmits(
          BeakFieldFilter.forKey('rating', BeakOperator.gt, BeakValue.of(4)),
          image,
        ),
        isFalse,
      );
      expect(
        beakScopeAdmits(
          BeakFieldFilter.forKey('rating', BeakOperator.lte, BeakValue.of(4)),
          image,
        ),
        isTrue,
      );
    });

    test('an ordering across unlike types admits nothing', () {
      final scope = BeakFieldFilter.forKey(
        'rating',
        BeakOperator.gt,
        BeakValue.of('3'),
      );
      expect(beakScopeAdmits(scope, _note({'rating': 4})), isFalse);
    });

    test('strings and instants order and compare by value', () {
      final moment = DateTime.utc(2026, 1, 2, 3);
      expect(
        beakScopeAdmits(
          BeakFieldFilter.forKey('title', BeakOperator.gt, BeakValue.of('b')),
          _note({'title': 'c'}),
        ),
        isTrue,
      );
      expect(
        beakScopeAdmits(
          BeakFieldFilter.forKey(
            'created_at',
            BeakOperator.eq,
            BeakValue.of(moment),
          ),
          _note({'created_at': moment.toLocal()}),
        ),
        isTrue,
      );
      expect(
        beakScopeAdmits(
          BeakFieldFilter.forKey(
            'created_at',
            BeakOperator.lt,
            BeakValue.of(moment),
          ),
          _note({'created_at': moment.subtract(const Duration(hours: 1))}),
        ),
        isTrue,
      );
    });

    test('a list operator without a list is a scope it cannot decide', () {
      for (final operator in [BeakOperator.inList, BeakOperator.notInList]) {
        expect(
          () => beakScopeAdmits(
            BeakFieldFilter.forKey('author_id', operator, BeakValue.of('a1')),
            _note({'author_id': 'a1'}),
          ),
          throwsA(isA<BeakValidationException>()),
        );
      }
    });

    test('a condition only the database can decide is refused', () {
      for (final scope in <BeakFilter>[
        BeakFieldFilter.forKey(
          'title',
          BeakOperator.contains,
          BeakValue.of('draft'),
        ),
        BeakRelationFilter('author', NoteModel.authorId.eq('a1')),
      ]) {
        expect(
          () => beakScopeAdmits(scope, _note({'title': 'a draft'})),
          throwsA(isA<BeakValidationException>()),
        );
      }
    });
  });

  group('beakScopeColumnKeys', () {
    test('reads the columns the scope names', () {
      final scope = BeakAndFilter([
        NoteModel.authorId.eq('a1'),
        BeakOrFilter([
          BeakFieldFilter.forKey('rating', BeakOperator.gt, BeakValue.of(1)),
        ]),
      ]);
      expect(beakScopeColumnKeys(scope, const NoteModel()), {
        'author_id',
        'rating',
      });
      expect(beakScopeColumnKeys(null, const NoteModel()), isEmpty);
    });

    test('a condition through a belongs-to reads its foreign key', () {
      expect(
        beakScopeColumnKeys(
          BeakRelationFilter('author', NoteModel.authorId.eq('a1')),
          const NoteModel(),
        ),
        {'author_id'},
      );
      expect(
        beakScopeColumnKeys(
          BeakFieldFilter.forKey(
            'author.name',
            BeakOperator.eq,
            BeakValue.of('x'),
          ),
          const NoteModel(),
        ),
        {'author_id'},
      );
    });
  });
}
