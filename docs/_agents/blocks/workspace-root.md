<!-- BEGIN:beak-agent-rules -->
## Admin panel (Beak)

`{{adminDir}}/` is a Beak {{version}} admin panel. Before changing it, read
`{{adminDir}}/AGENTS.md`, and run `beak` commands from that directory.
{{#serverpod}}
Data the admin shows starts in `{{serverPkg}}` (a `.spy.yaml` model, then
`serverpod generate`), followed by its definition class in `{{schemaPkg}}`
and `beak generate`. The rules above about MCP tools, migrations and never
starting the server apply to the admin too.
{{/serverpod}}
<!-- END:beak-agent-rules -->
