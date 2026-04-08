# Connector Classes

A connector class defines a category of integration — not a specific platform,
but a type of relationship between Hardys and the outside world.

## Current classes

| Class | What it integrates | Proto | SDK repo | Status |
|-------|--------------------|-------|----------|--------|
| `lecture` | Live teaching sessions | `protos/lecture/connector.proto` | `hardys-connector-sdk-lecture` | Specified v0.5 |
| `content` | Content repositories | future | future | Not yet defined |
| `identity` | Identity systems | future | future | Not yet defined |
| `assessment` | Assessment platforms | future | future | Not yet defined |

## Lecture class — data flows

```
Platform --audio--> ConnectorService --AudioFrame--> Hardys Core
Platform --video--> ConnectorService --VideoFrame--> Hardys Core
Platform --chat-->  ConnectorService --ChatMessage-> Hardys Core
Core     --msg-->   ConnectorService --SendChat----> Platform
```

- `StreamAudio`: raw PCM 16-bit 16kHz mono — no transcription in connector
- `StreamVideo`: raw frames — no analysis in connector
- `StreamChat`: plain text — connector strips HTML
- `GetConfigSchema()`: connector declares instance config as JSON Schema
- `ConnectorManagementService`: optional session discovery

## Faculty App UX by management_supported

| management_supported | Faculty App shows |
|----------------------|------------------|
| `true` | Session list from platform — tap to activate |
| `false` | Text field — paste guest link or session token |

## Adding a new class — see `docs/governance.md`
