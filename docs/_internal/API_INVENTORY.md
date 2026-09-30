# API inventory (writers: the public surface, per package)

Not published. A navigation aid for writers, not an exhaustive signature
reference. Verify constructor fields against current source before writing an
example. Public barrels and dartdoc are authoritative; paths below are
workspace-relative.

Version: pre-1.0 (`0.9.0`, lockstep line). Each barrel exports a `beak*Version`.

---

## beak_core (`packages/beak_core/lib/beak_core.dart`)
Pure Dart. No Flutter, no worm. The shared vocabulary both sides speak.

### Declarative fields and commits
- `BeakFieldRef<T>`, `BeakScalarField<T>`, `BeakToOneField`, `BeakToManyField`
  (`src/model/beak_field_ref.dart`): typed paths/readers, scalar predicates,
  `.matches` / `.any` grouped relation predicates, and `BeakOptionQuery`.
- `BeakDraftReader`: tracked typed reads implemented by form drafts; generated
  nullable `as<Model>` accessors delegate through this seam.
- `BeakCommitDataSource`, `BeakCommitCapabilities`, `BeakSavePlan`,
  `BeakSaveOperation`, `BeakRecordRef`, `BeakSaveResult` (`src/data/beak_commit.dart`):
  graph persistence and explicit per-operation outcomes.
- `BeakStagedCommitDataSource`: capability fallback for ordinary CRUD sources.
- `BeakRelationFilter`: one child satisfies the grouped filter.
- `BeakFutureDate`: client/server future-date validation.

### Columns (`src/columns/`)
- `BeakColumn` (sealed base, `beak_column.dart`): `key`, `label`, `visibleOn`
  (`Set<BeakContext>`, default table/form/detail), `sortable`, `searchable`,
  `filterable`, `rules` (`List<BeakRule>`); abstract `renderConfig`, `valueType`;
  method `intentFor(BeakContext)`.
- `BeakUploadColumn` (sealed intermediate): adds `storagePath`, `maxSizeInBytes`,
  `allowedTypes` (`List<BeakFileType>`).
- Leaf columns (13): `BeakStringColumn` (`placeholder`, `maxLength`),
  `BeakTextColumn`, `BeakIntColumn` (`min`, `max`), `BeakDecimalColumn`
  (`precision`=2, `prefix`, `suffix`), `BeakBoolColumn` (`trueLabel`,
  `falseLabel`), `BeakDateTimeColumn` (`format` `BeakDateFormat`; `withFormat`),
  `BeakEnumColumn<T extends Enum>` (`values`, `defaultValue`, `badgeColors`,
  `labelOf`; `badgeColorFor`, `labelFor`, `valueByName`), `BeakJsonColumn` (JSON
  as text; `valueType` is String), `BeakRichTextColumn`, `BeakColorColumn`,
  `BeakImageColumn` extends upload (`maxDimensions`, `aspectRatio`, `thumbnail`,
  `transforms`; `allowedTypes` defaults images), `BeakFileColumn` extends upload,
  `BeakCustomColumn` (`tag` `BeakColumnTag`).
- `BeakDateFormat` enum: standard, relative, dateOnly, timeOnly, iso.
- `BeakRenderConfig` (`beak_render_config.dart`): table/form/detail/filter
  intents; `.uniform(intent)`; `intentFor(context)`.
- `BeakJson` sealed tree (`beak_json.dart`): `BeakJsonObject/Array/String/Number/
  Bool/Null`; statics `decode`, `fromEncodable`; `toEncodable`, `encode`.

### Semantic types, formatting and validation
- `BeakColumn.semantic`, `defaultValue`: shared metadata with physical storage
  codecs; `BeakSemantic`, `BeakSemanticKind`, `BeakPrimitiveType` and
  `BeakObjectSchema` (`src/columns/beak_semantic.dart`).
- `BeakDate`, `BeakTime`, `BeakDecimal` (`src/columns/beak_semantic_values.dart`):
  calendar/time values and exact integer-unit decimals; generated typed readers,
  writers and predicates preserve the domain type.
- `BeakFormatPolicy`, `BeakValueFormat` (`src/formatting/`): shared locale,
  explicit timestamp timezone, number, date, money, percent and structured-value
  display; serializable policy for CSV export.
