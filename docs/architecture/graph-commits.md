---
title: Graph commits
description: See how a graph save is planned, validated, committed transactionally and receipted.
type: concept
audience: [contributor, expert]
status: draft
---

# Graph commits

This page is a draft. It will cover how a graph save works inside: the commit plan, the candidate graph, transactional execution, receipts and the outbox for durable effects.

## Continue reading

- [Architecture](index.md): See how Beak is built inside: the principles, the package graph, the two flows and the seams.
- [The data source seam](data-source-seam.md): See how BeakDataSource lets the panel and the server run the same operations over worm, HTTP and Serverpod.
- [The query contract](query-contract.md): See how the query spec, filters and values serialize losslessly and become a worm query.
