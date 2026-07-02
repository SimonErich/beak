/// Pure, stateless compiler from worm descriptors to MongoDB
/// filter / find-operation documents.
library;

import 'package:worm/worm.dart';

import 'mongo_compile_result.dart';

/// Compiles worm query descriptors into BSON-compatible MongoDB
/// documents.
///
/// Produces plain Dart collections (`Map<String, Object?>`,
/// `List<Object?>`) so the output is JSON-serialisable for logging,
/// golden snapshots, and driver hand-off via `mongo_dart`. The
/// compiler performs no I/O and depends on no database connection.
///
/// ## Field-name handling
///
/// worm's domain model uses `id` as the canonical primary-key column
/// name. MongoDB stores primary keys under `_id`. The compiler maps
/// `id` → `_id` everywhere (filters, projections, sort keys) so user
/// descriptors stay database-agnostic.
final class MongoFilterCompiler {
  /// Creates a const, reusable compiler.
  const MongoFilterCompiler();

  /// The name of worm's logical primary-key column.
  static const String _idColumn = 'id';

  /// MongoDB's native primary-key field name.
  static const String _idField = '_id';

  /// Compiles a [PredicateTree] into a single MongoDB filter
  /// document.
  ///
  /// - `null` tree → `{}` (match every document).
  /// - Single leaf → that leaf's clause, unwrapped.
  /// - AND/OR/NOT/group nodes compose into the matching MongoDB
  ///   operator (`$and`, `$or`, `$nor`).
  Map<String, Object?> compileFilter(PredicateTree? tree) {
    if (tree == null) return const <String, Object?>{};
    return _compileTree(tree);
  }

  /// Compiles a full [QueryDescriptor] — filter, sort, skip, limit,
  /// projection, and the target collection — into a
  /// [MongoCompileResult].
  MongoCompileResult compileQuery(QueryDescriptor descriptor) =>
      MongoCompileResult(
        collection: descriptor.table,
        filter: compileFilter(descriptor.where),
        sort: _compileSort(descriptor.orderBy),
        projection: _compileProjection(descriptor.columns),
        limit: descriptor.limit,
        skip: descriptor.offset,
      );

  /// Renders [descriptor] as a MongoDB shell-style
  /// `db.<collection>.find(...)` line.
  ///
  /// Useful for log lines and the shared adapter contract test.
  /// Accepts any worm descriptor type; falls back to a generic form
  /// for descriptors the compiler has not yet specialised.
  String compileToString(Object descriptor) {
    if (descriptor is QueryDescriptor) {
      final compiled = compileQuery(descriptor);
      return _renderFind(compiled);
    }
    return 'db.${_collectionOf(descriptor)}.'
        '${_operationOf(descriptor)}'
        '(${_bodyOf(descriptor)})';
  }

  Map<String, Object?> _compileTree(PredicateTree node) => switch (node) {
    LeafNode(:final predicate) => _compilePredicate(predicate),
    AndNode(:final left, :final right) => <String, Object?>{
      r'$and': <Map<String, Object?>>[_compileTree(left), _compileTree(right)],
    },
    OrNode(:final left, :final right) => <String, Object?>{
      r'$or': <Map<String, Object?>>[_compileTree(left), _compileTree(right)],
    },
    NotNode(:final child) => <String, Object?>{
      r'$nor': <Map<String, Object?>>[_compileTree(child)],
    },
    GroupNode(:final child) => _compileTree(child),
    ColumnNode() => _compileColumn(node),
    ExistsNode() => throw const UnsupportedOperationException(
      operation: 'whereExists',
      adapter: 'MongoFilterCompiler',
      message:
          'MongoDB find filters cannot express EXISTS subqueries; '
          'use an aggregation pipeline with \$lookup instead.',
    ),
    RawNode() => throw const UnsupportedOperationException(
      operation: 'whereRaw',
      adapter: 'MongoFilterCompiler',
      message: 'MongoDB filters cannot evaluate raw SQL fragments.',
    ),
  };

  Map<String, Object?> _compileColumn(ColumnNode node) => <String, Object?>{
    r'$expr': <String, Object?>{
      '\$${node.operator.name}': <Object?>[
        '\$${_fieldOf(node.leftField)}',
        '\$${_fieldOf(node.rightField)}',
      ],
    },
  };

