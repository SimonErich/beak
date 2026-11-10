part of 'serverpod_ir.dart';

BeakAdmissionIr _admissionFor(
  _Draft draft,
  DefinitionResource resource,
  String prefix,
  BeakIssueSink issues,
) {
  final columns = {
    for (final column in draft.schema.columns) column.fieldName,
    for (final column in draft.schema.columns) column.columnKey,
  };
  final writable = <String>[];
  for (final field in resource.writeFields ?? const <String>[]) {
    if (!columns.contains(field)) {
      issues.add(
        resource.path,
        '${resource.name}.$field is writable but has no column; declare its '
        'relation or mark it @ReadOnly().',
      );
      continue;
    }
    if (const {
      'id',
      'createdAt',
      'updatedAt',
      'deletedAt',
      'isDeleted',
    }.contains(field)) {
      issues.add(
        resource.path,
        '${resource.name}.$field is server owned and never written.',
      );
      continue;
    }
    for (final hidden in draft.hidden) {
      if (hidden == field) {
        issues.add(
          resource.path,
          '${resource.name}.$field is hidden and never written.',
        );
      }
    }
    writable.add(field);
  }
  // The key a one-sided parent stores on this row is written with the row
  // whenever its fields are.
  if (writable.isNotEmpty) {
    for (final column in draft.schema.columns) {
      if (column.columnKey.startsWith('_') &&
          !writable.contains(column.fieldName)) {
        writable.add(column.fieldName);
      }
    }
  }
  final hidden = [
    for (final field in draft.hidden)
      if (columns.contains(field)) field,
  ];
  final translation = _translationOf(draft, resource);
  final restoreKey =
      resource.restoreKey ??
      (translation == null ? null : [translation.owner, translation.locale]);
  return BeakAdmissionIr(
    writable: writable,
    hidden: hidden,
    restoreKey: restoreKey ?? const [],
    writeValue: resource.write == null
        ? null
        : '${prefix}Write.${resource.write}',
    reason: resource.reason,
    translationOwner: translation?.owner,
    translationLocale: translation?.locale,
  );
}

({String owner, String locale})? _translationOf(
  _Draft draft,
  DefinitionResource resource,
) {
  if (resource.write == null) return null;
  final locale = draft.schema.columns
      .where((column) => column.columnKey.toLowerCase() == 'locale')
      .map((column) => column.fieldName)
      .firstOrNull;
  if (locale == null) return null;
  for (final index in draft.db.indexes) {
    if (!index.isUnique) continue;
    final localeKey = index.columns
        .where((column) => column.toLowerCase() == 'locale')
        .firstOrNull;
    if (localeKey == null) continue;
    final ownerKey = index.columns
        .where((column) => column != localeKey)
        .firstOrNull;
    if (ownerKey == null) continue;
    final ownerField = draft.schema.columns
        .where((column) => column.columnKey == ownerKey)
        .map((column) => column.fieldName)
        .firstOrNull;
    if (ownerField != null) return (owner: ownerField, locale: locale);
  }
  return null;
}

BeakPermissionsIr _permissionsFor(
  DefinitionResource resource,
  BeakGenerateSettings settings,
) {
  final area = resource.area == null ? null : settings.areas[resource.area];
  final read = resource.access.operations['read'] ?? area?.read ?? const [];
  final write = resource.access.operations['write'] ?? area?.write ?? const [];
  List<String>? override(String operation) =>
      resource.access.operations[operation];
  return BeakPermissionsIr(
    read: read,
    write: _writable(resource) ? write : const [],
    create: override('create'),
    update: override('update'),
    delete: override('delete'),
  );
}

bool _writable(DefinitionResource resource) =>
    resource.writes && resource.write != null;
