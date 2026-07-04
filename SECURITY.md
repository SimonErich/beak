# Security Policy

## Supported Versions

Beak is pre-1.0 and under active development. Security fixes land on `main` and
are released in the next tagged version. Please always test against the latest
`main` before reporting.

## Reporting a Vulnerability

**Please do not open a public issue for security vulnerabilities.**

Report suspected vulnerabilities privately to **security@marqably.com**, or use
GitHub's [private vulnerability reporting][ghsa] on this repository. Include:

- A description of the vulnerability and its impact.
- Steps to reproduce (a minimal proof of concept is ideal).
- The affected package(s) and version/commit.
- Any suggested remediation, if you have one.

We aim to acknowledge reports within **3 business days** and to provide a
remediation timeline after triage. We will keep you informed throughout, and
credit you in the release notes unless you prefer to remain anonymous.

## Scope

Beak generates a Shelf backend and a Flutter admin panel from model
definitions. Areas of particular interest:

- The authorization layer (`BeakPolicy`, `BeakAuthGuard`, session tokens).
- Upload validation and storage-key handling (path traversal, MIME/type
  bypass) in `beak_backend` and the storage drivers.
- The query translation layer (`WormQueryTranslator`) and any injection surface
  reachable through a serialized `BeakQuerySpec`.

The vendored `worm` ORM and its drivers live under `packages/worm*`; report
issues there upstream, but a Beak-specific misuse is in scope here.

[ghsa]: https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability
