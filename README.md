# hardys-connector-sdk

Normative gRPC contract definitions for all Hardys connector classes.

This repository is the single source of truth for the Hardys Connector Framework (HCF). All OOTB connectors and third-party connectors implement the contracts defined here.

## Repository structure

```
protos/
  base/
    base.proto               ← BaseConnectorService — mandatory for ALL classes (v1)
  lecture/
    connector.proto          ← Lecture class ConnectorService (v2)
content/                     ← future
identity/                    ← future
assessment/                  ← future
docs/
  getting-started.md         ← Build your first connector
  connector-classes.md       ← Class taxonomy and naming
  event-driven-pattern.md    ← StreamEvents lifecycle events + SendControl
  management-service.md      ← ConnectorManagementService pattern
  governance.md              ← Versioning, changelog, certification
README.md
CLAUDE.md
```

## Quick start

1. Read `docs/getting-started.md`
2. Copy `protos/base/base.proto` and `protos/lecture/connector.proto` into your connector repo
3. Generate stubs for your language
4. Implement `BaseConnectorService` + `ConnectorService` (lecture)
5. Emit lifecycle events on `StreamEvents` — see `docs/event-driven-pattern.md`

## Architecture

### Fully event-driven — no callback servers

All connector→Core signals travel as typed events on `StreamEvents`. No second gRPC server to deploy.

- **Core → Connector:** method calls (`Register`, `Connect`, `SendControl`, etc.)
- **Connector → Core:** typed events on `StreamEvents` (platform events + lifecycle control events)

### Three gRPC services per connector

| Service | Mandatory | Proto |
|---|---|---|
| `BaseConnectorService` | Yes — all classes | `protos/base/base.proto` |
| `ConnectorService` (lecture) | Yes — lecture class | `protos/lecture/connector.proto` |
| `ConnectorManagementService` | No — optional | `protos/lecture/connector.proto` |

## Official connectors

| Connector | connector_id | management_supported | Milestone |
|---|---|---|---|
| Collaborate — Guest | `lecture.collaborate_guest` | false | Pilot |
| Collaborate — API | `lecture.collaborate_api` | true | MVP |
| Microsoft Teams | `lecture.teams` | true | MVP |
| Google Meet | `lecture.google_meet` | true | Production |
| Zoom | `lecture.zoom` | true | Production |

## Package versions

| Package | Version | File |
|---|---|---|
| `hardys.connector.base` | v1 | `protos/base/base.proto` |
| `hardys.connector.lecture` | v2 | `protos/lecture/connector.proto` |

See `docs/governance.md` for the full changelog.

## Related repositories

- `juvantio/hardys-connector-lecture-collaborate-guest` — Pilot connector (in progress)
- `juvantio/hardys-connector-sdk-lecture` — Reference implementation
- `juvantio/hardys-pm` — Project management
