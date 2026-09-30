part of 'generator.dart';

final class _ResourceEmitter {
  _ResourceEmitter(this.owner, this.read, this.client) {
    final candidates =
        <(FieldElement, MethodElement, InterfaceType, InterfaceType)>[];
    for (final field in client.fields) {
      final type = field.type;
      if (type is! InterfaceType) continue;
      for (final method in type.element.methods) {
        if (method.name != 'list') continue;
        final page = _future(method.returnType);
        if (page is! InterfaceType) continue;
        final items = page.element.fields.where(
          (field) => _listOf(field.type, read.element),
        );
        final queries = method.formalParameters.where((parameter) {
          final type = parameter.type;
          return type is InterfaceType &&
              type.element.fields.any((field) => field.name == 'pageSize');
        });
        if (items.length == 1 && queries.length == 1) {
          final queryType = queries.single.type;
          if (queryType is InterfaceType) {
            candidates.add((field, method, queryType, page));
          }
        }
      }
    }
    if (candidates.length != 1) {
      throw FormatException(
        '${read.name} needs one unambiguous Client endpoint with list(query) returning a typed page; found ${candidates.length}.',
      );
    }
    final candidate = candidates.single;
    endpoint = candidate.$1;
    list = candidate.$2;
    query = candidate.$3;
    page = candidate.$4;
    final endpointType = endpoint.type;
    if (endpointType is! InterfaceType) {
      throw const FormatException('Endpoint type missing.');
    }
    methods = endpointType.element.methods;
    get = _singleMethod({
      'get',
      'getById',
    }, (method) => _isRead(_future(method.returnType)));
    if (get == null) {
      throw FormatException('${read.name} needs a typed get/getById method.');
    }
    final ids = get!.formalParameters
        .where((parameter) => parameter.name != 'locale')
        .toList();
    if (ids.length != 1 ||
        owner._scalar(ids.single.type) == null ||
        owner._nullable(ids.single.type)) {
      throw FormatException(
        '${read.name} get needs one non-null scalar identity.',
      );
    }
    idType = ids.single.type;
    create = _singleMethod({
      'create',
    }, (method) => _isRead(_future(method.returnType)));
    update = _singleMethod({
      'update',
      'edit',
    }, (method) => _isRead(_future(method.returnType)));
    remove = _singleMethod({
      'delete',
      'archive',
    }, (method) => _future(method.returnType) is VoidType);
    batch = _singleMethod({'getMany'}, (method) {
      final result = _future(method.returnType);
      return result != null && _listOf(result, read.element);
    });
    createInput = _input(create);
    updateInput = _input(update);
    for (final type in [query, page, ?createInput, ?updateInput]) {
      final element = type.element;
      if (element is ClassElement) owner.collect(element);
    }
    if (!query.element.fields.any((field) => field.name == 'page') ||
        !page.element.fields.any(
          (field) => field.name == 'totalCount' && field.type.isDartCoreInt,
        ) ||
        query.element.unnamedConstructor?.formalParameters.any(
              (parameter) => parameter.isRequiredNamed,
            ) !=
            false) {
      throw FormatException(
        '${read.name} requires query page/pageSize defaults and page totalCount.',
      );
    }
  }
  final _Emitter owner;
  final _Model read;
  final ClassElement client;
  late final FieldElement endpoint;
  late final MethodElement list;
  late final InterfaceType query;
  late final InterfaceType page;
  late final List<MethodElement> methods;
  late final DartType idType;
  late final MethodElement? get;
  late final MethodElement? create;
  late final MethodElement? update;
  late final MethodElement? remove;
  late final MethodElement? batch;
  late final InterfaceType? createInput;
  late final InterfaceType? updateInput;

