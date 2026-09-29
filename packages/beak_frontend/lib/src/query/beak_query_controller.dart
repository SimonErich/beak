import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import '../state/beak_view_model.dart';
import '../data/beak_resource_repository.dart';
import '../filters/beak_filter_widget.dart';
import '../presentation/beak_record_template.dart';

/// A named, counted view over the same resource and permanent query scope.
final class BeakQueryPreset {
  /// Preset filters are combined with permanent and user filters.
  const BeakQueryPreset({
    required this.key,
    required this.label,
    this.filter,
    this.columns,
    this.quickFilters,
    this.defaults = const {},
    this.rowHeight,
    this.countColor = BeakColor.muted,
  });

  /// Stable URL and saved-view identifier.
  ///
  /// Declared once here; every other reference to a preset (the initial
  /// selection, a navigation destination, a count) is the object itself.
  final String key;

  /// Visible tab label.
  final String label;

  /// Additional constraint while this preset is selected.
  final BeakFilter? filter;

  /// Suggested filter values that explicit user filters can replace by key.
  /// Keep mandatory preset constraints in [filter], and tenant scopes in base.
  final Map<BeakFilterDef, BeakFilter> defaults;

  /// Optional alternative columns while this view is active.
  final List<BeakTableColumn>? columns;

  /// Optional ordered quick-filter controls for this preset.
  final List<BeakFilterDef>? quickFilters;

  /// Optional visual row height for this preset; null inherits the table theme.
  final double? rowHeight;

  /// Semantic tone of the record-count label, independent of active-tab styling.
  final BeakColor countColor;
}

/// Authoritative record counts of a list's presets, read by preset object.
///
/// A preset that has no count yet, or whose count failed, answers null rather
/// than zero, so a loading tab is never shown as empty.
final class BeakPresetCounts {
  /// Captures the count of each preset that has one.
  BeakPresetCounts(Map<BeakQueryPreset, int> counts)
    : _byKey = Map.unmodifiable({
        for (final entry in counts.entries) entry.key.key: entry.value,
      });

  /// No preset has been counted.
  const BeakPresetCounts.none() : _byKey = const {};

  final Map<String, int> _byKey;

  /// The number of records in [preset], or null while it is unavailable.
  int? operator [](BeakQueryPreset preset) => _byKey[preset.key];
}

/// Serializable user choices; permanent application scopes are never serialized.
final class BeakQueryState {
  /// Creates the first page of a list.
  BeakQueryState({
    this.preset,
    Map<String, BeakFilter> filters = const {},
    this.search = '',
    List<BeakSort> sorts = const [],
    this.page = 1,
    this.perPage = 15,
    List<String>? visibleColumns,
    this.showHeader,
  }) : visibleColumns = visibleColumns == null
           ? null
           : List.unmodifiable(visibleColumns),
       filters = Map.unmodifiable(filters),
       sorts = List.unmodifiable(sorts) {
    if (page < 1 || perPage < 1 || perPage > 1000) {
      throw const BeakConfigurationException('Invalid list pagination.');
    }
  }

  /// [BeakQueryPreset.key] of the selected preset, or null for the unfiltered
  /// base view.
  ///
  /// The serialized identity of the choice in URLs and saved views. Code that
  /// configures a list refers to the [BeakQueryPreset] object instead.
  final String? preset;

  /// Predicates keyed by configured filter identifiers.
  final Map<String, BeakFilter> filters;

  /// Search term, interpreted against the definition's search fields.
  final String search;

  /// Current ordering.
  final List<BeakSort> sorts;

  /// One-based page number.
  final int page;

  /// Maximum number of records in one page.
  final int perPage;

  /// Explicit presentation keys in display order, or preset/model defaults.
  final List<String>? visibleColumns;

  /// Optional overview visibility preference.
  final bool? showHeader;

  /// Stable persistence representation, shared by URLs and saved views.
  Map<String, Object?> toJson() => {
    'version': 1,
    'preset': preset,
    'filters': {
      for (final entry in filters.entries) entry.key: entry.value.toJson(),
    },
    'search': search,
    'sorts': [for (final sort in sorts) sort.toJson()],
    'page': page,
    'perPage': perPage,
    if (visibleColumns != null) 'columns': visibleColumns,
    if (showHeader != null) 'showHeader': showHeader,
  };

