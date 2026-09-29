import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/src/form/beak_form_controller_builder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  BeakFormController controller(
    BeakModel model, {
    List<BeakFormSection>? sections,
  }) {
    final built = BeakFormController(model: model, sections: sections);
    addTearDown(built.dispose);
    return built;
  }

  test(
    'prefill distinguishes absent defaults from explicit nullable values',
    () {
      final form = controller(const ArticleModel());
      form.prefill(BeakRecord.fromRow({'status': null, 'title': 'First'}));
      expect(form.valueOf<Object>(ArticleColumns.status), isNull);
      form.setValue(ArticleColumns.title, 'Unsent title');
      form.prefill(const BeakRecord(values: {}));
      expect(form.valueOf<Object>(ArticleColumns.status), ArticleStatus.draft);
      expect(form.valueOf<Object>(ArticleColumns.title), isNull);
      expect(form.isDirty, isFalse);
    },
  );

  group('field registration', () {
    test('registers a typed field per form column', () {
      final form = controller(const ArticleModel());

      expect(
        form.get<ArticleStatus>(form.slotOf(ArticleColumns.status)),
        ArticleStatus.draft,
      );
      expect(form.get<bool>(form.slotOf(ArticleColumns.active)), isFalse);
      expect(form.get<String>(form.slotOf(ArticleColumns.title)), isNull);
      expect(form.get<num>(form.slotOf(ArticleColumns.price)), isNull);
      expect(
        form.get<DateTime>(form.slotOf(ArticleColumns.publishedAt)),
        isNull,
      );
    });

    test('skips the primary key and custom columns', () {
      final form = controller(const ArticleModel());

      expect(
        () => form.slotOf(ArticleColumns.id),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => form.slotOf(ArticleColumns.badge),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('claims belongs-to foreign keys as relation picker slots', () {
      final form = controller(const ArticleModel());

      expect(
        form.slotOfForeignKey(ArticleRelations.category),
        form.slotOf(ArticleColumns.categoryId),
      );
    });

    test('a model past the default pool is told how to widen it', () {
      expect(
        () => BeakFormController(model: const _WideModel()),
        throwsA(
          isA<BeakConfigurationException>().having(
            (exception) => exception.message,
            'message',
            allOf(contains('visibleOn'), contains('formSlots')),
          ),
        ),
      );
    });

    test('a model that supplies its own pool has no ceiling', () {
      // 60 columns is an ordinary wide table, and far past the default pool.
      // A generated model always supplies its own, sized to itself.
      final form = controller(const _WidePooledModel());

      expect(form.hasFieldForKey('c0'), isTrue);
      expect(form.hasFieldForKey('c59'), isTrue);
      form.setValue(_WidePooledModel.columnAt(59), 'last');
      expect(form.valueOf<String>(_WidePooledModel.columnAt(59)), 'last');
    });
  });

  group('rule mirroring', () {
    test('client validation reproduces the server rule messages', () async {
      final form = controller(const ArticleModel())
        ..setValue(ArticleColumns.price, -1);

      expect(await form.validate(), isFalse);
      expect(form.getErrors(form.slotOf(ArticleColumns.title)), [
        'This field is required.',
      ]);
      expect(form.getErrors(form.slotOf(ArticleColumns.price)), [
        'Must be at least 0.',
      ]);
      expect(form.getErrors(form.slotOf(ArticleColumns.categoryId)), [
        'This field is required.',
      ]);
    });

    test('content rules skip absent values on optional fields', () async {
      final form = controller(const ArticleModel())
        ..setValue(ArticleColumns.title, 'Fine')
        ..setValue(ArticleColumns.categoryId, 'c1');

      expect(await form.validate(), isTrue);

      form.setValue(ArticleColumns.title, 'A headline far too long to pass');
      expect(await form.validate(), isFalse);
      expect(form.getErrors(form.slotOf(ArticleColumns.title)), [
        'Must be at most 20 characters.',
      ]);
    });

    test('content rules validate a submitted whitespace string, matching '
        'the server', () async {
      // Absent (null) still passes — presence is BeakRequired's job.
      expect(await controller(const _EmailModel()).validate(), isTrue);

      // A whitespace-only string is a *submitted* value the server would
      // reject, so the client mirror must reject it too (byte-identical).
      final form = controller(const _EmailModel())
        ..setValue(_emailColumn, '   ');
      expect(await form.validate(), isFalse);
      expect(
        form.getErrors(form.slotOf(_emailColumn)),
        const BeakEmail().validate('   ') == null
            ? anything
            : [const BeakEmail().validate('   ')],
      );
    });
  });

  group('buildData', () {
    test('complete command mode includes untouched nulls', () {
      final form = BeakFormController(
        model: const ArticleModel(),
        valueMode: BeakFormValueMode.complete,
      );
      addTearDown(form.dispose);
      expect(form.buildData()['summary'], const BeakNullValue());
    });

    test('patch mode sends only changed fields including clears', () {
      final form = BeakFormController(
        model: const ArticleModel(),
        valueMode: BeakFormValueMode.changes,
      )..prefill(BeakRecord.fromRow({'title': 'Same', 'summary': 'Old'}));
      addTearDown(form.dispose);
      expect(form.buildData().values, isEmpty);
      form.setValue<String>(ArticleColumns.summary, null);
      expect(form.buildData().values, {'summary': const BeakNullValue()});
    });
    test('preserves cleared values and explicit nullable booleans', () {
      final form = controller(const ArticleModel())
        ..prefill(BeakRecord.fromRow({'summary': 'Old', 'active': null}))
        ..setValue<String>(ArticleColumns.summary, null);

      expect(form.buildData()['summary'], const BeakNullValue());
      expect(form.buildData()['active'], const BeakNullValue());
      expect(form.buildData()['body'], isNull);
    });

    test('yields a typed record and omits unset values', () {
      final form = controller(const ArticleModel())
        ..setValue(ArticleColumns.title, 'Hello')
        ..setValue(ArticleColumns.price, 12.5)
        ..setValue(ArticleColumns.stock, 3)
        ..setValue(ArticleColumns.publishedAt, DateTime(2026, 1, 2))
        ..setValue(ArticleColumns.brandColor, const Color(0xFF663399))
        ..setValue(ArticleColumns.meta, '{"a":1}')
        ..setValue(ArticleColumns.avatar, 'articles/avatars/x.png')
        ..setValue(ArticleColumns.categoryId, 'c1');

      final record = form.buildData();

      expect(record['title'], const BeakStringValue('Hello'));
      expect(record['price'], const BeakDoubleValue(12.5));
      expect(record['stock'], const BeakIntValue(3));
      expect(record['active'], const BeakBoolValue(false));
      expect(record['status'], const BeakStringValue('draft'));
      expect(record['published_at'], BeakDateTimeValue(DateTime(2026, 1, 2)));
      expect(record['brand_color'], const BeakStringValue('#663399'));
      expect(record['meta'], const BeakStringValue('{"a":1}'));
      expect(record['avatar'], const BeakStringValue('articles/avatars/x.png'));
      expect(record['category_id'], const BeakStringValue('c1'));
      expect(record['summary'], isNull);
      expect(record['body'], isNull);
      expect(record['id'], isNull);
      expect(record['badge'], isNull);
    });
  });

  group('prefill', () {
    test('seeds every field from a record without marking it dirty', () {
      final form = controller(const ArticleModel())
        ..prefill(
          BeakRecord.fromRow({
            'id': 'a1',
            'title': 'One',
            'summary': 'Sum',
            'price': 9.5,
            'stock': 7,
            'active': true,
            'status': 'published',
            'published_at': DateTime(2025, 5, 4),
            'brand_color': '#112233',
            'body': 'Body',
            'meta': '{"k":true}',
            'avatar': 'articles/avatars/a.png',
            'category_id': 'c9',
          }),
        );

      expect(form.get<String>(form.slotOf(ArticleColumns.title)), 'One');
      expect(form.get<num>(form.slotOf(ArticleColumns.price)), 9.5);
      expect(form.get<num>(form.slotOf(ArticleColumns.stock)), 7);
      expect(form.get<bool>(form.slotOf(ArticleColumns.active)), isTrue);
      expect(
        form.get<ArticleStatus>(form.slotOf(ArticleColumns.status)),
        ArticleStatus.published,
      );
      expect(
        form.get<DateTime>(form.slotOf(ArticleColumns.publishedAt)),
        DateTime(2025, 5, 4),
      );
      expect(
        form.get<Color>(form.slotOf(ArticleColumns.brandColor)),
        const Color(0xFF112233),
      );
      expect(
        form.get<Object>(form.slotOfForeignKey(ArticleRelations.category)),
        'c9',
      );
      expect(form.isFieldDirty(form.slotOf(ArticleColumns.title)), isFalse);

      final record = form.buildData();
      expect(record['status'], const BeakStringValue('published'));
      expect(record['brand_color'], const BeakStringValue('#112233'));
      expect(record['active'], const BeakBoolValue(true));
    });

    test('decodes ISO timestamp strings into date fields', () {
      final form = controller(const ArticleModel())
        ..prefill(
          BeakRecord.fromRow(const {'published_at': '2025-05-04T10:30:00'}),
        );

      expect(
        form.get<DateTime>(form.slotOf(ArticleColumns.publishedAt)),
        DateTime(2025, 5, 4, 10, 30),
      );
    });
  });

  group('server errors', () {
    test('maps 422 field errors onto slots and unknown keys globally', () {
      final form = controller(const ArticleModel())
        ..applyServerErrors({
          'title': ['Already taken.'],
          'ghost': ['No such field.'],
        });

      expect(form.getErrors(form.slotOf(ArticleColumns.title)), [
        'Already taken.',
      ]);
      expect(form.globalErrors, ['ghost: No such field.']);
    });
  });

  group('sections', () {
    test('limit the form to their columns and drive visibility', () {
      final form = controller(
        const ArticleModel(),
        sections: [
          const BeakFormSection(
            title: 'Basics',
            columns: [ArticleColumns.title, ArticleColumns.active],
          ),
          BeakFormSection(
            title: 'Pricing',
            columns: const [ArticleColumns.price],
            visibleWhen: (values) =>
                values.valueOf<bool>(ArticleColumns.active) ?? false,
          ),
        ],
      );

      expect(
        () => form.slotOf(ArticleColumns.summary),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(form.isFieldVisible(form.slotOf(ArticleColumns.price)), isFalse);

      form.set(form.slotOf(ArticleColumns.active), true);
      expect(form.isFieldVisible(form.slotOf(ArticleColumns.price)), isTrue);
    });
  });
}

/// An optional string column carrying only a content rule (no
/// [BeakRequired]) — the shape that surfaced the client/server whitespace
/// mismatch.
const _emailColumn = BeakStringColumn(
  key: 'email',
  label: 'Email',
  rules: [BeakEmail()],
);

/// A one-field model over [_emailColumn].
final class _EmailModel extends BeakModel {
  const _EmailModel();

  @override
  String get table => 'contacts';

  @override
  String get displayColumnKey => 'email';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    _emailColumn,
  ];
}

/// The pool a wide model brings, the way a generated one does.
enum _WideSlots {
  s0,
  s1,
  s2,
  s3,
  s4,
  s5,
  s6,
  s7,
  s8,
  s9,
  s10,
  s11,
  s12,
  s13,
  s14,
  s15,
  s16,
  s17,
  s18,
  s19,
  s20,
  s21,
  s22,
  s23,
  s24,
  s25,
  s26,
  s27,
  s28,
  s29,
  s30,
  s31,
  s32,
  s33,
  s34,
  s35,
  s36,
  s37,
  s38,
  s39,
  s40,
  s41,
  s42,
  s43,
  s44,
  s45,
  s46,
  s47,
  s48,
  s49,
  s50,
  s51,
  s52,
  s53,
  s54,
  s55,
  s56,
  s57,
  s58,
  s59,
}

/// A 60-column model carrying a pool big enough for itself.
final class _WidePooledModel extends BeakModel {
  const _WidePooledModel();

  /// The column at [index], for addressing a field the test set.
  static BeakColumn columnAt(int index) =>
      BeakStringColumn(key: 'c$index', label: 'C$index');

  @override
  String get table => 'wide_pooled';

  @override
  String get displayColumnKey => 'c0';

  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    for (var index = 0; index < 60; index++) columnAt(index),
  ];

  @override
  List<Enum> get formSlots => _WideSlots.values;
}

/// A model with more form columns than the default pool offers.
final class _WideModel extends BeakModel {
  const _WideModel();

  @override
  String get table => 'wide';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    for (var i = 0; i < 33; i++) BeakStringColumn(key: 'c$i', label: 'C$i'),
  ];
}