- `BeakValidation` (`src/validation/`): metadata, semantic, scalar and record
  validation used by forms and authoritative writes.
- `BeakRecordRule`, `BeakWhen`, `BeakRequiredIf`, `BeakSameAs`, `BeakBeforeField`,
  `BeakAfterField`, `BeakCount`, `BeakDistinct`, `BeakSum`: typed model rules.
- `BeakAsyncRecordRule`, `BeakUnique`, `BeakExists`, `BeakFieldMatch`,
  `BeakAsyncValidation`: trusted datasource-backed rules.
- `BeakValidationDataSource`, `BeakValidationRequest`, `BeakValidationReport`:
  optional preflight capability; normal writes independently repeat validation.
- `BeakManagedUploadClient.discardUpload`, `BeakUploadUrlClient.uploadUrl`:
  optional cleanup and stored-file URL capabilities, implemented by BeakClient.

### Context/intents (`src/context/`)
- `BeakContext` enum: table, form, detail, filter.
- `BeakRenderIntent` enum: text, number, currency, badge, image, thumbnail,
  boolean, date, relativeDate, relationLink, relationBadges, richText, color,
  json, custom.

### Relationships (`src/relations/`)
- `BeakRelationship` (sealed): `key`, `label`, `relatedTable`, `displayColumnKey`,
  `searchColumnKeys`; getters `effectiveSearchColumnKeys`, `cardinality`,
  `renderConfig`; `displayLabelOf(record)`, `intentFor(context)`.
- `BeakRelationCardinality` enum: one, many.
- `BeakBelongsTo` (`foreignKey`), `BeakHasOne` (`foreignKey`),
  `BeakHasMany` (`foreignKey`, `onDelete`=restrict),
  `BeakBelongsToMany` (`pivotTable`, `foreignPivotKey`, `relatedPivotKey`,
  `allowCreate`, `maxAllowed`, `onDelete`=cascade).
- `BeakOnDelete` enum: cascade, ormCascade, restrict, setNull, setDefault,
  noAction (mirrors worm 1:1).

### Query spec (`src/query/`)
- `BeakQuerySpec`: `table`, `filter`, `sorts`, `search`, `relationLoads`,
  `pagination`, `withTrashed`; builders `withFilter`, `orderBy`, `withRelation`,
  `searching`, `paginate`; `toJson`/`fromJson`.
- `BeakSearch`: `term`, `columnKeys`.
- `BeakFilter` (sealed): statics `allOf`, `fromJson`. `BeakFieldFilter`
  (`{column, operator, value}` and `.forKey`), `BeakAndFilter`, `BeakOrFilter`.
- `BeakOperator` enum: eq, neq, gt, gte, lt, lte, like, ilike, contains,
  startsWith, endsWith, isNull, isNotNull, inList, notInList, between, notBetween.
- `BeakValue` (sealed): statics `of`, `fromJson`; `raw`, `toJson`.
  `BeakStringValue`, `BeakIntValue`, `BeakDoubleValue`, `BeakBoolValue`,
  `BeakDateTimeValue` (tagged), `BeakNullValue`, `BeakListValue`.
- `BeakRecord`: `{values, relations}`; `fromRow`, `fromJson`; `operator[]`,
  `values`, `relations`, `toRow`, `toJson`.
- `BeakPage<T>`: `items/total/page/perPage`; `fromJson`, `toJson`.
- `BeakPagination`: `page`=1, `perPage`=25 (asserts >=1).
- `BeakSort`: `columnKey`, `descending`.
- `BeakRelationLoad`: `relationKey`, `filter`, `nested` (recursive).
- `BeakAggregateSpec`: `.count/.sum/.avg`, `.forKey`, `fromJson`;
  `table/function/columnKey/filter/withTrashed`. `BeakAggregateFunction` enum:
  count, sum, avg (`requiresColumn`).

- `BeakSummarySpec`, `BeakSummaryMeasure`, `BeakSummaryRow`, `BeakSummaryResult`:
  grouped count/sum queries with an explicit result bound and truncation flag.
- `BeakSummaryDataSource`, `BeakExportDataSource`, `BeakExportFormat`: optional
  source capabilities for authorized population summaries and explicit CSV projections.

