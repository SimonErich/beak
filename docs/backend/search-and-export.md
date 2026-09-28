---
title: Search and export
description: Use typed search sources and export authorized records with a shared display policy.
---

# Search and export

Search and export use the same model, query and authorization contracts as tables.
A resource declares `globalSearchSources` with generated scalar or relationship
references. Models can also mark default columns searchable with `@Column`.

The canonical shop searches product names and SKUs, category names, variant
attributes, customer addresses, invoice lines and voucher snapshots. Collection
search uses `Model.children.search(ChildModel.field)` and to-one paths use generated
chained fields. These are query definitions, not manually fetched child lists.

## Search semantics

Text search uses case-insensitive matching. Numeric and boolean fields parse a
compatible search term and use typed equality; an incompatible term does not
attempt a text operator against an integer column. Relationship predicates are
translated into scoped related queries, including to-many paths.

Global search groups matches by resource. Ordinary list queries can combine search
with permanent filters, user filters, sorting and pagination. Backend policies
remain authoritative: unavailable resources are excluded or denied as appropriate,
row scopes narrow records and related records, and hidden fields cannot be
searched to infer their contents.

The shop's API tests exercise real SQLite collection search through
`variants.attributes.value`, product specifications and invoice item/voucher paths.
They also test enum, boolean, date and numeric filters.

## CSV export

Export accepts a typed query specification and streams authorized records. It
applies the same scope, filter, sort and field visibility as the requesting user.
Pagination is handled by the service rather than materializing every row in the
browser. Password values are redacted.

A formatted export accepts a `BeakFormatPolicy` describing locale, currency,
number/date patterns, empty values and timezone behavior. Standard panel export
uses its configured formatting so a downloaded amount matches what the user saw.
Exact decimal and money formatting does not convert scaled integer values through
a floating-point intermediate.

Machine/raw export deliberately preserves physical wire/storage representations.
Choose it for downstream processing rather than a human spreadsheet. Calendar
dates, wall-clock times, durations, lists and structured objects retain the shared
semantic codec's representation. CSV quoting handles delimiters, quotes and line
breaks independently of formatting.

Malformed format options produce a validation response rather than silently
changing locale or interpreting an arbitrary timezone. UTC, local time and explicit
fixed offsets have distinct behavior; choose one consistently for an export.

See the framework's `csv_export_service_test.dart` for formatting, raw values,
password redaction, pagination and error examples. The canonical shop uses one
EUR/de_AT display policy across forms, tables, summaries and exports.

## Continue reading

- [Typed queries](../architecture/query-contract.md).
- [Authorization](auth-and-policies.md).
