import 'dart:io';

import 'package:beak_cli/src/agents/beak_claude_md.dart';
import 'package:beak_cli/src/agents/beak_managed_block.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('beak_claude_md_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  File write(String path, String content) => File(p.join(dir.path, path))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  group('claudeMdImportsAgents', () {
    test('accepts the import on a line of its own', () {
      for (final content in [
        '@AGENTS.md\n',
        '@./AGENTS.md\n',
        '@AGENTS.md',
        '@AGENTS.md   \n',
        '# Notes\n\n@AGENTS.md\n\nMore.\n',
        '@AGENTS.md\r\n',
      ]) {
        expect(claudeMdImportsAgents(content), isTrue, reason: content);
      }
    });

    test('rejects anything else', () {
      for (final content in [
        '',
        'See @AGENTS.md for more.\n',
        '  @AGENTS.md\n',
        '@docs/AGENTS.md\n',
        '@../AGENTS.md\n',
        '@AGENTS.markdown\n',
        'AGENTS.md\n',
      ]) {
        expect(claudeMdImportsAgents(content), isFalse, reason: content);
      }
    });
  });

  group('BeakClaudeMd.plan', () {
    test(
      'creates CLAUDE.md when neither CLAUDE.md nor .claude/CLAUDE.md exist',
      () {
        write('AGENTS.md', 'rules\n');

        expect(BeakClaudeMd.plan(dir), isA<BeakClaudeCreate>());
      },
    );

    test('leaves a CLAUDE.md that imports AGENTS.md', () {
      write('AGENTS.md', 'rules\n');
      write('CLAUDE.md', '@AGENTS.md\n');

      expect(BeakClaudeMd.plan(dir), isA<BeakClaudeSatisfied>());
    });

    test('leaves a CLAUDE.md that is a symlink to AGENTS.md', () {
      write('AGENTS.md', 'rules\n');
      Link(p.join(dir.path, 'CLAUDE.md')).createSync('AGENTS.md');

      expect(BeakClaudeMd.plan(dir), isA<BeakClaudeSatisfied>());
    }, testOn: '!windows');

    test('leaves a symlink to AGENTS.md that does not resolve yet', () {
      Link(p.join(dir.path, 'CLAUDE.md')).createSync('AGENTS.md');

      expect(BeakClaudeMd.plan(dir), isA<BeakClaudeSatisfied>());
    }, testOn: '!windows');

    test('leaves an AGENTS.md that is a symlink to CLAUDE.md', () {
      write('CLAUDE.md', 'rules\n');
      Link(p.join(dir.path, 'AGENTS.md')).createSync('CLAUDE.md');

      expect(BeakClaudeMd.plan(dir), isA<BeakClaudeSatisfied>());
    }, testOn: '!windows');

    test('carries the block into a CLAUDE.md without the import', () {
      write('AGENTS.md', 'rules\n');
      write('CLAUDE.md', '# My Claude notes\n');

      final BeakClaudePlan plan = BeakClaudeMd.plan(dir);

      expect(switch (plan) {
        BeakClaudeCarry(:final existing) => existing,
        _ => fail('expected the block to be carried'),
      }, '# My Claude notes\n');
    });

    test('leaves a project whose only CLAUDE.md is .claude/CLAUDE.md', () {
      write('AGENTS.md', 'rules\n');
      write('.claude/CLAUDE.md', '# Mine\n');

      expect(BeakClaudeMd.plan(dir), isA<BeakClaudeSatisfied>());
    });
  });

  group('BeakClaudeMd.pairing', () {
    test('is paired when CLAUDE.md imports AGENTS.md', () {
      write('AGENTS.md', 'x\n');
      write('CLAUDE.md', '@AGENTS.md\n');

      expect(BeakClaudeMd.pairing(dir), BeakClaudePairing.paired);
    });

    test('is paired when CLAUDE.md carries the block', () {
      write('AGENTS.md', 'x\n');
      write(
        'CLAUDE.md',
        '${BeakManagedBlock.begin}\nx\n${BeakManagedBlock.end}\n',
      );

      expect(BeakClaudeMd.pairing(dir), BeakClaudePairing.paired);
    });

    test('is paired when CLAUDE.md is the same file as AGENTS.md', () {
      write('AGENTS.md', 'x\n');
      Link(p.join(dir.path, 'CLAUDE.md')).createSync('AGENTS.md');

      expect(BeakClaudeMd.pairing(dir), BeakClaudePairing.paired);
    }, testOn: '!windows');

    test('is unread when no CLAUDE.md exists', () {
      write('AGENTS.md', 'x\n');

      expect(BeakClaudeMd.pairing(dir), BeakClaudePairing.unread);
    });

    test('is unread when CLAUDE.md neither imports nor carries the block', () {
      write('AGENTS.md', 'x\n');
      write('CLAUDE.md', 'other\n');

      expect(BeakClaudeMd.pairing(dir), BeakClaudePairing.unread);
    });

    test('is paired through .claude/CLAUDE.md with the right import', () {
      write('AGENTS.md', 'x\n');
      write('.claude/CLAUDE.md', '@../AGENTS.md\n');

      expect(BeakClaudeMd.pairing(dir), BeakClaudePairing.paired);
    });

    test('flags the import that resolves next to .claude/CLAUDE.md', () {
      write('AGENTS.md', 'x\n');
      write('.claude/CLAUDE.md', '@AGENTS.md\n');

      expect(
        BeakClaudeMd.pairing(dir),
        BeakClaudePairing.brokenDotClaudeImport,
      );
    });

    test('a .claude/AGENTS.md makes the plain import resolve', () {
      write('AGENTS.md', 'x\n');
      write('.claude/AGENTS.md', 'x\n');
      write('.claude/CLAUDE.md', '@AGENTS.md\n');

      expect(BeakClaudeMd.pairing(dir), BeakClaudePairing.paired);
    });

    test('is unread when .claude/CLAUDE.md does not mention AGENTS.md', () {
      write('AGENTS.md', 'x\n');
      write('.claude/CLAUDE.md', '# Mine\n');

      expect(BeakClaudeMd.pairing(dir), BeakClaudePairing.unread);
    });

    test('the root CLAUDE.md wins over .claude/CLAUDE.md', () {
      write('AGENTS.md', 'x\n');
      write('CLAUDE.md', '@AGENTS.md\n');
      write('.claude/CLAUDE.md', '@AGENTS.md\n');

      expect(BeakClaudeMd.pairing(dir), BeakClaudePairing.paired);
    });
  });

  test('the file Beak creates imports AGENTS.md and nothing else', () {
    expect(BeakClaudeMd.importOnly, '@AGENTS.md\n');
    expect(claudeMdImportsAgents(BeakClaudeMd.importOnly), isTrue);
  });
}
