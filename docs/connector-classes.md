# Connector Classes

A connector class defines a category of integration — not a specific platform, but a type of relationship between Hardys and the outside world.

## Current classes

| Class | What it integrates | Primary data flows | Status |
|---|---|---|---|
| `lecture` | Live lecture platforms (Collaborate, Teams, Meet, Zoom) | Audio IN, Video IN, Chat IN/OUT, Events IN/OUT | Specified — v0.6 |
| `content` | Content repositories (LMS materials, Panopto, Drive) | Documents IN, Recordings IN, Metadata IN | Not yet defined |
| `identity` | Identity and profile systems (HR, directory, LinkedIn) | Profile data IN, Role data IN | Not yet defined |
| `assessment` | Assessment platforms (external quiz tools, proctoring) | Results IN, Triggers OUT | Not yet defined |

## connector_id naming convention

```
{class}.{platform}
```

Examples:
```
lecture.collaborate_guest
lecture.collaborate_api
lecture.teams
lecture.google_meet
lecture.zoom
content.panopto
identity.linkedin
```

## Three gRPC services per connector

Every connector implements:

| Service | Mandatory | Direction | Proto file |
|---|---|---|---|
| `BaseConnectorService` | Yes — all classes | Core → Connector | `protos/base/base.proto` |
| `ConnectorService` (class-specific) | Yes — class-specific | Core → Connector | `protos/{class}/connector.proto` |
| `ConnectorManagementService` | No — optional | Core → Connector | `protos/{class}/connector.proto` |

## Proposing a new class

Open an issue in `juvantio/hardys-connector-sdk` titled `Proposal: new connector class — {class_name}`. See `docs/governance.md` for the full process.
