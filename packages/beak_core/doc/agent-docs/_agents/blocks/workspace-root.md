<!-- BEGIN:beak-agent-rules -->
## Admin panel (Beak)

`{{adminDir}}/` is a Beak {{version}} admin panel. Before changing it, read
`{{adminDir}}/AGENTS.md`, and run `beak` commands from that directory.
{{#serverpod}}
Data the admin shows starts in `{{serverPkg}}` (a `.spy.yaml` model, then
`serverpod generate`), followed by the matching Beak schema class in
`{{schemaPkg}}`. The rules above about MCP tools, migrations and never
starting the server apply to the admin too.
{{/serverpod}}
<!-- END:beak-agent-rules -->
