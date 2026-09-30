import 'dart:io';

import 'package:beak_cli/src/agents/beak_workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('beak_workspace_');
    addTearDown(() => tmp.deleteSync(recursive: true));
  });

  /// Writes [content] to [path] under the temp directory.
  Directory write(String path, String content) {
    final file = File(p.join(tmp.path, path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
    return file.parent;
  }

  const String member = 'name: admin\nresolution: workspace\n';

  BeakWorkspace locate(Directory project, {Directory? workspaceRoot}) =>
      BeakWorkspace.locate(project, workspaceRoot: workspaceRoot);

  group('a project that is not a workspace member', () {
    test('is its own workspace root', () {
      final Directory project = write('app/pubspec.yaml', 'name: app\n');
      final BeakWorkspace workspace = locate(project);

      expect(workspace.projectRoot.path, project.path);
      expect(workspace.workspaceRoot.path, project.path);
      expect(workspace.isWorkspaceMember, isFalse);
    });

    test('is standalone even below a directory that holds a workspace', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - other\n');
      final Directory project = write('app/pubspec.yaml', 'name: app\n');

      expect(locate(project).isWorkspaceMember, isFalse);
    });

    test('is standalone without a pubspec at all', () {
      final Directory project = Directory(p.join(tmp.path, 'nothing'))
        ..createSync();

      expect(locate(project).workspaceRoot.path, project.path);
    });

    test('is standalone when the pubspec is not YAML', () {
      final Directory project = write('app/pubspec.yaml', 'a: [unclosed\n');

      expect(locate(project).workspaceRoot.path, project.path);
    });

    test('is standalone when the pubspec is not a mapping', () {
      final Directory project = write('app/pubspec.yaml', '- a\n- b\n');

      expect(locate(project).workspaceRoot.path, project.path);
    });
  });

  group('a workspace member', () {
    test('finds the parent whose workspace list names it', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - admin\n');
      final Directory project = write('admin/pubspec.yaml', member);
      final BeakWorkspace workspace = locate(project);

      expect(workspace.workspaceRoot.path, tmp.path);
      expect(workspace.isWorkspaceMember, isTrue);
    });

    test('finds a root several levels up, for a nested member', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - apps/admin\n');
      write('apps/pubspec.yaml', 'name: apps\n');
      final Directory project = write('apps/admin/pubspec.yaml', member);

      expect(locate(project).workspaceRoot.path, tmp.path);
    });

    test('skips a parent workspace that does not list it', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - apps/admin\n');
      write('apps/pubspec.yaml', 'name: apps\nworkspace:\n  - other\n');
      final Directory project = write('apps/admin/pubspec.yaml', member);

      expect(locate(project).workspaceRoot.path, tmp.path);
    });

    test('matches a glob entry', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - apps/*\n');
      final Directory project = write('apps/admin/pubspec.yaml', member);

      expect(locate(project).workspaceRoot.path, tmp.path);
    });

    test('a glob does not match a deeper path', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - apps/*\n');
      final Directory project = write('apps/a/b/pubspec.yaml', member);

      expect(locate(project).isWorkspaceMember, isFalse);
    });

    test('reads a leading ./ and a trailing / in an entry', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - ./admin/\n');
      final Directory project = write('admin/pubspec.yaml', member);

      expect(locate(project).workspaceRoot.path, tmp.path);
    });

    test('ignores a workspace entry that is not a string', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - 7\n  - admin\n');
      final Directory project = write('admin/pubspec.yaml', member);

      expect(locate(project).workspaceRoot.path, tmp.path);
    });

    test('ignores a workspace key that is not a list', () {
      write('pubspec.yaml', 'name: root\nworkspace: admin\n');
      final Directory project = write('admin/pubspec.yaml', member);

      expect(locate(project).isWorkspaceMember, isFalse);
    });

    test('skips an unreadable parent pubspec', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - apps/admin\n');
      write('apps/pubspec.yaml', 'a: [unclosed\n');
      final Directory project = write('apps/admin/pubspec.yaml', member);

      expect(locate(project).workspaceRoot.path, tmp.path);
    });
  });

  group('the --root override', () {
    test('names the workspace root outright', () {
      write('pubspec.yaml', 'name: root\n');
      final Directory project = write('somewhere/admin/pubspec.yaml', 'x: 1');
      final BeakWorkspace workspace = locate(project, workspaceRoot: tmp);

      expect(workspace.workspaceRoot.path, tmp.path);
      expect(workspace.isWorkspaceMember, isTrue);
    });
  });

  group('derived paths', () {
    test('the package config and the docs sit under .dart_tool', () {
      final Directory project = write('app/pubspec.yaml', 'name: app\n');
      final BeakWorkspace workspace = locate(project);

      expect(
        workspace.packageConfigFile.path,
        p.join(project.path, '.dart_tool', 'package_config.json'),
      );
      expect(
        workspace.docsDirectory.path,
        p.join(project.path, '.dart_tool', 'beak', 'docs'),
      );
      expect(BeakWorkspace.docsPath, '.dart_tool/beak/docs');
    });

    test('a package config exists only once pub get has written it', () {
      final Directory project = write('app/pubspec.yaml', 'name: app\n');
      expect(locate(project).hasPackageConfig, isFalse);

      write('app/.dart_tool/package_config.json', '{}');
      expect(locate(project).hasPackageConfig, isTrue);
    });

    test('the project path relative to the workspace root, in posix form', () {
      write('pubspec.yaml', 'name: root\nworkspace:\n  - apps/admin\n');
      final Directory project = write('apps/admin/pubspec.yaml', member);

      expect(locate(project).projectPathInWorkspace, 'apps/admin');
      expect(
        locate(write('pubspec.yaml', 'name: solo\n')).projectPathInWorkspace,
        '.',
      );
    });
  });
}
