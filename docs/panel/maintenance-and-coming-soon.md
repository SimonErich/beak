---
title: Maintenance and coming soon
description: Use dedicated presentation states while controlling service access separately.
type: guide
audience: [beginner]
status: draft
---

# Maintenance and coming soon

The frontend includes maintenance and coming-soon presentation widgets for host applications. They can occupy a custom screen or replace the panel at the application entrypoint.

A presentation screen does not stop API traffic. Coordinate actual maintenance with the service layer and expose only the operations that should remain available. Keep status messages and retry behavior in the host application's configuration.

## Continue reading

- [Custom screens](custom-screens.md)
- [Production deployment](../shipping/going-to-production.md)
