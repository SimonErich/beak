/// Name conversions used by the make:* commands.
library;

/// Convert `BlogPost` to `blog_post`.
String pascalToSnake(String input) {
  final buf = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    final lower = char.toLowerCase();
    if (i > 0 && char != lower) buf.write('_');
    buf.write(lower);
  }
  return buf.toString();
}

/// Convert `BlogPost` to `blog_posts` (naive pluralisation).
String tableNameFor(String className) {
  final snake = pascalToSnake(className);
  if (snake.endsWith('s')) return snake;
  if (snake.endsWith('y')) return '${snake.substring(0, snake.length - 1)}ies';
  return '${snake}s';
}

/// Convert `blog_post` to `BlogPost`.
String snakeToPascal(String input) {
  final parts = input.split('_').where((p) => p.isNotEmpty);
  final buf = StringBuffer();
  for (final p in parts) {
    buf
      ..write(p[0].toUpperCase())
      ..write(p.substring(1));
  }
  return buf.toString();
}

/// Render a 14-char migration filename timestamp from [now].
///
/// Format: `YYYYMMDD_HHMMSS` **in UTC**. The input is normalised via
/// `toUtc()` so production callers passing a local `DateTime.now()`
/// and tests passing a `DateTime.utc(...)` both produce a stable UTC
/// string.
String migrationTimestamp(DateTime now) {
  final utc = now.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  String four(int v) => v.toString().padLeft(4, '0');
  return '${four(utc.year)}${two(utc.month)}${two(utc.day)}'
      '_${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
}
