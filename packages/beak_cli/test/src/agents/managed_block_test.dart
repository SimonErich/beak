import 'package:beak_cli/src/agents/beak_managed_block.dart';
import 'package:test/test.dart';

void main() {
  const String begin = '<!-- BEGIN:beak-agent-rules -->';
  const String end = '<!-- END:beak-agent-rules -->';
  const String block = '$begin\n## Beak\n\nRead the docs.\n$end';
  const String otherBlock = '$begin\n## Beak\n\nRead the new docs.\n$end';

  /// The file a result holds, failing when it is a refusal.
  String contentOf(BeakBlockResult result) => switch (result) {
    BeakBlockOk(:final content) => content,
    BeakBlockDamaged(:final reason) => fail('refused: $reason'),
  };

  /// The content of a successful upsert.
  String upserted(String? existing, [String content = block]) => contentOf(
    BeakManagedBlock.upsert(existing, content, title: 'Acme Admin'),
  );

  /// The reason of a refused upsert.
  String refused(String existing) =>
      switch (BeakManagedBlock.upsert(existing, block, title: 'Acme Admin')) {
        BeakBlockDamaged(:final reason) => reason,
        BeakBlockOk() => fail('expected a refusal'),
      };

  /// The content of a successful removal.
  String removed(String existing) =>
      contentOf(BeakManagedBlock.remove(existing));

  test('the markers are the ones the docs promise', () {
    expect(BeakManagedBlock.begin, begin);
    expect(BeakManagedBlock.end, end);
  });

  group('upsert into no file', () {
    test('writes the new-file template', () {
      expect(
        upserted(null),
        '# Acme Admin\n'
        '\n'
        '$block\n'
        '\n'
        '## This project\n'
        '\n'
        '<!-- Your conventions: domain words, who uses the panel, what "done" '
        'means here.\n'
        'Beak only edits between the markers above. -->\n',
      );
    });

    test('treats an empty or blank file as no file', () {
      expect(upserted(''), upserted(null));
      expect(upserted('  \n\n'), upserted(null));
    });
  });

  group('upsert into a file without markers', () {
    test('appends after one blank line and never reorders', () {
      expect(
        upserted('# Mine\n\nMy rules.\n'),
        '# Mine\n\nMy rules.\n\n$block\n',
      );
    });

    test('adds the blank line a file without a final newline lacks', () {
      expect(upserted('# Mine\nMy rules.'), '# Mine\nMy rules.\n\n$block\n');
    });

    test('does not double a blank line that is already there', () {
      expect(upserted('# Mine\n\n'), '# Mine\n\n$block\n');
    });

    test('keeps the text of the file byte for byte', () {
      const String mine = '# Mine\n\n\tTabs   and trailing spaces  \n\n\n';
      expect(upserted(mine), startsWith(mine));
    });
  });

  group('upsert into a file with the block', () {
    test('replaces between the markers and nothing else', () {
      const String before = '# Mine\n\nIntro.\n\n';
      const String after = '\n\n## Later\n\nMore  text \n';
      const String existing = '$before$block$after';

      expect(upserted(existing, otherBlock), '$before$otherBlock$after');
    });

    test('replaces a block another version wrote', () {
      const String existing = '# T\n\n$begin\nold rules\n$end\n\nmine\n';

      expect(upserted(existing), '# T\n\n$block\n\nmine\n');
    });

    test('leaves a file whose block is current exactly as it was', () {
      const String existing = 'a\n\n$block\n\nb\n';

      expect(upserted(existing), existing);
    });

    test('is idempotent for every shape of input', () {
      for (final String? input in [
        null,
        '',
        '# Mine\n',
        'no newline',
        'a\r\nb\r\n',
        'a\n\n$block\n\nb\n',
        block,
        'x\r\n\r\n$block\r\ny\r\n',
      ]) {
        final String once = upserted(input);

        expect(upserted(once), once, reason: 'input: ${input?.length}');
      }
    });

    test('keeps a block at the very start or the very end of the file', () {
      expect(upserted(block, otherBlock), otherBlock);
      expect(upserted('$block\n', otherBlock), '$otherBlock\n');
      expect(upserted('intro\n$block', otherBlock), 'intro\n$otherBlock');
    });

    test('ignores markers that are not alone on their line', () {
      const String prose = 'Mention $begin in a sentence.\n';
      expect(upserted(prose), '$prose\n$block\n');
    });

    test('ignores indented markers, which are quoted, not Beak\'s', () {
      const String quoted = '  $begin\n  $end\n';
      expect(upserted(quoted), '$quoted\n$block\n');
    });
  });

  group('CRLF files', () {
    test('append in CRLF', () {
      expect(
        upserted('# Mine\r\n\r\nRules.\r\n'),
        '# Mine\r\n\r\nRules.\r\n\r\n${block.replaceAll('\n', '\r\n')}\r\n',
      );
    });

    test('replace keeps every CRLF outside the markers', () {
      const String before = '# Mine\r\n\r\n';
      const String after = '\r\n\r\nTail\r\n';
      final String crlfBlock = block.replaceAll('\n', '\r\n');
      final String crlfOther = otherBlock.replaceAll('\n', '\r\n');

      expect(
        upserted('$before$crlfBlock$after', otherBlock),
        '$before$crlfOther$after',
      );
    });

    test(
      'a file with LF and one stray CRLF is treated by its first ending',
      () {
        expect(upserted('a\nb\r\nc\n'), 'a\nb\r\nc\n\n$block\n');
      },
    );
  });

  group('damaged markers', () {
    test('a BEGIN with no END is refused', () {
      expect(refused('x\n$begin\ny\n'), contains('no END marker'));
    });

    test('an END with no BEGIN is refused', () {
      expect(refused('x\n$end\ny\n'), contains('no BEGIN marker'));
    });

    test('END before BEGIN is refused', () {
      expect(
        refused('$end\nmid\n$begin\n'),
        contains('END marker comes before'),
      );
    });

    test('two blocks are refused', () {
      expect(refused('$block\n\n$block\n'), contains('more than one'));
    });

    test('two BEGIN markers and one END are refused', () {
      expect(refused('$begin\n$begin\n$end\n'), contains('more than one'));
    });

    test('a refusal names the fix', () {
      expect(refused('$begin\n'), contains('fix or delete the markers'));
    });
  });

  group('find', () {
    test('reports no block, the block, or damage', () {
      expect(BeakManagedBlock.find('# Mine\n'), isA<BeakBlockMissing>());
      expect(BeakManagedBlock.find('a\n$block\nb\n'), isA<BeakBlockPresent>());
      expect(BeakManagedBlock.find('$begin\n'), isA<BeakBlockDamaged>());
    });

    test('returns the block text, markers included, in LF', () {
      final BeakBlockLookup found = BeakManagedBlock.find(
        'a\r\n${block.replaceAll('\n', '\r\n')}\r\nb\r\n',
      );

      expect(switch (found) {
        BeakBlockPresent(:final text) => text,
        _ => fail('expected the block'),
      }, block);
    });
  });

  group('remove', () {
    test('undoes an append, byte for byte', () {
      const String mine = '# Mine\n\nRules.\n';

      expect(removed(upserted(mine)), mine);
    });

    test('undoes an append to a file without a final newline', () {
      const String mine = 'Rules.';
      expect(removed(upserted(mine)), 'Rules.\n');
    });

    test('keeps one blank line between what surrounded the block', () {
      expect(removed('a\n\n$block\n\nb\n'), 'a\n\nb\n');
    });

    test('removes a block at the start of the file with its blank line', () {
      expect(removed('$block\n\nb\n'), 'b\n');
    });

    test('a file that was only the block becomes empty', () {
      expect(removed('$block\n'), isEmpty);
    });

    test('works on CRLF files', () {
      final String crlf = block.replaceAll('\n', '\r\n');

      expect(removed('a\r\n\r\n$crlf\r\n\r\nb\r\n'), 'a\r\n\r\nb\r\n');
    });

    test('a file without a block comes back unchanged', () {
      expect(removed('# Mine\n'), '# Mine\n');
    });

    test('refuses damaged markers', () {
      expect(BeakManagedBlock.remove('$begin\n'), isA<BeakBlockDamaged>());
    });
  });

  test('a block without the markers is a programming error', () {
    expect(
      () => BeakManagedBlock.upsert(null, 'text', title: 'T'),
      throwsArgumentError,
    );
  });
}
