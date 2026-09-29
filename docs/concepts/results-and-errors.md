---
title: Results and errors
description: Keep typed failures, field feedback and uncertain writes distinct.
type: concept
audience: [expert]
status: draft
---

# Results and errors

Backend adapters throw typed `BeakException` values. Frontend repository boundaries convert transport failures into `BeakResult` values for presentation. Validation errors carry field paths; authorization, missing records and concurrency conflicts remain distinguishable.

A graph save returns operation outcomes and a stable receipt. Applied, unapplied and unknown are different states. An unknown outcome requires recovery with the same save identity before replaying. Forms and batch views preserve the draft while showing a correctable error; custom widgets should expose an error and retry state instead of displaying an invented zero.

## Continue reading

- [Drafts and review](../forms/drafts-and-review.md)
- [Exception reference](../reference/exceptions.md)
