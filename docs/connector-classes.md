# Connector Classes

| Class | What it integrates | Primary data flows | Status |
|---|---|---|---|
| `lecture` | Live lecture platforms (Collaborate, Teams, Meet, Zoom) | MediaFrame IN, Chat IN/OUT, Transcript IN, Events IN/OUT | Specified — v0.6 |
| `content` | Content repositories (LMS materials, Panopto, Drive) | Documents IN, Recordings IN, Metadata IN | Not yet defined |
| `identity` | Identity and profile systems | Profile data IN, Role data IN | Not yet defined |
| `assessment` | Assessment platforms | Results IN, Triggers OUT | Not yet defined |

## connector_id naming convention

```
{class}.{platform}

lecture.collaborate_guest
lecture.collaborate_api
lecture.teams
lecture.google_meet
lecture.zoom
content.panopto
identity.linkedin
```

## Two mandatory services + one optional

| Service | Mandatory | Direction | Proto |
|---|---|---|---|
| `BaseConnectorService` | Yes — all classes | Core -> Connector | `protos/base/base.proto` |
| `ConnectorService` (class-specific) | Yes — class-specific | Core -> Connector | `protos/{class}/connector.proto` |
| `ConnectorManagementService` | No — optional | Core -> Connector | `protos/{class}/connector.proto` |

## Proposing a new class

Open an issue titled `Proposal: new connector class — {class_name}`. See `docs/governance.md`.