### Model / client / data (`src/model|client|data/`)
- `BeakModel` (@immutable abstract base): abstract `table`, `displayColumnKey`,
  `columns`; overridable `relationships`, `softDeletes`, `primaryKey`; methods
  `primaryKeyOf`, `columnsFor`, `columnByKey`, `relationshipByKey`.
- `BeakModelRegistry`: `register`, `byTable`, `byTableOrThrow`, `all`.
- `BeakDataSource` (interface): `query`, `getOne`, `create`, `update`,
  `delete({force})`, `batchGet`, `attach`, `detach`, `aggregate`.
- `BeakUploadClient`: `upload(table, columnKey, BeakUpload)`.
- `BeakClient`: `{baseUrl, httpClient?, tokenProvider?}`; data-source methods plus
  `upload`, `export`, `search`, `close`. Maps error bodies to typed exceptions by
  `code`. Documents every REST route.

### Common (`src/common/`)
- `BeakException` (sealed): `code`, `message`. `BeakValidationException`
  (`fieldErrors`), `BeakNotFoundException`, `BeakAuthenticationException`,
  `BeakAuthorizationException`, `BeakConfigurationException`,
  `BeakStorageException`, `BeakConflictException`.
- `BeakColor` enum: primary, secondary, success, warning, error, info, muted.
- `BeakResult<T>` (sealed): `BeakOk`/`BeakErr`; `isOk`, `valueOrThrow`, `fold`,
  `map`.

### Rules (`src/rules/`) — sealed `BeakRule`: `id`, `validate(Object?) -> String?`
`BeakRequired`, `BeakMin(min)`, `BeakMax(max)`, `BeakMinLength(minLength)`,
`BeakMaxLength(maxLength)`, `BeakPattern(regex,{message})`, `BeakEmail`,
`BeakUrl`, `BeakInList<T>(allowed)`, `BeakAllowedFileTypes(allowedTypes)`,
`BeakMaxFileSize(maxSizeInBytes)`.

### Search
- No search type. A search is `BeakQuerySpec.searching(term, fields)` sent to
  `POST /api/{table}/query`; the panel's command bar uses `globalSearchSources`.

### Storage (`src/storage/`)
- `BeakStorageDriver` (interface): `id`, `put`, `get`, `delete`, `url`, `exists`.
- `BeakStorageConfig` (sealed): `driverId`. `BeakS3Config`
  (`endpoint,bucket,accessKey,secretKey,region,usePathStyle,publicBaseUrl`),
  `BeakFtpConfig` (`host,port=21,user,password,baseDir,publicBaseUrl`),
  `BeakLocalDiskStorageConfig` (`rootDir,publicBaseUrl`),
  `BeakMemoryStorageConfig`.
- `BeakStorageRegistry`: pre-registers memory+local; `register`, `resolve`,
  `driverIds`. `BeakStorageDriverFactory` typedef.
- `BeakStorageKeys` (abstract final): `appendToBaseUrl`, `join`, `validate`.
- `BeakStoredFile`: `key,url,sizeInBytes,mimeType,widthInPixels?,heightInPixels?,
  variants`. `BeakStoredFileVariant`.
- `BeakUpload`: `filename,mimeType,bytes`; `sizeInBytes`, `extension`.
- `BeakUploadValidator` (const): `validate(...) -> BeakResult<BeakUpload>`;
  `aspectRatioTolerance`.
- Built-in drivers: `BeakLocalDiskStorageDriver` (+ `.fromConfig`),
  `BeakMemoryStorageDriver`.
- File rules: `BeakFileType` enum (jpeg,png,webp,gif,svg,pdf,csv,json,zip,mp4,mp3;
  `mimeType`, `extensions`, `isImage`, static `images`), `BeakDimensions`
  (`widthInPixels,heightInPixels`, `.square`).
- Transforms: `BeakImageTransform` (sealed; `.resize/.format/.webp/.thumbnail`),
  `BeakResizeTransform`, `BeakFormatTransform` (+ `.webp`),
  `BeakThumbnailTransform`; `BeakImageFit` {cover,contain,fill},
  `BeakImageFormat` {jpg,png,webp}; `BeakTransformRunner` interface,
  `BeakTransformedImage`.

