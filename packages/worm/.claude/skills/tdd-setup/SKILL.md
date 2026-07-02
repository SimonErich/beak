---
name: tdd-setup
description: Use when TDD is explicitly requested. Generates tests and stubs based on a provided implementation plan or feature spec. Must be executed strictly after planning, but before writing the actual application code.
argument-hint: [implementation-plan]
context: fork
model: haiku
user-invocable: false
---

# TDD Setup

<critical_rules>

1. NEVER implement actual working code. All feature implementations MUST strictly consist of `throw UnimplementedError();`.
2. You must actually EXECUTE the tests using your Bash tool to prove they fail. Do not assume or hallucinate the test results.
3. Preserve TDD purity: your only goal is setting up the RED state.
</critical_rules>

## Operating Procedure

### Step 1: Analyze Requirements

Review the provided implementation plan - use the Read tool if it is a file path:
$0

Determine:

- Required classes/interfaces and their file locations.
- Required methods, signatures, and expected behavior.
- Dependencies or collaborators.

### Step 2: Create Implementation Stubs

For each required API element:

- Use your tools to create the file in the appropriate directory.
- Implement the classes/methods with the correct signatures.
- The body of EVERY method must solely be `throw UnimplementedError();`.

### Step 3: Write Corresponding Tests

For each implementation stub:

- Create the test file in the `test/` directory.
- Write tests that verify the expected behavior using the arrange-act-assert pattern.
- Use appropriate mocking/faking for dependencies.

### Step 4: Execute and Verify (RED State)

- Use your Bash tool to run the tests you just created (e.g., `flutter test <path_to_test_file>`).
- Verify the terminal output confirms the tests are failing due to the `UnimplementedError`.
- If a test fails to compile or fails for a syntax reason, fix it until it fails specifically for being unimplemented.

### Step 5: Report Deliverables

When finished, output your results in the exact format below:

```md
## Files Needing Implementation
- lib/feature1/class1.dart
- lib/feature1/class2.dart

## Test Files Needing to Pass
- test/feature1/class1_test.dart
- test/feature1/class2_test.dart

VERIFIED all test files are failing. Ready for TDD.
```
