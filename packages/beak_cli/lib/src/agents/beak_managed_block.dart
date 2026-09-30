/// What an edit of a managed block produced.
sealed class BeakBlockResult {
  const BeakBlockResult();
}

/// An edit that succeeded, carrying the file's new [content].
final class BeakBlockOk extends BeakBlockResult {
  /// Creates a successful result.
  const BeakBlockOk(this.content);

  /// The whole file after the edit.
  final String content;
}

/// An edit refused because the markers in the file cannot be trusted.
///
/// Nothing is written: guessing which of two blocks the user meant would
/// destroy their text.
final class BeakBlockDamaged extends BeakBlockResult
    implements BeakBlockLookup {
  /// Creates a refusal explaining [reason].
  const BeakBlockDamaged(this.reason);

  /// What is wrong with the markers, and how to fix it.
  final String reason;
}

/// Where the managed block is in a file.
sealed class BeakBlockLookup {
  const BeakBlockLookup();
}

/// The file has no managed block.
final class BeakBlockMissing extends BeakBlockLookup {
  /// Creates the result.
  const BeakBlockMissing();
}

/// The file has exactly one managed block.
final class BeakBlockPresent extends BeakBlockLookup {
  /// Creates a result carrying the block's [text].
  const BeakBlockPresent(this.text);

  /// The block from its BEGIN marker to its END marker, both included, with
  /// LF line endings whatever the file uses.
  final String text;
}

/// The part of an `AGENTS.md` Beak owns: the text between two marker lines.
///
/// Everything outside the markers belongs to the person who owns the file.
/// So the edits here are byte-exact outside the block, append rather than
/// reorder, keep the file's line endings, and refuse rather than guess when
/// the markers are damaged. All of it is pure text in, text out; reading and
/// writing the file, and skipping the write when nothing changed, is the
/// caller's job.
///
/// ```dart
/// final result = BeakManagedBlock.upsert(existing, block, title: 'Acme');
/// if (result case BeakBlockOk(:final content)) {
///   File('AGENTS.md').writeAsStringSync(content);
/// }
/// ```
abstract final class BeakManagedBlock {
  /// The line that opens the block.
  static const String begin = '<!-- BEGIN:beak-agent-rules -->';

  /// The line that closes the block.
  static const String end = '<!-- END:beak-agent-rules -->';

  /// [existing] with [block] in place of the managed block.
  ///
  /// [block] runs from [begin] to [end], both included, in LF. Without a file
  /// (or with a blank one) the result is the new-file template titled
  /// [title]. With no markers the block is appended after one blank line.
  /// With exactly one ordered pair the text between them, markers included,
  /// is replaced. Any other arrangement of markers is [BeakBlockDamaged].
  ///
  /// Applying the result again yields the same text.
  static BeakBlockResult upsert(
    String? existing,
    String block, {
    required String title,
  }) {
    if (!block.startsWith(begin) || !block.endsWith(end)) {
      throw ArgumentError.value(
        block,
        'block',
        'must run from the BEGIN marker to the END marker',
      );
    }
    if (existing == null || existing.trim().isEmpty) {
      return BeakBlockOk(newFile(title, block));
    }
    final _Scan scan = _scan(existing);
    switch (scan) {
      case _Damaged(:final reason):
        return BeakBlockDamaged(reason);
      case _Absent():
        final String eol = _endOfLineIn(existing);
        final String separator = existing.endsWith('$eol$eol')
            ? ''
            : existing.endsWith(eol)
            ? eol
            : '$eol$eol';
        return BeakBlockOk('$existing$separator${_withEol(block, eol)}$eol');
      case _Found(:final start, :final stop):
        final String eol = _endOfLineAt(existing, start);
        return BeakBlockOk(
          '${existing.substring(0, start)}${_withEol(block, eol)}'
          '${existing.substring(stop)}',
        );
    }
  }