  DartType? _future(DartType type) =>
      type is InterfaceType && type.isDartAsyncFuture
      ? type.typeArguments.single
      : null;
  bool _isRead(DartType? type) =>
      type is InterfaceType && type.element == read.element;
  bool _listOf(DartType type, InterfaceElement element) =>
      type is InterfaceType &&
      type.isDartCoreList &&
      switch (type.typeArguments.single) {
        final InterfaceType item => item.element == element,
        _ => false,
      };
  MethodElement? _singleMethod(
    Set<String> names,
    bool Function(MethodElement) matches,
  ) {
    final found = methods
        .where((method) => names.contains(method.name) && matches(method))
        .toList();
    if (found.length > 1) {
      throw FormatException(
        '${read.name}: ambiguous operations ${found.map((method) => method.name).join(', ')}.',
      );
    }
    return found.firstOrNull;
  }

  InterfaceType? _input(MethodElement? method) {
    if (method == null) return null;
    final inputs = method.formalParameters
        .where(
          (parameter) =>
              parameter.name != 'locale' && !_sameType(parameter.type, idType),
        )
        .toList();
    if (inputs.length != 1 || inputs.single.type is! InterfaceType) {
      throw FormatException(
        '${read.name}.${method.name} requires one typed input.',
      );
    }
    final type = inputs.single.type;
    return type is InterfaceType ? type : null;
  }

  bool _listMatchesId(DartType type) => switch (idType) {
    final InterfaceType id => _listOf(type, id.element),
    _ => false,
  };
  bool _sameType(DartType left, DartType right) =>
      left is InterfaceType &&
      right is InterfaceType &&
      left.element == right.element &&
      left.typeArguments.length == right.typeArguments.length &&
      Iterable<int>.generate(left.typeArguments.length).every(
        (index) =>
            _sameType(left.typeArguments[index], right.typeArguments[index]),
      );
  String _call(
    MethodElement method, {
    String? queryValue,
    String? input,
    String? id,
    String? ids,
  }) {
    final arguments = <String>[];
    for (final parameter in method.formalParameters) {
      final String value;
      if (parameter.name == 'locale' && parameter.type.isDartCoreString) {
        value = 'locale()';
      } else if (_sameType(parameter.type, query) && queryValue != null) {
        value = queryValue;
      } else if (_sameType(parameter.type, idType) && id != null) {
        value = id;
      } else if (parameter.type is InterfaceType &&
          ids != null &&
          _listMatchesId(parameter.type)) {
        value = ids;
      } else if (input != null &&
          parameter.type is InterfaceType &&
          !_sameType(parameter.type, idType)) {
        value = input;
      } else {
        throw FormatException(
          '${read.name}.${method.name}: unsupported parameter ${parameter.name}; add a typed adapter.',
        );
      }
      arguments.add('${parameter.isNamed ? '${parameter.name}: ' : ''}$value');
    }
    return 'client.${endpoint.name}.${method.name}(${arguments.join(', ')})';
  }

  String _editInputMethod() {
    final input = updateInput;
    if (input == null) return '';
    final targets = owner.fieldRefs[input.element.name]!;
    final sources = owner.fieldRefs[read.name]!;
    final parameters = <String>[];
    final values = <String>[];
    for (final target in targets) {
      final candidates = sources
          .where(
            (source) =>
                source.key.split('.').last == target.key.split('.').last &&
                _sameType(source.type, target.type) &&
                (!source.nullable || target.nullable),
          )
          .toList();
      final String value;
      if (candidates.length == 1) {
        value = '${read.name}Fields.${candidates.single.name}.get(value)';
      } else {
        parameters.add(
          'required ${owner._name(target.type, forceNullable: target.nullable)} ${target.name}',
        );
        value = target.name;
      }
      values.add(
        "'${target.key}': ${input.element.name}Fields.${target.name}.codec.encode($value)",
      );
    }
    return '''
  /// Projects compatible fields; only domain-specific values need overrides.
  static ${owner._name(input)} editInput(${owner._name(read.element.thisType)} value${parameters.isEmpty ? '' : ', {${parameters.join(', ')}}'}) => const ${input.element.name}Codec().decode(BeakRecord(values: {${values.join(', ')}}));
''';
  }

