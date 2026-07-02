import 'package:test/test.dart';
import 'package:worm/src/naming/naming.dart';

void main() {
  group('NamingConvention.toSnakeCase', () {
    test('simple camelCase', () {
      expect(NamingConvention.toSnakeCase('userId'), 'user_id');
    });

    test('multi-word camelCase', () {
      expect(NamingConvention.toSnakeCase('createdAt'), 'created_at');
    });

    test('consecutive caps acronym start', () {
      expect(NamingConvention.toSnakeCase('HTMLContent'), 'html_content');
    });

    test('acronym mid-word', () {
      expect(
        NamingConvention.toSnakeCase('parseHTMLContent'),
        'parse_html_content',
      );
    });

    test('acronym followed by word', () {
      expect(NamingConvention.toSnakeCase('URLParser'), 'url_parser');
    });

    test('all-caps acronym', () {
      expect(NamingConvention.toSnakeCase('URL'), 'url');
    });

    test('single word', () {
      expect(NamingConvention.toSnakeCase('id'), 'id');
    });

    test('two-char camelCase', () {
      expect(NamingConvention.toSnakeCase('aB'), 'a_b');
    });

    test('three-char all-caps', () {
      expect(NamingConvention.toSnakeCase('ABC'), 'abc');
    });

    test('already snake_case is idempotent', () {
      expect(NamingConvention.toSnakeCase('already_snake'), 'already_snake');
    });

    test('empty string returns empty', () {
      expect(NamingConvention.toSnakeCase(''), '');
    });

    test('double application is idempotent', () {
      final inputs = [
        'userId',
        'HTMLContent',
        'parseHTMLContent',
        'URLParser',
        'URL',
        'createdAt',
        'id',
        'aB',
        'ABC',
        'already_snake',
        '',
      ];

      for (final input in inputs) {
        final once = NamingConvention.toSnakeCase(input);
        final twice = NamingConvention.toSnakeCase(once);
        expect(
          twice,
          once,
          reason:
              'toSnakeCase not idempotent '
              'for "$input"',
        );
      }
    });
  });

  group('NamingConvention.toCamelCase', () {
    test('simple snake_case', () {
      expect(NamingConvention.toCamelCase('user_id'), 'userId');
    });

    test('multi-word snake_case', () {
      expect(NamingConvention.toCamelCase('html_content'), 'htmlContent');
    });

    test('timestamp field', () {
      expect(NamingConvention.toCamelCase('created_at'), 'createdAt');
    });

    test('single word', () {
      expect(NamingConvention.toCamelCase('id'), 'id');
    });

    test('empty string returns empty', () {
      expect(NamingConvention.toCamelCase(''), '');
    });
  });

  group('NamingConvention.tableName', () {
    test('simple model name', () {
      expect(NamingConvention.tableName('User'), 'users');
    });

    test('two-word PascalCase', () {
      expect(NamingConvention.tableName('BlogPost'), 'blog_posts');
    });

    test('another two-word PascalCase', () {
      expect(NamingConvention.tableName('PostComment'), 'post_comments');
    });

    test('empty string returns empty', () {
      expect(NamingConvention.tableName(''), '');
    });

    test('sibilant endings take -es', () {
      expect(NamingConvention.tableName('Box'), 'boxes');
      expect(NamingConvention.tableName('Class'), 'classes');
      expect(NamingConvention.tableName('Dish'), 'dishes');
      expect(NamingConvention.tableName('Match'), 'matches');
    });

    test('-y after a consonant becomes -ies; after a vowel adds -s', () {
      expect(NamingConvention.tableName('Category'), 'categories');
      expect(NamingConvention.tableName('Day'), 'days');
    });

    test('-f / -fe becomes -ves', () {
      expect(NamingConvention.tableName('Wolf'), 'wolves');
      expect(NamingConvention.tableName('Knife'), 'knives');
    });

    test('irregular plurals', () {
      expect(NamingConvention.tableName('Person'), 'people');
      expect(NamingConvention.tableName('Child'), 'children');
      expect(NamingConvention.tableName('Mouse'), 'mice');
    });

    test('only the last snake segment is pluralized', () {
      expect(NamingConvention.tableName('BlogCategory'), 'blog_categories');
    });

    test('uncountable words are unchanged', () {
      expect(NamingConvention.tableName('Series'), 'series');
      expect(NamingConvention.tableName('Sheep'), 'sheep');
    });
  });

  group('NamingConvention.pivotTableName', () {
    test('joins singular snake names alphabetically', () {
      expect(NamingConvention.pivotTableName('User', 'Role'), 'role_user');
      expect(NamingConvention.pivotTableName('Role', 'User'), 'role_user');
    });

    test('multi-word class names', () {
      expect(
        NamingConvention.pivotTableName('BlogPost', 'Tag'),
        'blog_post_tag',
      );
    });
  });
}
