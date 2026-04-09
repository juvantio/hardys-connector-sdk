# hardys-connector-sdk

Normative gRPC contract definitions for all Hardys connector classes.

## Repository structure

```
protos/
  base/
    base.proto               <- BaseConnectorService — mandatory ALL classes (v1)
  lecture/
    connector.proto          <- Lecture class ConnectorService (v2)
content/                     <- future
identity/                    <- future
assessment/                  <- future
docs/
  getting-started.md
  connector-classes.md
  event-driven-pattern.md    <- StreamEvents + SendControl pattern
  management-service.md      <- ConnectorManagementService pattern
  governance.md              <- Versioning, changelog, certification
README.md
CLAUDE.md
```

## Quick start

1. Read `docs/getting-started.md`
2. Copy `protos/base/base.proto` and `protos/lecture/connector.proto`
3. Generate stubs for your language
4. Implement `BaseConnectorService` + `ConnectorService` (lecture)
5. Emit lifecycle events on `StreamEvents` — see `docs/event-driven-pattern.md`

## Architecture

### Fully event-driven — no callback servers

- **Core -> Connector:** method calls (`Register`, `Connect`, `SendControl`, etc.)
- **Connector -> Core:** typed events on `StreamEvents`

### MediaFrame — universal media frame

Both `StreamAudio` and `StreamAudioVideo` return `stream MediaFrame`. The `MediaFrameType` field declares the content:
- `MEDIA_FRAME_AUDIO` — PCM 16-bit 16kHz mono
- `MEDIA_FRAME_AUDIO_VIDEO` — audio+video multiplexed by the connector

There is no separate `AudioFrame` or `VideoFrame`.

### No locale in connectors

Locale is a Core concern. Connectors pass raw data and never generate user-facing text.

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
