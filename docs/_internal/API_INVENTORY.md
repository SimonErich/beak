# API inventory (writers: the public surface, per package)

Not published. The exhaustive list of public types the reference and feature
pages document. Every symbol here already carries dartdoc in source with worked
examples; quote signatures verbatim from the cited files. Paths are
workspace-relative.

Version: pre-1.0 (`0.0.x`, shared line). Each barrel exports a `beak*Version`.

---

## beak_core (`packages/beak_core/lib/beak_core.dart`)
Pure Dart. No Flutter, no worm. The shared vocabulary both sides speak.

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
- `BeakSearchHit`: `table`, `id`, `displayLabel`, `matchedColumnKey`.

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
The Flutter panel. Built on obers_ui / obers_ui_autoforms / obers_ui_charts.

### Panel/config (`src/panel/`)
- `BeakPanel` (HookWidget root): `{config, dataSource?, httpClient?}`.
- `BeakPanelConfig`: `{title, resources, apiBaseUrl, pages=[], auth?,
  maintenance?, theme?, darkTheme?, initialThemeMode=system, sidebarCollapsible,
  sidebarDefaultCollapsed, dashboardStats=[], dashboardCharts=[], notifications?}`;
  `buildRegistry()`.
- `BeakResource`: `{model, icon (BeakIconToken), label?, section?,
  recordActions=[], bulkActions=[], globalActions=[], filters=[],
  viewModes=[BeakTableView()], detail?, formSteps?, formLayout?}`;
  `effectiveLabel`, `route`.
- `BeakIconToken` (extension type over IconData).
- `BeakScreen`: `{path, title, icon, body (BeakBlock), label?, section?,
  showInNav=true, framed=true}`.
- `BeakAuthConfig`: `{register=true, recover=true, onLogin?, onRegister?,
  onRecover?, idleLockTimeout?, lockUserName?, onUnlock?}` (callbacks return
  `Future<bool>`).
- `BeakMaintenanceConfig`: `{maintenanceTitle, maintenanceDescription?,
  estimatedReturn?, comingSoonTitle, comingSoonDescription?, launchAt?}`.
- `BeakThemeController` (`ValueNotifier<OiThemeMode>`).
- `BeakResourceView` (sealed): `BeakTableView({initialSpec?, baseFilter?})`,
  `BeakCalendarView({titleField, startField, endField?, allDayField?,
  categoryField?, mode, label})`, `BeakKanbanView({groupField (BeakEnumColumn),
  titleField, subtitleField?, sortField?, sortDescending, label})`.
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
  `BeakGridBlock({children, columns?, minColumnWidthInPixels?, gapInPixels=16})`,
  `BeakCardBlock({child, title?, subtitle?, footer?})`, `BeakSectionBlock`,
  `BeakTabsBlock({tabs, initialIndex=0})` + `BeakTabBlockItem({label, content,
  icon?})`, `BeakAccordionBlock` + `BeakAccordionBlockItem`,
  `BeakBreadcrumbsBlock` + `BeakBreadcrumbBlockItem`, `BeakMasonryBlock`,
  `BeakThreePaneBlock`, `BeakWizardBlock({steps, stepperStyle, onComplete?})` +
  `BeakWizardStep`, plus `BeakCarouselBlock`, `BeakDividerBlock`,
  `BeakSpacerBlock`, `BeakTimelineBlock` (some categorized as display/data).
- Display: `BeakTextBlock(text,{variant=body})` + `BeakTextVariant`
  {display,h1,h2,h3,h4,body,bodyStrong,small,caption}, `BeakImageBlock`,
  `BeakMarkdownBlock`, `BeakDividerBlock`, `BeakSpacerBlock`, `BeakWidgetBlock`
  (WidgetBuilder escape hatch), `BeakVideoBlock`, `BeakIconGalleryBlock` +
  `BeakIconGalleryItem`.
- Data-bound: `BeakKpiBlock({title, value (BeakAggregateSpec), previous?, target?,
  format=number, currencySymbol, decimals})` + `BeakKpiFormat`
  {number,currency,percent}, `BeakChartBlock`, `BeakTableBlock({model, title?,
  initialSpec?, baseFilter?, actions=[], onRowTap?, heightInPixels=360})`,
  `BeakMetricBlock`, `BeakMapBlock`, `BeakTileMapBlock`, `BeakCarouselBlock`,
  `BeakRadialSliderBlock`, `BeakGalleryBlock`, `BeakTimelineBlock`,
  `BeakBubbleChartBlock`, `BeakCandlestickChartBlock`, `BeakHeatmapChartBlock`.
- UI-kit: `BeakAlertBlock(message,{level=info})` + `BeakAlertLevel`
  {info,success,warning,error}, `BeakBadgeBlock`, `BeakProgressBlock`,
  `BeakRatingBlock`, `BeakIconGalleryBlock`.