---

## beak_frontend (`packages/beak_frontend/lib/beak_frontend.dart`)

### Composed pages and queries
- `BeakListDefinition`, `BeakQueryPreset`, `BeakQueryController`, `BeakQueryState`,
  `BeakQueryScope`: one versioned query for lists, summaries, filters and URL history.
- `BeakTableColumn`, `BeakRecordTemplate`, `BeakActionPresentation`: typed composite
  cells and explicit action placement without replacing CRUD/command handling.
- `BeakSavedViewStore.model`, `BeakListExport`, `BeakRefreshPolicy`: persisted
  query views, server-side CSV projection, and optional shared foreground polling.
- `BeakNavigation`, `BeakNavigationSection`, `BeakNavigationItem`: primary rails,
  contextual navigation and links retaining list return state.
- `BeakFormHeader`, `BeakFormTemplate`, `BeakFormSummary`, `BeakFormMetrics`,
  `BeakFormNotice`, `BeakFormCapacity`, `BeakFormProgress`, `BeakFormTimeline`,
  `BeakFormActions`: session-bound presentation regions sharing draft state.
- `EnumLabels<T>` schema annotation: stable enum wire names with generated
  readable display labels; semantic badge colors resolve through the panel theme.

### Semantic inputs and media
- `BeakInputPresentation`, typed `.input()` and choice helpers: model-driven
  editors for semantic values, nullable controls, lists and embedded objects.
- `.inputAttribute`, `.inputRange`, `.inputDateRange`: dependent typed attribute
  editors and paired field presentation while preserving independent model values.
- `BeakFormatting`: Flutter policy inheriting the shared `BeakFormatPolicy`.
- `BeakDraftUploads`: session-owned staging, upload preparation, receipt-aware
  adoption/recovery and observable cleanup; `BeakFormSession.uploadCleanup`.
- `beakPickFile`, `BeakStoredImage`: default native picker and optional transport
  URL resolution with loading/error state.
- `BeakGallery`, `BeakGalleryView`, `.galleryForm`: owned image relationships,
  captions, metadata, local ordering and removal using the normal graph lifecycle.


### Configured resource forms
- `BeakResourceScreen`, `BeakScreenRole`, `BeakFormScreen`, `BeakWizardScreen`,
  `BeakTableScreen`, `BeakCustomResourceScreen` (`src/panel/beak_resource_screen.dart`).
- `BeakFormNode`, `BeakFormLayout`, `BeakCard`, `BeakColumns`, `BeakWizardStep`,
  `BeakInput`, `BeakRelationInput`, `BeakRelationTable`, `BeakCalculated`,
  `BeakFormWidget`, `BeakRemoveBehavior` (`src/form/beak_form_layout.dart`).
- `BeakConfiguredForm`, `BeakFormSession`, `BeakDraftRecord`, `BeakFormReader`:
  model-derived and authored forms sharing reactive local graph state.
- `BeakDependencyScope` / `beakDependencies(context)`: per-panel service scope;
  `beakLocator` remains a compatibility fallback for explicit standalone setup.

The Flutter panel. Built on obers_ui / obers_ui_autoforms / obers_ui_charts.

### Panel/config (`src/panel/`)
- `BeakPanel` accepts explicit `resources:` and the everyday options, or a
  complete `config:` (a generated or host-built `BeakPanelConfig`), never both.
  Both forms support the transport overrides `dataSource:` and `httpClient:`.
- `BeakPanelConfig`: `{title, resources, apiBaseUrl, pages=[], auth?,
  maintenance?, theme?, darkTheme?, initialThemeMode=system, locale?,
  supportedLocales=BeakLocalizations.supportedLocales, localizationsDelegates=[],
  sidebarCollapsible, sidebarDefaultCollapsed, formatting?, home?,
  notifications?, navigation?, refreshPolicy?, shellActions?, mapException?}`;
  `buildRegistry()`.
- `BeakResource`: `{model, icon (BeakIconToken), title?, navigationTitle?,
  navigationGroup?, navigationRank=0, screens=[], globalSearchSources=[],
  recordActions=[], bulkActions=[], globalActions=[], filters=[], ...}`;
  `effectiveLabel`, `route`.
