---
name: qa-checks 
description: The QA scripts and commands available to this project.
---

# QA Checks (sorted by blast radius)

## Static Analysis

Static analysis of file:
$ flutter analyze my_file.dart

Static analysis of codebase:
$ flutter analyze

## Testing

Specific unit tests & Flutter widget tests:
$ flutter test path/my_test.dart

Full Flutter test suite:
$ flutter test

Integration test using patrol:
$ patrol test -t integration_test/example_test.dart

Integration test using patrol with screenshot:
$ patrol-screenshot integration_test/example_test.dart

Serverpod tests:
$ todo
