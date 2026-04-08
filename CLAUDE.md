# CLAUDE.md — hardys-connector-sdk

This file provides context for AI coding assistants working in this repository.

## What this repo is

The **normative home for all Hardys connector `.proto` files** across all
connector classes. This is the multi-class SDK.

It does NOT contain reference implementations — those live in class-specific
SDK repos (`hardys-connector-sdk-lecture`, etc.).

## Repo structure

```
protos/
  lecture/connector.proto    <- lecture class — ConnectorService + ManagementService
  content/                   <- future
  identity/                  <- future
  assessment/                <- future
docs/
  getting-started.md
  connector-classes.md
  governance.md
```

## Architecture decisions in effect

| ADR | Title | What it means here |
|-----|-------|--------------------|
| [ADR-005](https://github.com/juvantio/hardys-pm/blob/main/docs/decisions/ADR-005-grpc-connector-protocol.md) | gRPC as connector protocol | All connector contracts are defined as .proto files here |
| [ADR-006](https://github.com/juvantio/hardys-pm/blob/main/docs/decisions/ADR-006-connector-class-taxonomy.md) | Connector class taxonomy | One subdirectory per class under protos/ |
| [ADR-008](https://github.com/juvantio/hardys-pm/blob/main/docs/decisions/ADR-008-connector-configuration-model.md) | Configuration model | Three-level config; GetConfigSchema() in every connector |

## Proto versioning rules

- Field numbers are PERMANENT — never reuse or change a field number
- Adding new fields is always backward compatible
- Removing or renaming fields is a breaking change — requires a major version bump
- New messages and services can be added freely
- Breaking changes require updating the package name (e.g. v2) and a migration guide

## Governance

To propose a contract change: open a PR with the proto change, describe motivation
and backward compatibility impact, tag with the relevant class label.

To propose a new connector class: see `docs/governance.md`.

## Key proto contracts (lecture class)

The `lecture/connector.proto` defines:
- `ConnectorService` — mandatory for all lecture connectors
- `ConnectorManagementService` — optional session discovery
- `GetConfigSchema()` — connector returns JSON Schema for its instance config
- `SessionRef.session_token` — canonical platform token (guest token, meeting ID)
- `SessionRef.join_url` — full URL when available
- `RegisterRequest` — connector identifies itself; Core sends config in `RegisterResponse`
