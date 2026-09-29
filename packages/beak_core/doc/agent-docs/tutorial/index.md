# Tutorial

> Learn the declarative resource model through the maintained shop example.

First Flight builds a panel by describing its data, behavior and presentation. It follows [the runnable shop](https://github.com/SimonErich/beak/tree/v0.9.0/examples/clean_beak_config); every example uses that application's models.

Start with the minimal generated app if you have no project yet. Then inspect the shop one resource at a time. The API runs on port 8080 and the panel on port 3000.

## Which page to read

| You want to… | Read | For |
| --- | --- | --- |
| Define a shared schema and register its presentation in a panel | [Your first resource](01-your-first-resource.md) | Tutorial chapter for beginners |
| Use typed fields, semantic metadata and shared model constraints | [Columns and validation](02-columns-and-validation.md) | Tutorial chapter for beginners |
| Configure related editors while Beak manages their draft graph | [Related records](03-relationships.md) | Tutorial chapter for beginners |
| Run the maintained shop against its generated server and SQLite database | [Seeding and the API](04-seeding-and-the-api.md) | Tutorial chapter for beginners |
| Arrange resources, forms and custom content without rebuilding data plumbing | [Shaping the panel](05-shaping-the-panel.md) | Tutorial chapter for beginners |
| Verify the declarative contracts and configure authority before deployment | [Auth, tests, and shipping](06-auth-tests-and-shipping.md) | Tutorial chapter for beginners |

The maintained examples are `examples/quickstart`, the CLI scaffold, and `examples/clean_beak_config`, the complete application. Both use the same model and resource contracts.

## Continue reading

- [Your first resource](01-your-first-resource.md): Define a shared schema and register its presentation in a panel.
- [Columns and validation](02-columns-and-validation.md): Use typed fields, semantic metadata and shared model constraints.
- [Related records](03-relationships.md): Configure related editors while Beak manages their draft graph.
