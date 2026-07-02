import 'package:test/test.dart';
import 'package:worm/src/cli/cli_naming.dart';

void main() {
  group('pascalToSnake', () {
    test('converts PascalCase to snake_case', () {
      expect(pascalToSnake('User'), 'user');
      expect(pascalToSnake('BlogPost'), 'blog_post');
      expect(pascalToSnake('HTTPServer'), 'h_t_t_p_server');
    });
  });

  group('tableNameFor', () {
    test('appends s when not ending in y', () {
      expect(tableNameFor('User'), 'users');
      expect(tableNameFor('BlogPost'), 'blog_posts');
    });
    test('replaces trailing y with ies', () {
      expect(tableNameFor('Story'), 'stories');
    });
    test('leaves trailing s alone', () {
      expect(tableNameFor('News'), 'news');
    });
  });

  group('snakeToPascal', () {
    test('converts snake_case to PascalCase', () {
      expect(snakeToPascal('create_users_table'), 'CreateUsersTable');
      expect(snakeToPascal('user'), 'User');
    });
  });

  group('migrationTimestamp', () {
    test('produces yyyymmdd_hhmmss', () {
      final ts = migrationTimestamp(DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(ts, '20260102_030405');
    });
  });
}