- `BeakIconToken` (extension type over IconData).
- `BeakScreen`: `{path, title, icon, body (BeakBlock), navigationTitle?,
  navigationGroup?, showInNav=true, framed=true}`.
- `BeakAuthConfig`: `{adapter?, register=false, recover=false,
  idleLockTimeout?, lockUserName?, onUnlock?}` (unlock callbacks return
  `Future<bool>`).
- `BeakMaintenanceConfig`: `{maintenanceTitle, maintenanceDescription?,
  estimatedReturn?, comingSoonTitle, comingSoonDescription?, launchAt?,
  redirectTo?}`.
- `BeakThemeController` (`ValueNotifier<OiThemeMode>`).
- Views other than the table are blocks on a `BeakScreen`: `BeakKanbanBlock`
  and `BeakCalendarBlock` (see Blocks). There is no `viewModes` on a resource.
- Command bar: `openBeakCommandBar(context, config)`,
  `beakNavigationCommands(config, go)`.
- Notifications: `BeakNotificationSource({model, titleField, bodyField?,
  timeField?, readField?, categoryField?})`, `BeakNotificationBell`.
- Routing: `createBeakRouter(config) -> GoRouter`; `BeakRoutes` (static
  `list/create/show/edit`).
- Pages: `BeakResourceListPage/ShowPage/CreatePage/EditPage`, `BeakScreenView`,
  `BeakPageScaffold`.

### Blocks (`src/blocks/`) — sealed `BeakBlock` (+ optional `span` `BeakSpan`),
one `BeakBlockHost` renderer. ~48 variants:
- Layout: `BeakColumnBlock({children, gapInPixels=16})`, `BeakRowBlock`,
  `BeakGridBlock({children, columns?, minColumnWidthInPixels?, minChildWidthInPixels=240, gapInPixels=16})`,
  `BeakCardBlock({child, title?, subtitle?, footer?})`, `BeakSectionBlock`,
  `BeakTabsBlock({tabs, initialIndex=0})` + `BeakTabBlockItem({label, content,
  icon?})`, `BeakAccordionBlock` + `BeakAccordionBlockItem`,
  `BeakBreadcrumbsBlock` + `BeakBreadcrumbBlockItem`, `BeakMasonryBlock`,
  `BeakThreePaneBlock`, plus `BeakCarouselBlock`, `BeakDividerBlock`,
  `BeakSpacerBlock`, `BeakTimelineBlock` (some categorized as display/data).
- Display: `BeakTextBlock(text,{variant=body})` + `BeakTextVariant`
  {display,h1,h2,h3,h4,body,bodyStrong,small,caption}, `BeakImageBlock`,
  `BeakMarkdownBlock`, `BeakDividerBlock`, `BeakSpacerBlock`, `BeakWidgetBlock`
  (WidgetBuilder escape hatch), `BeakVideoBlock`, `BeakIconGalleryBlock` +
  `BeakIconGalleryItem`.
- Data-bound: `BeakMetricBlock({label, aggregate, icon?, format=number
  (BeakValueFormat: number, currency, percent), minorUnits=false, scale=2,
  unit?, previous?, target?})`, `BeakChartBlock`, `BeakTableBlock({model,
  title?, initialSpec?, baseFilter?, actions=[], onRowTap?,
  heightInPixels=360})`, `BeakMapBlock`, `BeakTileMapBlock`, `BeakCarouselBlock`,
  `BeakRadialSliderBlock`, `BeakGalleryBlock`, `BeakTimelineBlock`,
  `BeakBubbleChartBlock`, `BeakCandlestickChartBlock`, `BeakHeatmapChartBlock`.
- UI-kit: `BeakAlertBlock(message,{level=info})` + `BeakAlertLevel`
  {info,success,warning,error}, `BeakBadgeBlock`, `BeakProgressBlock`,
  `BeakRatingBlock`, `BeakIconGalleryBlock`.