  /// Decodes only the current version and rejects malformed state.
  factory BeakQueryState.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1 || json['filters'] is! Map<String, Object?>) {
      throw const BeakConfigurationException('Unsupported saved list state.');
    }
    final filterValues = switch (json['filters']) {
      final Map<String, Object?> value => value,
      _ => const <String, Object?>{},
    };
    final spec = BeakQuerySpec.fromJson({
      'table': '_list_state',
      'sorts': json['sorts'],
      'pagination': {'page': json['page'], 'perPage': json['perPage']},
    });
    return BeakQueryState(
      preset: switch (json['preset']) {
        null => null,
        final String value => value,
        _ => throw const BeakConfigurationException('Invalid saved preset.'),
      },
      filters: {
        for (final entry in filterValues.entries)
          entry.key: switch (entry.value) {
            final Map<String, Object?> value => BeakFilter.fromJson(value),
            _ => throw const BeakConfigurationException(
              'Invalid saved filter.',
            ),
          },
      },
      search: switch (json['search']) {
        final String value => value,
        _ => throw const BeakConfigurationException('Invalid saved search.'),
      },
      sorts: spec.sorts,
      page: spec.pagination.page,
      perPage: spec.pagination.perPage,
      visibleColumns: switch (json['columns']) {
        null => null,
        final List<Object?> values when values.every((v) => v is String) =>
          values.cast<String>(),
        _ => throw const BeakConfigurationException('Invalid saved columns.'),
      },
      showHeader: switch (json['showHeader']) {
        null => null,
        final bool value => value,
        _ => throw const BeakConfigurationException(
          'Invalid saved overview preference.',
        ),
      },
    );
  }
}

/// Framework-owned list state shared by tables, summaries, filters and exports.
final class BeakQueryController extends BeakViewModel {
  /// The base query stays outside editable or URL-restored state.
  BeakQueryController({
    required this.model,
    BeakQuerySpec? base,
    this.presets = const [],
    this.searchFields = const [],
    this.columns = const [],
    BeakQueryState? initial,
  }) : base = base ?? BeakQuerySpec(table: model.table) {
    if (this.base.table != model.table ||
        presets.map((preset) => preset.key).toSet().length != presets.length ||
        presets.any((preset) => preset.key.isEmpty)) {
      throw const BeakConfigurationException('Invalid list definition.');
    }
    _state = ownedSignal(
      initial ??
          BeakQueryState(
            sorts: this.base.sorts,
            perPage: this.base.pagination.perPage,
            page: this.base.pagination.page,
          ),
    );
    _checkState(_state.value);
  }

  /// Model that owns this list.
  final BeakModel model;

  /// Permanent filtering, eager loads and default pagination.
  final BeakQuerySpec base;

  /// Available named views.
  final List<BeakQueryPreset> presets;

  /// Default configured columns; preset columns can override this projection.
  final List<BeakTableColumn> columns;

  /// Exact generated fields searched; model searchable fields are the default.
  final List<BeakFieldRef<Object>> searchFields;
  late final Signal<BeakQueryState> _state;

  /// Reactive current presentation state.
  ReadonlySignal<BeakQueryState> get state => _state;

  late final Signal<BeakPresetCounts> _presetCounts = ownedSignal(
    const BeakPresetCounts.none(),
  );
  int _countGeneration = 0;

  /// Authoritative preset populations shared by tab badges and the page subtitle.
  ReadonlySignal<BeakPresetCounts> get presetCounts => _presetCounts;

  /// Refreshes each preset once, discarding stale responses after a later refresh.
  Future<void> refreshPresetCounts(BeakDataSource source) async {
    final generation = ++_countGeneration;
    final results = await Future.wait([
      for (final preset in presets)
        BeakResourceRepository(source).query(countQuery(preset)),
    ]);
    if (isDisposed || generation != _countGeneration) return;
    _presetCounts.value = BeakPresetCounts({
      for (final (index, result) in results.indexed)
        if (result case BeakOk<BeakPage<BeakRecord>>(:final value))
          presets[index]: value.total,
    });
  }

