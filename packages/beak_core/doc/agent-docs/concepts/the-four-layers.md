# The four layers

> Understand shared metadata, persistence, presentation and generation.

Beak separates shared metadata, server persistence, frontend presentation and code generation. Core models and typed queries contain no Flutter or database dependencies. Backend adapters enforce policies and transactions. Frontend resources arrange screens around a shared runtime. The CLI emits the metadata and wiring from schemas.

A normal application declares data and behavior in schemas, navigation in resources and layouts in screen files. Domain calculations may use a server graph preparer; specialized widgets can use the panel's source or form draft scope. Those extensions retain the same typed contracts.

## Continue reading

- [Package graph](../architecture/package-graph.md)
- [Declarative resources](declarative-resources.md)