  Map<String, Object?> _compilePredicate(Predicate predicate) {
    final field = _fieldOf(predicate.fieldName);
    return switch (predicate.operator) {
      Operator.eq => <String, Object?>{field: _guardScalar(predicate.value)},
      Operator.neq => <String, Object?>{
        field: <String, Object?>{r'$ne': _guardScalar(predicate.value)},
      },
      Operator.gt => <String, Object?>{
        field: <String, Object?>{r'$gt': _guardScalar(predicate.value)},
      },
      Operator.gte => <String, Object?>{
        field: <String, Object?>{r'$gte': _guardScalar(predicate.value)},
      },
      Operator.lt => <String, Object?>{
        field: <String, Object?>{r'$lt': _guardScalar(predicate.value)},
      },
      Operator.lte => <String, Object?>{
        field: <String, Object?>{r'$lte': _guardScalar(predicate.value)},
      },
      Operator.like => _compileLike(
        field,
        predicate.value,
        caseInsensitive: false,
        negate: false,
      ),
      Operator.notLike => _compileLike(
        field,
        predicate.value,
        caseInsensitive: false,
        negate: true,
      ),
      Operator.ilike => _compileLike(
        field,
        predicate.value,
        caseInsensitive: true,
        negate: false,
      ),
      Operator.isNull => <String, Object?>{
        field: <String, Object?>{r'$eq': null},
      },
      Operator.isNotNull => <String, Object?>{
        field: <String, Object?>{r'$ne': null},
      },
      Operator.inList => <String, Object?>{
        field: <String, Object?>{r'$in': _asList(predicate.value)},
      },
      Operator.notInList => <String, Object?>{
        field: <String, Object?>{r'$nin': _asList(predicate.value)},
      },
      Operator.between => _compileBetween(
        field,
        predicate.value,
        negate: false,
      ),
      Operator.notBetween => _compileBetween(
        field,
        predicate.value,
        negate: true,
      ),
    };
  }

  Map<String, Object?> _compileLike(
    String field,
    Object? pattern, {
    required bool caseInsensitive,
    required bool negate,
  }) {
    if (pattern is! String) {
      return <String, Object?>{
        field: const <String, Object?>{r'$eq': null},
      };
    }
    final regex = _likePatternToRegex(pattern);
    final inner = <String, Object?>{r'$regex': regex};
    if (caseInsensitive) inner[r'$options'] = 'i';
    if (negate) {
      return <String, Object?>{
        field: <String, Object?>{r'$not': inner},
      };
    }
    return <String, Object?>{field: inner};
  }

  Map<String, Object?> _compileBetween(
    String field,
    Object? bounds, {
    required bool negate,
  }) {
    final pair = _extractBounds(bounds);
    if (pair == null) {
      return <String, Object?>{
        field: const <String, Object?>{r'$eq': null},
      };
    }
    final low = _guardScalar(pair.$1);
    final high = _guardScalar(pair.$2);
    if (negate) {
      return <String, Object?>{
        r'$or': <Map<String, Object?>>[
          <String, Object?>{
            field: <String, Object?>{r'$lt': low},
          },
          <String, Object?>{
            field: <String, Object?>{r'$gt': high},
          },
        ],
      };
    }
    return <String, Object?>{
      field: <String, Object?>{r'$gte': low, r'$lte': high},
    };
  }

  (Object?, Object?)? _extractBounds(Object? bounds) {
    if (bounds is (Object?, Object?)) return bounds;
    if (bounds is List && bounds.length == 2) return (bounds[0], bounds[1]);
    return null;
  }

  Map<String, int> _compileSort(List<SortClause> orderBy) {
    if (orderBy.isEmpty) return const <String, int>{};
    return <String, int>{
      for (final clause in orderBy)
        _fieldOf(clause.fieldName): clause.direction == SortDirection.desc
            ? -1
            : 1,
    };
  }

  Map<String, int>? _compileProjection(List<String> columns) {
    if (columns.isEmpty) return null;
    final projection = <String, int>{
      for (final column in columns) _fieldOf(column): 1,
    };
    if (!columns.contains(_idColumn) && !columns.contains(_idField)) {
      projection[_idField] = 0;
    }
    return projection;
  }

  String _renderFind(MongoCompileResult compiled) {
    final buffer = StringBuffer('db.')
      ..write(compiled.collection)
      ..write('.find(')
      ..write(_renderMap(compiled.filter));
    final projection = compiled.projection;
    if (projection != null) {
      buffer
        ..write(', ')
        ..write(_renderMap(projection));
    }
    buffer.write(')');
    if (compiled.sort.isNotEmpty) {
      buffer
        ..write('.sort(')
        ..write(_renderMap(compiled.sort))
        ..write(')');
    }
    if (compiled.skip != null) {
      buffer
        ..write('.skip(')
        ..write(compiled.skip)
        ..write(')');
    }
    if (compiled.limit != null) {
      buffer
        ..write('.limit(')
        ..write(compiled.limit)
        ..write(')');
    }
    return buffer.toString();
  }