  /// Full server query; table pagination does not affect summary filtering.
  BeakQuerySpec get query => queryFor(_state.value);

  /// Builds the candidate filter preview without changing active state.
  /// [excludingFilter] omits one editable facet, preserving permanent scopes.
  BeakQuerySpec queryFor(BeakQueryState value, {String? excludingFilter}) {
    _checkState(value);
    final preset = presets
        .where((preset) => preset.key == value.preset)
        .firstOrNull;
    final searchKeys = searchFields.isEmpty
        ? [
            for (final column in model.columns)
              if (column.searchable) column.key,
          ]
        : [for (final field in searchFields) field.qualifiedKey];
    return BeakQuerySpec(
      table: model.table,
      filter: BeakFilter.allOf([
        ?base.filter,
        ?preset?.filter,
        for (final entry in effectiveFilters(value).entries)
          if (entry.key != excludingFilter) entry.value,
      ]),
      search: value.search.trim().isEmpty || searchKeys.isEmpty
          ? base.search
          : BeakSearch(value.search.trim(), searchKeys),
      sorts: value.sorts,
      relationLoads: base.relationLoads,
      pagination: BeakPagination(page: value.page, perPage: value.perPage),
      withTrashed: base.withTrashed,
    );
  }

  /// Preset defaults plus explicitly supplied filter values.
  Map<String, BeakFilter> effectiveFilters(BeakQueryState value) => {
    for (final entry in {
      for (final preset in presets.where((p) => p.key == value.preset))
        for (final entry in preset.defaults.entries) entry.key.key: entry.value,
      ...value.filters,
    }.entries)
      // An empty conjunction explicitly clears a preset default. It survives
      // bookmarks, but is omitted from visible controls and server predicates.
      if (entry.value is! BeakAndFilter ||
          (entry.value as BeakAndFilter).filters.isNotEmpty)
        entry.key: entry.value,
  };

  /// A preset badge counts the permanent scope plus that preset, not page filters.
  BeakQuerySpec countQuery(BeakQueryPreset preset) => BeakQuerySpec(
    table: model.table,
    filter: BeakFilter.allOf([
      ?base.filter,
      ?preset.filter,
      ...preset.defaults.values,
    ]),
    search: base.search,
    pagination: const BeakPagination(perPage: 1),
    withTrashed: base.withTrashed,
  );

  /// Replaces user choices atomically, for history navigation or a saved view.
  void restore(BeakQueryState value) {
    _checkState(value);
    if (jsonEncode(value.toJson()) == jsonEncode(_state.value.toJson())) return;
    _state.value = value;
  }

  /// Changes the preset and returns to the first page, retaining user filters.
  ///
  /// A null [preset] selects the unfiltered base view.
  void selectPreset(BeakQueryPreset? preset) => restore(
    _copy(
      preset: preset?.key,
      replacePreset: true,
      replaceColumns: true,
      page: 1,
    ),
  );

  /// Commits the filter drawer only after Apply.
  void applyFilters(Map<String, BeakFilter> filters) =>
      restore(previewFilters(filters));

  /// Builds an unapplied filter candidate, including intentionally cleared defaults.
  BeakQueryState previewFilters(Map<String, BeakFilter> filters) =>
      _copy(filters: _withClearedDefaults(filters), page: 1);

  /// Removes one editable filter, including an inherited preset default.
  void removeFilter(String key) =>
      applyFilters({...effectiveFilters(_state.value)}..remove(key));

  Map<String, BeakFilter> _withClearedDefaults(
    Map<String, BeakFilter> filters,
  ) => {
    for (final preset in presets.where((p) => p.key == _state.value.preset))
      for (final definition in preset.defaults.keys)
        if (!filters.containsKey(definition.key))
          definition.key: const BeakAndFilter([]),
    ...filters,
  };

  /// Clears editable filters and search, retaining permanent and preset scopes.
  void clearFilters() => restore(
    _copy(filters: _withClearedDefaults(const {}), search: '', page: 1),
  );

