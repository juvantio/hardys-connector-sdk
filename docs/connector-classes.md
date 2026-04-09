# Connector Classes

A connector class defines a category of integration — not a specific platform, but a type of relationship between Hardys and the outside world.

## Current classes

| Class | What it integrates | Primary data flows | Status |
|---|---|---|---|
| `lecture` | Live lecture platforms | MediaFrame IN, Chat IN/OUT, Transcript IN, Events IN/OUT | Specified — v2 |
| `content` | Content repositories (LMS materials, Panopto, Drive) | Documents IN, Recordings IN, Metadata IN | Not yet defined |
| `identity` | Identity and profile systems | Profile data IN, Role data IN | Not yet defined |
| `assessment` | Assessment platforms | Results IN, Triggers OUT | Not yet defined |

## connector_id naming convention

```
{class}.{platform}

lecture.collaborate_api
lecture.teams
lecture.google_meet
lecture.zoom
content.panopto
identity.linkedin
```

## One service per connector

Every connector implements a single `ConnectorService` — defined in `protos/{class}/connector.proto`. There is no `BaseConnectorService`.

| Service | Mandatory | Direction | Proto |
|---|---|---|---|
| `ConnectorService` (class-specific) | Yes | Core → Connector | `protos/{class}/connector.proto` |

## Proposing a new class

Open an issue titled `Proposal: new connector class — {class_name}`. See `docs/governance.md`.
