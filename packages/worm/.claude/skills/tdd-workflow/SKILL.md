---
name: tdd-workflow
description: Use immediately when TDD (tdd) is explicitly requested.
user-invocable: true
---

# TDD Workflow

1. Use Explore subagent to get related project context
2. Formalize user prompt and enrich with gathered context
3. Hand this prompt over to subagent tdd-planning-agent
4. Use skill tdd-setup, use "## PUBLIC API" section from plan as argument.
5. Start implementation until tests pass.