  /// Replaces search and resets pagination.
  void setSearch(String term) => restore(_copy(search: term, page: 1));

  /// Replaces the list ordering with a typed scalar field.
  void sortBy(BeakColumn column, {bool descending = false}) => restore(
    _copy(sorts: [BeakSort(column.key, descending: descending)], page: 1),
  );

  /// Moves to a one-based page.
  void goToPage(int page) => restore(_copy(page: page));

  /// Changes page length and resets pagination.
  void setPageSize(int perPage) => restore(_copy(page: 1, perPage: perPage));

  /// Available columns for the selected preset.
  List<BeakTableColumn> get availableColumns =>
      presets.where((p) => p.key == _state.value.preset).firstOrNull?.columns ??
      columns;
  String? _columnCacheKey;
  List<BeakTableColumn>? _columnCache;

  /// Selected projection, stable between unrelated query updates.
  List<BeakTableColumn> get currentColumns {
    final keys = _state.value.visibleColumns;
    if (keys == null) return availableColumns;
    final signature = jsonEncode([_state.value.preset, keys]);
    if (_columnCacheKey != signature) {
      _columnCacheKey = signature;
      final available = {
        for (final column in availableColumns) column.key: column,
      };
      _columnCache = [for (final key in keys) available[key]!];
    }
    return _columnCache!;
  }

  /// Stores a typed column selection in URL and saved-view state.
  void chooseColumns(List<BeakTableColumn> value) => restore(
    _copy(
      visibleColumns: [for (final column in value) column.key],
      replaceColumns: true,
    ),
  );

  /// Toggles the overview without altering the query population.
  void setHeaderVisible(bool value) => restore(_copy(showHeader: value));

  BeakQueryState _copy({
    String? preset,
    bool replacePreset = false,
    Map<String, BeakFilter>? filters,
    String? search,
    List<BeakSort>? sorts,
    int? page,
    int? perPage,
    List<String>? visibleColumns,
    bool replaceColumns = false,
    bool? showHeader,
  }) {
    final current = _state.value;
    return BeakQueryState(
      preset: replacePreset ? preset : current.preset,
      filters: filters ?? current.filters,
      search: search ?? current.search,
      sorts: sorts ?? current.sorts,
      page: page ?? current.page,
      perPage: perPage ?? current.perPage,
      visibleColumns: replaceColumns ? visibleColumns : current.visibleColumns,
      showHeader: showHeader ?? current.showHeader,
    );
  }

  void _checkState(BeakQueryState value) {
    _checkPreset(value.preset);
    final keys = value.visibleColumns;
    final available =
        presets.where((p) => p.key == value.preset).firstOrNull?.columns ??
        columns;
    if (keys != null &&
        (keys.isEmpty ||
            keys.toSet().length != keys.length ||
            keys.any((key) => !available.any((column) => column.key == key)))) {
      throw const BeakConfigurationException(
        'The saved columns are no longer available.',
      );
    }
  }

  void _checkPreset(String? key) {
    if (key != null && !presets.any((preset) => preset.key == key)) {
      throw BeakConfigurationException('Unknown list preset "$key".');
    }
  }

  /// Writes only this list's parameter and preserves unrelated query parameters.
  Uri writeUri(Uri uri, {String parameter = 'list'}) => uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      parameter: base64Url.encode(
        utf8.encode(jsonEncode(_state.value.toJson())),
      ),
    },
  );

  /// Reads a bookmarked view. A missing parameter leaves the default untouched.
  static BeakQueryState? readUri(Uri uri, {String parameter = 'list'}) {
    final encoded = uri.queryParameters[parameter];
    if (encoded == null) return null;
    if (encoded.length > 16384) {
      throw const BeakConfigurationException('Saved list state is too large.');
    }
    try {
      final Object? decoded = jsonDecode(
        utf8.decode(base64Url.decode(encoded)),
      );
      return switch (decoded) {
        final Map<String, Object?> value => BeakQueryState.fromJson(value),
        _ => throw const BeakConfigurationException(
          'Invalid saved list state.',
        ),
      };
    } on FormatException {
      throw const BeakConfigurationException('Invalid saved list state.');
    }
  }
}