  String _renderMap(Map<String, Object?> map) {
    final entries = <String>[
      for (final entry in map.entries)
        '"${entry.key}": ${_renderValue(entry.value)}',
    ];
    return '{${entries.join(', ')}}';
  }

  String _renderValue(Object? value) => switch (value) {
    null => 'null',
    final String s => '"$s"',
    final num n => n.toString(),
    final bool b => b.toString(),
    final Map<String, Object?> m => _renderMap(m),
    final List<Object?> l => _renderList(l),
    _ => '"$value"',
  };

  String _renderList(List<Object?> list) {
    final parts = <String>[for (final v in list) _renderValue(v)];
    return '[${parts.join(', ')}]';
  }

  String _collectionOf(Object descriptor) => switch (descriptor) {
    final QueryDescriptor d => d.table,
    final InsertDescriptor d => d.table,
    final InsertManyDescriptor d => d.table,
    final UpdateDescriptor d => d.table,
    final DeleteDescriptor d => d.table,
    final AggregateDescriptor d => d.table,
    final SchemaDescriptor d => d.table,
    _ => 'unknown',
  };

  String _operationOf(Object descriptor) => switch (descriptor) {
    QueryDescriptor() => 'find',
    InsertDescriptor() => 'insertOne',
    InsertManyDescriptor() => 'insertMany',
    UpdateDescriptor() => 'updateMany',
    DeleteDescriptor() => 'deleteMany',
    AggregateDescriptor() => 'aggregate',
    SchemaDescriptor() => 'schema',
    _ => 'run',
  };

  String _bodyOf(Object descriptor) => switch (descriptor) {
    final InsertDescriptor d => _renderMap(d.values),
    final UpdateDescriptor d => _renderMap(<String, Object?>{
      r'$set': d.values,
    }),
    final DeleteDescriptor d => _renderMap(compileFilter(d.where)),
    final AggregateDescriptor d =>
      '${d.function.name}("${d.column ?? '*'}") where '
          '${_renderMap(compileFilter(d.where))}',
    final SchemaDescriptor d => '${d.operation.name}("${d.table}")',
    _ => '',
  };

  List<Object?> _asList(Object? value) {
    if (value is List) {
      return <Object?>[for (final element in value) _guardScalar(element)];
    }
    return const <Object?>[];
  }

  /// Defence-in-depth against NoSQL operator injection.
  ///
  /// Scalar predicate values (from `eq` / `gt` / `in` / `between` …)
  /// must never be a map carrying a MongoDB operator (`$`-prefixed)
  /// key — that would let an attacker-supplied object such as
  /// `{r'$ne': null}` rewrite the query's semantics. Typed `Field`
  /// values can't produce one; this guards the loosely-typed
  /// (`Field<Object?>`) path. Intentional operator documents go
  /// through the explicit `.mongo(rawFilter:)` escape hatch instead.
  Object? _guardScalar(Object? value) {
    if (value is Map &&
        value.keys.any((k) => k is String && k.startsWith(r'$'))) {
      throw const QueryException(
        query: '',
        message:
            'Rejected a map value containing a MongoDB operator key in a '
            'scalar predicate (possible NoSQL operator injection). Pass a '
            'typed field value, or use the .mongo(rawFilter:) escape hatch '
            'for an intentional operator document.',
      );
    }
    return value;
  }

  String _fieldOf(String column) => column == _idColumn ? _idField : column;

  /// Translates a SQL LIKE pattern into a regex string.
  ///
  /// `%` → `.*`, `_` → `.`, every other regex metacharacter is
  /// escaped. The result is not anchored — MongoDB's `$regex`
  /// already performs substring matching by default, which matches
  /// LIKE semantics ("contains"-style `%foo%` becomes `.*foo.*`).
  String _likePatternToRegex(String pattern) {
    final buffer = StringBuffer();
    for (final unit in pattern.codeUnits) {
      final char = String.fromCharCode(unit);
      if (char == '%') {
        buffer.write('.*');
        continue;
      }
      if (char == '_') {
        buffer.write('.');
        continue;
      }
      if (_regexMetaChars.contains(char)) {
        buffer.write(r'\');
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  static const Set<String> _regexMetaChars = <String>{
    '.',
    '*',
    '+',
    '?',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    '|',
    '^',
    r'$',
    r'\',
  };
}
