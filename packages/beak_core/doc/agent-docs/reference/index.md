# Reference

> Look up any annotation, column type, rule, builder, block, option, REST route, CLI command, environment variable or exception of Beak.

This section is for lookup, not for reading top to bottom. Every page is a complete table for one surface of Beak, with signatures quoted from the source, defaults read from the source, and the file that defines each thing. If you know the name and want the signature, or you know the job and want the name, start here.

Each page in [Guides](../guides/index.md) teaches the same APIs with reasons and worked examples. These pages state them flat, so a parameter is findable without rereading an explanation.

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Find the declaration for a common task without knowing its name | [Cheatsheet](cheatsheet.md) | one resource end to end, then task to API tables |
| See every annotation a schema class carries | [Annotations](annotations.md) | `@Resource`, `@Column`, `@Display`, relationships, and the `beak prepare` errors |
| Know which column a Dart type becomes | [Field types](field-types.md) | every column type, semantic kinds, options and defaults |
| Bound or check a value | [Validation rules](validation-rules.md) | column, record and async rules, and the message each emits |
| Guard a state change or calculate a value | [Behavior and actions](behavior-and-actions.md) | `BeakModelBehavior`, value lifecycles, model commands, panel actions |
| Read the code `beak prepare` writes | [Generated files and symbols](generated-files.md) | each generated file and the symbols per schema class |
| Put an editor in a form | [Input builders](input-builders.md) | every `inputX` builder on a typed field |
| Put a control in a list | [Filter builders](filter-builders.md) | every `xFilter` builder and its predicate |
| Arrange screens and forms | [Screens and form layouts](screens-and-layouts.md) | screens, roles, layout containers and presentation nodes |
| Compose a page from blocks | [Blocks](blocks.md) | all 47 block classes with constructors and data loading |
| Build or read a query | [Queries](queries.md) | `BeakQuerySpec`, filters, operators, values, pagination, summaries |
| Configure the panel and its resources | [Panel and resource options](panel-options.md) | `BeakPanel`, `BeakPanelConfig`, `BeakResource`, auth, navigation, formatting |
| Configure the project file | [beak.yaml](beak-yaml.md) | every key, its default, and what each way of booting reads |
| Configure the server and storage | [Configuration and environment](configuration.md) | environment variables, override files, `BeakBackendConfig`, storage configs |
| Run the tool | [CLI commands](cli-commands.md) | every command, flag, written file, transcript and exit code |
| Call the API | [REST API](rest-api.md) | every route, body, status code and the error envelope |
| Handle a failure | [Exceptions](exceptions.md) | the `BeakException` family, codes and HTTP statuses |
| Choose an import | [Libraries](libraries.md) | the eight libraries of `package:beak` and what each may reach |
| Know what a package owns | [Packages](packages.md) | every package, its dependencies, the examples and the version pins |
| Decode a term | [Glossary](glossary.md) | one line per term, linked to the page that explains it |

## Find a page by a name you have seen

| The name looks like | Page |
| --- | --- |
| `@Resource`, `@Column`, `@BelongsTo`, `@Display` | [Annotations](annotations.md) |
| `BeakStringColumn`, `BeakText`, `BeakDecimal`, `BeakSemantic` | [Field types](field-types.md) |
| `BeakMin`, `BeakMaxLength`, `BeakCount`, `BeakUnique`, `BeakExists` | [Validation rules](validation-rules.md) |
| `BeakModelBehavior`, `BeakModelAction`, `BeakRecordAction` | [Behavior and actions](behavior-and-actions.md) |
| `ProductModel.name.inputText()`, `.tableForm()` | [Input builders](input-builders.md) |
| `ProductModel.name.textFilter()`, `BeakChoiceFilter` | [Filter builders](filter-builders.md) |
| `BeakFormScreen`, `BeakTableScreen`, `BeakCard`, `BeakWizardStep` | [Screens and form layouts](screens-and-layouts.md) |
| `BeakMetricBlock`, `BeakChartBlock`, anything `Beak...Block` | [Blocks](blocks.md) |
| `BeakQuerySpec`, `BeakFilter`, `BeakSort`, `BeakPage` | [Queries](queries.md) |
| `BeakPanel`, `BeakPanelConfig`, `BeakResource`, `BeakAuthConfig` | [Panel and resource options](panel-options.md) |
| `BeakBackendConfig`, `BeakServeHost`, `DATABASE_URL`, `BEAK_STORAGE_DRIVER` | [Configuration and environment](configuration.md) |
| `BeakException`, `BeakConfigurationException`, `BeakResult` | [Exceptions](exceptions.md) |
| `/api/commits`, `/api/{table}/query`, `/healthz` | [REST API](rest-api.md) |
| `*.beak.dart`, `*.g.dart`, `XModel`, `XColumns`, `XRecord` | [Generated files and symbols](generated-files.md) |
| `package:beak/panel.dart`, `package:beak/server.dart` | [Libraries](libraries.md) |
| `beak_core`, `beak_serverpod`, `worm` | [Packages](packages.md) |

## Rules for this section

- Signatures are quoted from the source with the file named beside them, so what you read is what compiles.
- Defaults come from the source. A page that shows a default was checked against it.
- A limit or a rough edge is stated under `Rules and limits`, with its reason.
- Text an AI agent needs verbatim (names, paths, commands, flags) is in tables and code, not in prose.

## Continue reading

- [Cheatsheet](cheatsheet.md) the shortest path from a task to its declaration.
- [Guides](../guides/index.md) the same APIs with reasons and worked examples.
- [Quickstart](../start-here/quickstart.md) for running something first.