- Module: `BeakCalendarBlock`, `BeakKanbanBlock`, `BeakChatBlock`,
  `BeakInboxBlock`, `BeakFileManagerBlock`, `BeakInvoiceBlock`, `BeakProfileBlock`,
  `BeakPricingBlock`, `BeakFaqBlock`. (See beak_frontend inventory in source for
  each block's full field list; quote verbatim.)
- Record presentation: `BeakFieldBlock(column,{label?, layout=stacked})` +
  `BeakFieldLayout` {stacked, inline}, `BeakFieldGroupBlock(columns,
  {columnCount=2})`, `BeakRelationBlock(relationship,{title?})`.

### Detail + configured forms
- `BeakRecordScope` supplies read-only record presentation to the record blocks.
- `BeakRelationManager` manages persisted to-many relationships on detail pages.
- `BeakFormScreen`, `BeakWizardScreen` and `BeakScreenRole` assign read,
  create and edit screens to resources.
- `BeakFormLayout`, `BeakFormSections`, `BeakSection`, `BeakCard`, `BeakColumns`,
  `BeakTabs`, `BeakTab`, `BeakWizardStep` describe the configured layout.
- Typed scalar references expose input helpers; to-many references expose
  `tableForm`, with nested rows, advanced forms and summaries.
- `BeakConfiguredForm` renders a layout against `BeakFormSession`.
- `BeakDraftRecord`, `BeakDraftReader` and `BeakDraftScope` expose draft values,
  nested rows, errors and inherited editing state to custom code.
- `BeakFormWidget` embeds custom presentation; `showOnRead` controls whether an
  editing-only component appears in read mode.
- `BeakFormDrafts`, `BeakDraftStore`, `BeakMemoryDraftStore` and
  `BeakBrowserDraftStore` configure checkpoint persistence. Verify current
  signatures under `src/form/` before quoting.
- `BeakImportView`, `BeakBulkEditView` and `BeakBulkAction.edit` provide typed
  preview, validation and per-record commit outcomes for batch work.

### Overlays / actions / filters / table / dashboard / data / DI
- `BeakOverlays` (`const BeakOverlays(context)`): `confirm`, `ask`
  (`BeakConfirmResult`), `modal`, `dialog<T>`, `sheet`, `sheetWithResult<T>`,
  `toast`. `BeakActionContext` (`{buildContext, model, dataSource,
  router, refresh?}`; `overlays`).
- `BeakAction` (sealed `{key, label, icon?, color?, requiresConfirmation}`):
  `BeakRecordAction`, `BeakBulkAction`, `BeakGlobalAction`; `BeakActionButton`;
  built-in view/edit/delete/create.
- `BeakFilterDef` (sealed `{column, label}`): `BeakSelectFilter`, `BeakBoolFilter`,
  `BeakTextFilter`, `BeakDateRangeFilter`; `BeakFilterBar`.
- `BeakDataTable` (HookWidget; server-side sort/filter/paginate), `BeakTableAction`.
- No dashboard type: a custom overview is a `BeakScreen` with `path: '/'`.
  `BeakChartType` {line,bar,pie,donut,area,radar,funnel}, `BeakChartPoint`,
  `BeakChartMapper`, `BeakBubblePoint/Mapper`, `BeakCandle/Mapper`,
  `BeakMatrixCell/Mapper`.
- `BeakResourceRepository` (returns `BeakResult<T>`), `HttpBeakDataSource`,
  `BeakUploadRepository`, `BeakOptimistic.mutate`.
- `beakLocator` (package-scoped GetIt), `registerBeakDependencies({config,
  locator?, dataSource?, httpClient?, tokenProvider?})`, `BeakViewModel`.

---

## beak_backend (`packages/beak_backend/lib/beak_backend.dart`)
Shelf server. The only package that imports worm.

- `BeakServer`: `{config, dataSource, registry, storage?, transformRunner?,
  policy=BeakAllowAllPolicy, authSessions?, router?, authGuard?, onRequest?,
  onUnexpectedError?}`; `handler`; `start() -> HttpServer`.
- `beakApiRouter({registry, dataSource, policy, auth?, storage?,
  transformRunner?, now?, generateId?, preparePlan?, finalizePlan?, graphOnly,
  ...}) -> Handler` (mounts `/api/auth`, per-model `/api/{table}` with export
  and upload routes, and `POST /api/commits`).
- The per-model router (internal, not exported): `POST /query`,
  `POST /aggregate`, `POST /validate`, `POST /batch`, `POST /`, `GET /<id>`, `PATCH /<id>`,
  `DELETE /<id>`, `POST /<id>/relations/<relationKey>/attach|detach`.
- Auth (`src/auth/`): `BeakPolicy` (`canView/canCreate/canUpdate/canDelete/
  canDeleteUpload`), `BeakRowPolicy`, `BeakUploadReadPolicy.canViewUpload`,
  `BeakAllowAllPolicy`, `enforcePolicyDecision`, `BeakPrincipal`,
  `BeakAuthGuard`, `TokenSessionAuthGuard`, `BeakAuthSessions`, `BeakUserAccount`,
  `hashBeakPassword`, `BeakAuthHandlers`, `beakAuthRouter`, `TokenSessionStore`,
  `InMemoryTokenSessionStore`, `beakAuthMiddleware`, `beakPrincipal`.
- Data/worm (`src/data/worm/`): `WormDataSource(registry, {adapter, now?})`,
  `adapterFromUrl`, `initializeBeakDatabase`, `BeakBaselineMigration`,
  `BeakBlueprint`. The query translator and record model are internal.
- Uploads and CSV export are wired by `beakApiRouter`; their services and
  handlers are internal. There is no global search endpoint: the panel searches
  each model through `globalSearchSources`.
- Middleware (`src/server/middleware/`): `beakRequestLogMiddleware`,
  `BeakRequestLogEntry`, `beakCorsMiddleware`, `beakJsonMiddleware`,
  `readJsonObject`, `readBeakSpec`, `beakErrorMappingMiddleware`.
- Storage wiring: `createDefaultStorageRegistry`, `resolveStorage`.
- Config: `BeakBackendConfig` (`{databaseUrl, port=8080, host='0.0.0.0'}`,
  `fromEnv`), `BeakEnv` (`parse/loadFile/resolve`).

---

## beak_cli (`packages/beak_cli/lib/beak_cli.dart`)
- `createBeakRunner(BeakCliEnvironment) -> CommandRunner<int>`.
- `BeakCliEnvironment` (`{out, rootDirectory, now, probe}`, `.production()`,
  `writeFile`), `BeakPortProbe` typedef.
- Commands: `MakeResourceCommand` (`make:resource Name --fields ...`),
  `MakeModelCommand`, `MakeColumnsCommand`, `MakeMigrationCommand`,
  `DoctorCommand`.
- `BeakFieldSpec` (`{name, kind}`, `parse`, `parseList`, `camelName`),
  `BeakFieldKind` {string,text,integer,decimal,boolean,dateTime} (`parse`).
- Templates: `generateWormModel`, `generateBeakColumns`, `generateMigration`,
  `snakeCaseOf`, `tableNameOf`, `camelCaseOf`.

---

## beak_storage_s3 (`packages/beak_storage_s3/lib/beak_storage_s3.dart`)
- `registerS3Storage(BeakStorageRegistry)`, `S3StorageDriver` (`+.fromConfig`),
  `S3ObjectClient` (interface), `HttpS3ObjectClient`.

## beak_storage_ftp (`packages/beak_storage_ftp/lib/beak_storage_ftp.dart`)
- `registerFtpStorage(BeakStorageRegistry)`, `FtpStorageDriver` (`+.fromConfig`),
  `FtpTransport` (interface), `SocketFtpTransport`, `FtpProtocolException`.

## beak_image (`packages/beak_image/lib/beak_image.dart`)
- The `BeakTransformRunner` implementation (pixel codec) that core omits; used by
  `BeakServer`'s default transform runner.

---

## worm (vendored, used only by beak_backend)
App authors touch worm directly in exactly two places: migrations
(`extends Migration`, registered in `bin/worm.dart`) and seeders/factories. The
schema DSL: `table.idUuid()`, `.string(k,length:)`, `.text`, `.decimal`,
`.integer`, `.boolean`, `.uuid`, `.dateTime`, `.timestamps()`, `.softDeletes()`,
`.unique([...])`, `.index([...])`, `.foreign(column:, references:, onTable:,
onDelete: OnDelete...)`. Full worm docs: `packages/worm/docs/`.