- Module: `BeakCalendarBlock`, `BeakKanbanBlock`, `BeakChatBlock`,
  `BeakInboxBlock`, `BeakFileManagerBlock`, `BeakInvoiceBlock`, `BeakProfileBlock`,
  `BeakPricingBlock`, `BeakFaqBlock`. (See beak_frontend inventory in source for
  each block's full field list; quote verbatim.)
- Record-bound (dual-mode): `BeakFieldBlock(column,{label?, layout=stacked})` +
  `BeakFieldLayout` {stacked, inline}, `BeakFieldGroupBlock(columns,
  {columnCount=2})`, `BeakRelationBlock(relationship,{title?})`.

### Detail + forms
- `BeakRecordScope` (InheritedWidget `{model, record, child}`; `of`).
- `BeakDetailView` (HookWidget `{model, record}`).
- `BeakRelationManager` (HookWidget; attach/detach/delete for to-many).
- `BeakDataForm`: `{model, dataSource, recordId?, sections?, steps?, layout?,
  onSaved?, uploader?, filePicker?}`.
- `BeakFormStep`: `{title, columns, subtitle?, description?, icon?}`.
- `BeakFormScope` (InheritedWidget; `of`).
- `BeakFormController` (extends `OiAfController<BeakFormSlot, BeakRecord>`):
  `slotOf`, `slotOfForeignKey`, `hasFieldFor`, `valueOf`, `setValue`, `prefill`.
- `BeakFormSection` (`{title, columns, visibleWhen?}`), `BeakFormValues`,
  `BeakFormPredicate` typedef, `BeakFormSlot` enum.
- `BeakFilePicker` typedef, `BeakUploadField`, `BeakBelongsToField`,
  `BeakBelongsToManyField`; `beakFormColumnsOf(block)`.

### Overlays / actions / filters / table / dashboard / data / DI
- `BeakOverlays` (`const BeakOverlays(context)`): `confirm`, `modal`, `dialog<T>`,
  `sheet<T>`, `toast`. `BeakActionContext` (`{buildContext, model, dataSource,
  router, refresh?}`; `overlays`).
- `BeakAction` (sealed `{key, label, icon?, color?, requiresConfirmation}`):
  `BeakRecordAction`, `BeakBulkAction`, `BeakGlobalAction`; `BeakActionButton`;
  built-in view/edit/delete/create.
- `BeakFilterDef` (sealed `{column, label}`): `BeakSelectFilter`, `BeakBoolFilter`,
  `BeakTextFilter`, `BeakDateRangeFilter`; `BeakFilterBar`.
- `BeakDataTable` (HookWidget; server-side sort/filter/paginate), `BeakTableAction`.
- `BeakStat`/`BeakStatCard`, `BeakChart`/`BeakChartCard`, `BeakDashboard`;
  `BeakChartType` {line,bar,pie,donut,area,radar,funnel}, `BeakChartPoint`,
  `BeakChartMapper`, `BeakBubblePoint/Mapper`, `BeakCandle/Mapper`,
  `BeakMatrixCell/Mapper`, `beakChartWidget`.
- `BeakResourceRepository` (returns `BeakResult<T>`), `HttpBeakDataSource`,
  `ReferenceCache`, `BeakUploadRepository`, `BeakOptimistic.mutate`.
- `beakLocator` (package-scoped GetIt), `registerBeakDependencies({config,
  locator?, dataSource?, httpClient?, tokenProvider?})`, `BeakViewModel`.

---

## beak_backend (`packages/beak_backend/lib/beak_backend.dart`)
Shelf server. The only package that imports worm.

- `BeakServer`: `{config, dataSource, registry, storage?, transformRunner?,
  policy=BeakAllowAllPolicy, authSessions?, router?, authGuard?, onRequest?,
  onUnexpectedError?}`; `handler`; `start() -> HttpServer`.
- `beakApiRouter({registry, dataSource, validation, policy, auth?, uploads?, now?,
  generateId?}) -> Handler` (mounts `/api/auth`, `GET /api/search`, per-model
  `/api/{table}` with export + upload routes).
- `beakResourceRouter(service, {policy}) -> Router`: `POST /query`,
  `POST /aggregate`, `POST /batch`, `POST /`, `GET /<id>`, `PATCH /<id>`,
  `DELETE /<id>`, `POST /<id>/relations/<relationKey>/attach|detach`.
- `BeakCrudHandlers`, `BeakResourceService`, `ValidationService`.
- Auth (`src/auth/`): `BeakPolicy` (`canView/canCreate/canUpdate/canDelete/
  canDeleteUpload`), `BeakAllowAllPolicy`, `enforcePolicyDecision`, `BeakPrincipal`,
  `BeakAuthGuard`, `TokenSessionAuthGuard`, `BeakAuthSessions`, `BeakUserAccount`,
  `hashBeakPassword`, `BeakAuthHandlers`, `beakAuthRouter`, `TokenSessionStore`,
  `InMemoryTokenSessionStore`, `beakAuthMiddleware`, `beakPrincipal`.
- Data/worm (`src/data/worm/`): `WormDataSource(registry, {adapter, now?})`,
  `WormRecordModel`, `wormFieldForColumn`, `wormNumericFieldForColumn`,
  `WormQueryTranslator`, `postgresConnectionConfig`, `postgresAdapterFromUrl`,
  `initializeWormPostgres`.
- Uploads/export/search: `UploadService`, `BeakUploadHandlers`,
  `registerUploadRoutes`, `CsvExportService`, `BeakExportHandlers`,
  `registerExportRoutes`, `GlobalSearchService`, `BeakSearchHandlers`.
- Middleware (`src/server/middleware/`): `beakRequestLogMiddleware`,
  `BeakRequestLogEntry`, `beakCorsMiddleware`, `beakJsonMiddleware`,
  `readJsonObject`, `readBeakSpec`, `beakErrorMappingMiddleware`.
- Storage wiring: `createDefaultStorageRegistry`, `resolveStorage`.
- Config: `BeakBackendConfig` (`{databaseUrl, port=8080, host='0.0.0.0'}`,
  `fromEnv`), `BeakEnv` (`parse/loadFile/resolve`), `generateUuidV4`.

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
  `S3ObjectClient` (interface), `MinioS3ObjectClient`.

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
