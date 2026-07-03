import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
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

    test('rejects models with more form fields than slots', () {
      expect(
        () => BeakFormController(model: const _WideModel()),
        throwsA(isA<BeakConfigurationException>()),
      );
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
  });

  group('buildData', () {
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

/// A model with more form columns than the slot enum offers.
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