  String emit() {
    final entity = owner._name(read.element.thisType);
    final id = owner._name(idType);
    final createType = createInput == null
        ? 'Never'
        : owner._name(createInput!);
    final updateType = updateInput == null
        ? 'Never'
        : owner._name(updateInput!);
    final refs = owner.fieldRefs[read.name]!;
    final queryFields = query.element.fields
        .where((field) => !field.isStatic)
        .toList();
    bool has(String name) => queryFields.any((field) => field.name == name);
    final filterFields = queryFields
        .where(
          (field) =>
              !{
                'page',
                'pageSize',
                'search',
                'sort',
                'descending',
                'includeArchived',
              }.contains(field.name) &&
              owner._scalar(field.type) != null &&
              owner._nullable(field.type) &&
              refs.any(
                (ref) =>
                    ref.key.split('.').last == field.name &&
                    _sameType(ref.type, field.type),
              ),
        )
        .toList();
    final fieldNames = <String, List<String>>{};
    for (final ref in refs) {
      fieldNames.putIfAbsent(ref.key.split('.').last, () => []).add(ref.key);
    }
    final fieldMap = fieldNames.entries
        .map(
          (entry) =>
              "'${entry.key}': [${entry.value.map((key) => "'$key'").join(', ')}]",
        )
        .join(', ');
    final sortField = queryFields
        .where((field) => field.name == 'sort')
        .firstOrNull;
    final sortType = sortField?.type;
    final hasSort =
        sortType is InterfaceType && sortType.element is EnumElement;
    final sortName = hasSort ? owner._name(sortType) : null;
    final pageItems = page.element.fields
        .singleWhere((field) => _listOf(field.type, read.element))
        .name;
    final needsLocale = [list, ?get, ?create, ?update, ?remove, ?batch].any(
      (method) => method.formalParameters.any(
        (parameter) => parameter.name == 'locale',
      ),
    );
    final queryArgs = <String>[
      'page: reader.page(firstPage ?? defaults.page)',
      'pageSize: reader.perPage',
      if (has('search')) 'search: reader.search',
      if (hasSort)
        'sort: reader.sort($sortName.values, defaults.sort, overrides: {for (final entry in sortFields.entries) entry.key.key: entry.value})',
      if (has('descending'))
        'descending: reader.descending(defaults.descending)',
      if (has('includeArchived')) 'includeArchived: spec.withTrashed',
      for (final field in filterFields)
        "${field.name}: reader.equal('${field.name}', ${owner._scalar(field.type)})",
    ];
    final createCodec = createInput == null
        ? null
        : '${createInput!.element.name}Codec';
    final updateCodec = updateInput == null
        ? null
        : '${updateInput!.element.name}Codec';
    String form(InterfaceType type, String labels) {
      final fields = owner.fieldRefs[type.element.name]!;
      return '''ServerpodModel(resource: resource, formSlots: ${type.element.name}FormSlot.values, primaryKey: model.primaryKey, displayColumn: model.primaryKey, columns: [${fields.map((field) => "serverpodFormColumn(${type.element.name}Fields.${field.name}, columns, label: $labels[${type.element.name}Fields.${field.name}])").join(', ')}])''';
    }

    final projectedInput = updateInput == null
        ? ''
        : '''(value) => const $updateCodec().decode(serverpodProjectInput(const ${read.name}Codec().encode(value), inputKeys: [${owner.fieldRefs[updateInput!.element.name]!.map((field) => "'${field.key}'").join(', ')}], primaryKey: primaryKey.key))''';
    return '''
/// Model-owned Serverpod CRUD generated from the existing ${read.name} endpoint.
final class ${read.name}Resource extends ServerpodResource<$entity, $id, $createType, $updateType> {
  /// Configures presentation and exceptions to the discovered typed operations.
  factory ${read.name}Resource({
    required ${owner._name(client.thisType)} client,
    required String resource,
    required ServerpodField<$entity, $id> primaryKey,
    required List<BeakColumn> columns,
    BeakColumn? displayColumn,
    BeakPermissions permissions = const BeakPermissions.allowAll(),
    ${needsLocale ? 'required String Function() locale,' : ''}
    int? firstPage,
    ${hasSort ? 'Map<ServerpodField<$entity, Object?>, $sortName> sortFields = const {},' : ''}
    Future<void> Function()? onChanged,
    Future<BeakPage<$entity>> Function(BeakQuerySpec)? query,
    Future<$entity?> Function($id)? get,
    Future<void> Function($id)? archive,
    ${createInput == null ? '' : 'Future<$entity> Function($createType)? create, BeakModel? createModel, Map<ServerpodField<$createType, Object?>, String> createLabels = const {},'}
    ${updateInput == null ? '' : 'Future<$entity> Function($id, $updateType)? update, $updateType Function($entity)? editValues, BeakModel? editModel, Map<ServerpodField<$updateType, Object?>, String> editLabels = const {},'}
  }) {
    final model = ServerpodModel(resource: resource, formSlots: ${read.name}FormSlot.values, primaryKey: columns.where((column) => column.key == primaryKey.key).firstOrNull ?? primaryKey.column(primaryKey.key), displayColumn: displayColumn ?? columns.firstOrNull ?? primaryKey.column(primaryKey.key), columns: columns);
    Future<BeakPage<$entity>> load(BeakQuerySpec spec) async {
      final defaults = ${owner._name(query)}();
      final reader = ServerpodQueryReader(spec: spec, model: model, fields: {$fieldMap}, filters: {${filterFields.map((field) => "'${field.name}'").join(', ')}}, supportsSearch: ${has('search')}, supportsSort: $hasSort, supportsArchived: ${has('includeArchived')});
      final request = ${owner._name(query)}(${queryArgs.join(', ')});
      final result = await ${_call(list, queryValue: 'request')};
      return BeakPage(items: result.$pageItems, total: result.totalCount, page: ${page.element.fields.any((field) => field.name == 'page') ? 'result.page - (firstPage ?? defaults.page) + 1' : 'spec.pagination.page'}, perPage: ${page.element.fields.any((field) => field.name == 'pageSize') ? 'result.pageSize' : 'spec.pagination.perPage'});
    }
    final fetch = query ?? load;
    return ${read.name}Resource._(
      model: model, permissions: permissions, codec: const ${read.name}Codec(), idCodec: primaryKey.codec, identify: primaryKey.get,
      query: fetch, get: get ?? (id) => ${_call(get!, id: 'id')},
      ${remove == null ? 'archive: archive,' : 'archive: archive ?? (id) => ${_call(remove!, id: 'id')},'}
      ${batch == null ? '' : 'batchGet: (ids) => ${_call(batch!, ids: 'ids')},'}
      aggregate: (spec) => serverpodCount(spec, fetch), onChanged: onChanged,
      ${createInput == null ? '' : 'createCodec: const $createCodec(), create: create ?? (input) => ${_call(create!, input: 'input')}, createModel: createModel ?? ${form(createInput!, 'createLabels')},'}
      ${updateInput == null ? '' : 'updateCodec: const $updateCodec(), update: update ?? (id, input) => ${_call(update!, id: 'id', input: 'input')}, editValues: editValues ?? $projectedInput, editModel: editModel ?? ${form(updateInput!, 'editLabels')},'}
    );
  }
  ${_editInputMethod()}
  ${read.name}Resource._({required super.model, required super.codec, required super.idCodec, required super.identify, required super.query, required super.get, super.permissions, super.archive, ${batch == null ? '' : 'super.batchGet,'} super.aggregate, super.onChanged, ${createInput == null ? '' : 'super.createCodec, super.create, super.createModel,'} ${updateInput == null ? '' : 'super.updateCodec, super.update, super.editValues, super.editModel,'}});
}
''';
  }
}
