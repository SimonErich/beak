/// Hostile-input helpers: a valid JSON document with one node replaced by
/// junk of another type, so a test can ask "does this endpoint still answer
/// with a 4xx".
library;

import 'dart:math';

/// A random JSON value of any type, nested at most three levels.
Object? junkJson(Random random, [int depth = 0]) {
  switch (random.nextInt(depth > 2 ? 7 : 9)) {
    case 0:
      return null;
    case 1:
      return random.nextInt(2000) - 1000;
    case 2:
      return random.nextDouble() * 1e6;
    case 3:
      return random.nextBool();
    case 4:
      const words = [
        '',
        'x',
        'and',
        'field',
        'eq',
        'dateTime',
        'notes',
        '%',
        '\u0000',
        'a\\b',
        "'; DROP TABLE notes;--",
      ];
      return words[random.nextInt(words.length)];
    case 5:
      return 9007199254740993;
    case 6:
      return -1;
    case 7:
      return [
        for (var i = random.nextInt(3); i > 0; i--) junkJson(random, depth + 1),
      ];
    default:
      const keys = ['type', 'value', 'column', 'filters', 'x'];
      return {
        for (var i = random.nextInt(3); i > 0; i--)
          keys[random.nextInt(keys.length)]: junkJson(random, depth + 1),
      };
  }
}

/// [document] with one node, chosen by [random], replaced by junk; or, one
/// time in six, with a key of an object removed.
///
/// Seven times in ten the node is a leaf (a value, not a container): that is
/// where a well-formed request carries a value of the wrong type.
Object? mutateJson(Object? document, Random random) {
  final paths = <List<Object>>[];
  final leaves = <List<Object>>[];
  void walk(Object? node, List<Object> path) {
    paths.add(path);
    if (node is Map<String, Object?>) {
      for (final entry in node.entries) {
        walk(entry.value, [...path, entry.key]);
      }
    } else if (node is List<Object?>) {
      for (var i = 0; i < node.length; i++) {
        walk(node[i], [...path, i]);
      }
    } else {
      leaves.add(path);
    }
  }

  walk(document, const []);
  final chosen = random.nextInt(10) < 7 && leaves.isNotEmpty ? leaves : paths;
  final path = chosen[random.nextInt(chosen.length)];
  final removeKey = random.nextInt(6) == 0;
  Object? rebuild(Object? node, int depth) {
    if (depth == path.length) return junkJson(random);
    final step = path[depth];
    final atLeaf = depth == path.length - 1;
    if (node is Map<String, Object?>) {
      return {
        for (final entry in node.entries)
          if (!(removeKey && atLeaf && entry.key == step))
            entry.key: entry.key == step
                ? rebuild(entry.value, depth + 1)
                : entry.value,
      };
    }
    if (node is List<Object?>) {
      return [
        for (var i = 0; i < node.length; i++)
          i == step ? rebuild(node[i], depth + 1) : node[i],
      ];
    }
    return node;
  }

  return rebuild(document, 0);
}
