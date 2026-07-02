/// Adapter-agnostic Mongo filter compiler for query
/// inspection.
library;

import 'dart:convert';

import '../exception/unsupported_operation_exception.dart';
import 'operator.dart';
import 'predicate.dart';
import 'predicate_tree.dart';
import 'query_descriptor.dart';

const _encoder = JsonEncoder();

/// Compiles a [QueryDescriptor]'s WHERE tree into a
/// canonical Mongo filter document string for
/// `QueryBuilder.toMongoFilter()` golden tests.
final class MongoFilterCompiler {
  /// Creates a const compiler.
  const MongoFilterCompiler();

  /// Render [descriptor]'s where clause as a Mongo
  /// filter JSON string.
  String compile(QueryDescriptor descriptor) {
    final where = descriptor.where;
    if (where == null) return '{}';
    return _encoder.convert(_renderTree(where));
  }

  /// Render an arbitrary [PredicateTree] as a Mongo
  /// filter document (raw map form).
  Map<String, Object?> renderTree(PredicateTree node) => _renderTree(node);

  Map<String, Object?> _renderTree(PredicateTree node) => switch (node) {
    LeafNode(:final predicate) => _renderLeaf(predicate),
    AndNode(:final left, :final right) => <String, Object?>{
      r'$and': <Map<String, Object?>>[_renderTree(left), _renderTree(right)],
    },
    OrNode(:final left, :final right) => <String, Object?>{
      r'$or': <Map<String, Object?>>[_renderTree(left), _renderTree(right)],
    },
    NotNode(:final child) => <String, Object?>{
      r'$nor': <Object?>[_renderTree(child)],
    },
    GroupNode(:final child) => _renderTree(child),
    ColumnNode() => _renderColumn(node),
    ExistsNode() => _renderExists(node),
    RawNode() => throw const UnsupportedOperationException(
      operation: 'whereRaw',
      adapter: 'MongoFilterCompiler',
      message: 'Mongo filter cannot render a RawNode',
    ),
  };

  Map<String, Object?> _renderLeaf(Predicate p) {
    final field = p.fieldName;
    switch (p.operator) {
      case Operator.eq:
        return <String, Object?>{field: p.value};
      case Operator.neq:
        return <String, Object?>{
          field: <String, Object?>{r'$ne': p.value},
        };
      case Operator.gt:
        return <String, Object?>{
          field: <String, Object?>{r'$gt': p.value},
        };
      case Operator.gte:
        return <String, Object?>{
          field: <String, Object?>{r'$gte': p.value},
        };
      case Operator.lt:
        return <String, Object?>{
          field: <String, Object?>{r'$lt': p.value},
        };
      case Operator.lte:
        return <String, Object?>{
          field: <String, Object?>{r'$lte': p.value},
        };
      case Operator.like:
      case Operator.notLike:
      case Operator.ilike:
        return <String, Object?>{
          field: <String, Object?>{
            r'$regex': _likeToRegex(p.value),
            if (p.operator == Operator.ilike) r'$options': 'i',
            if (p.operator == Operator.notLike) r'$not': true,
          },
        };
      case Operator.isNull:
        return <String, Object?>{field: null};
      case Operator.isNotNull:
        return <String, Object?>{
          field: <String, Object?>{r'$ne': null},
        };
      case Operator.inList:
        return <String, Object?>{
          field: <String, Object?>{r'$in': p.value},
        };
      case Operator.notInList:
        return <String, Object?>{
          field: <String, Object?>{r'$nin': p.value},
        };
      case Operator.between:
        final bounds = _bounds(p.value);
        return <String, Object?>{
          field: <String, Object?>{r'$gte': bounds.$1, r'$lte': bounds.$2},
        };
      case Operator.notBetween:
        final bounds = _bounds(p.value);
        return <String, Object?>{
          r'$or': <Map<String, Object?>>[
            <String, Object?>{
              field: <String, Object?>{r'$lt': bounds.$1},
            },
            <String, Object?>{
              field: <String, Object?>{r'$gt': bounds.$2},
            },
          ],
        };
    }
  }

  Map<String, Object?> _renderColumn(ColumnNode node) => <String, Object?>{
    r'$expr': <String, Object?>{
      '\$${node.operator.name}': <Object?>[
        '\$${node.leftField}',
        '\$${node.rightField}',
      ],
    },
  };

  Map<String, Object?> _renderExists(ExistsNode node) {
    final sub = node.subquery;
    final filter = sub.where == null
        ? <String, Object?>{}
        : _renderTree(sub.where!);
    final pipeline = <Map<String, Object?>>[
      <String, Object?>{r'$match': filter},
      const <String, Object?>{r'$limit': 1},
    ];
    return <String, Object?>{
      r'$exists': <String, Object?>{
        'from': sub.table,
        'pipeline': pipeline,
        'negated': node.negated,
      },
    };
  }

  String _likeToRegex(Object? pattern) {
    if (pattern is! String) return '';
    final buffer = StringBuffer('^');
    for (final ch in pattern.split('')) {
      if (ch == '%') {
        buffer.write('.*');
      } else if (ch == '_') {
        buffer.write('.');
      } else {
        buffer.write(RegExp.escape(ch));
      }
    }
    buffer.write(r'$');
    return buffer.toString();
  }

  (Object?, Object?) _bounds(Object? value) {
    if (value is (Object?, Object?)) return value;
    if (value is List && value.length == 2) return (value[0], value[1]);
    return (null, null);
  }
}