  /// [existing] without the managed block, and without the blank line the
  /// block leaves behind.
  ///
  /// A file without a block comes back unchanged; damaged markers are
  /// refused.
  static BeakBlockResult remove(String existing) {
    final _Scan scan = _scan(existing);
    switch (scan) {
      case _Damaged(:final reason):
        return BeakBlockDamaged(reason);
      case _Absent():
        return BeakBlockOk(existing);
      case _Found(:final start, :final stop):
        final String eol = _endOfLineAt(existing, start);
        var before = existing.substring(0, start);
        var after = existing.substring(stop);
        if (after.startsWith(eol)) {
          after = after.substring(eol.length);
        }
        if (before.endsWith('$eol$eol')) {
          before = before.substring(0, before.length - eol.length);
        } else if (before.isEmpty && after.startsWith(eol)) {
          after = after.substring(eol.length);
        }
        return BeakBlockOk('$before$after');
    }
  }

  /// The managed block in [existing].
  static BeakBlockLookup find(String existing) {
    final _Scan scan = _scan(existing);
    return switch (scan) {
      _Damaged(:final reason) => BeakBlockDamaged(reason),
      _Absent() => const BeakBlockMissing(),
      _Found(:final start, :final stop) => BeakBlockPresent(
        existing.substring(start, stop).replaceAll('\r\n', '\n'),
      ),
    };
  }

  /// The text of a new `AGENTS.md`: a title, the [block] (markers included),
  /// and a section the project's own conventions go in.
  static String newFile(String title, String block) =>
      '# $title\n'
      '\n'
      '$block\n'
      '\n'
      '## This project\n'
      '\n'
      '<!-- Your conventions: domain words, who uses the panel, what "done" '
      'means here.\n'
      'Beak only edits between the markers above. -->\n';

  /// [text] (in LF) with its line breaks written as [eol].
  static String _withEol(String text, String eol) =>
      eol == '\n' ? text : text.replaceAll('\n', eol);

  /// The line ending the file starts with: CRLF when its first line break
  /// is one, LF otherwise.
  static String _endOfLineIn(String text) {
    final int newline = text.indexOf('\n');
    return newline > 0 && text[newline - 1] == '\r' ? '\r\n' : '\n';
  }

  /// The line ending of the line beginning at [lineStart], falling back to
  /// the file's own for a last line that has none.
  static String _endOfLineAt(String text, int lineStart) {
    final int newline = text.indexOf('\n', lineStart);
    if (newline == -1) {
      return _endOfLineIn(text);
    }
    return newline > 0 && text[newline - 1] == '\r' ? '\r\n' : '\n';
  }

  /// Finds the marker lines of [text].
  static _Scan _scan(String text) {
    final begins = <int>[];
    final ends = <({int start, int stop})>[];
    var offset = 0;
    while (offset <= text.length) {
      final int newline = text.indexOf('\n', offset);
      final int lineEnd = newline == -1 ? text.length : newline;
      final String line = text.substring(offset, lineEnd).trimRight();
      if (line == begin) {
        begins.add(offset);
      } else if (line == end) {
        ends.add((start: offset, stop: offset + line.length));
      }
      if (newline == -1) {
        break;
      }
      offset = newline + 1;
    }
    const String fix = 'fix or delete the markers in the file';
    if (begins.isEmpty && ends.isEmpty) {
      return const _Absent();
    }
    if (begins.length > 1 || ends.length > 1) {
      return const _Damaged(
        'the file has more than one Beak block; $fix so one pair remains',
      );
    }
    if (ends.isEmpty) {
      return const _Damaged('the BEGIN marker has no END marker; $fix');
    }
    if (begins.isEmpty) {
      return const _Damaged('the END marker has no BEGIN marker; $fix');
    }
    if (ends.single.start < begins.single) {
      return const _Damaged(
        'the END marker comes before the BEGIN marker; $fix',
      );
    }
    return _Found(begins.single, ends.single.stop);
  }
}

/// What a scan of a file's marker lines found.
sealed class _Scan {
  const _Scan();
}

final class _Absent extends _Scan {
  const _Absent();
}

final class _Damaged extends _Scan {
  const _Damaged(this.reason);

  final String reason;
}

final class _Found extends _Scan {
  const _Found(this.start, this.stop);

  /// Offset of the BEGIN line's first character.
  final int start;

  /// Offset just past the END marker.
  final int stop;
}
