# CLAUDE.md — hardys-connector-sdk

Context for Claude Code working in this repository.

## What this repo is

Normative gRPC proto definitions for the Hardys Connector Framework (HCF). This is the single source of truth — all connectors copy these protos, never modify them locally.

**Reference documents:** HCF v1.2 + LMS Architecture v0.6 (Apr 2026, in project knowledge).

## Proto files

| File | Package | Purpose |
|---|---|---|
| `protos/base/base.proto` | `hardys.connector.base.v1` | BaseConnectorService — mandatory all classes. Pure service contract, no platform fields. |
| `protos/lecture/connector.proto` | `hardys.connector.lecture.v2` | Lecture class contract — ConnectorConfig, MediaFrame, TranscriptChunk, LectureEvent, ConnectorService, ConnectorManagementService |

## Key architecture decisions (do not change without explicit instruction)

1. **Fully event-driven — no callback servers.** `LectureStartEvent` (first instruction in `Connect()`) and `LectureCloseEvent` (first instruction in `Disconnect()`) travel as typed events on `StreamEvents`. There is no `HardysCoreCallbackService`.

2. **MediaFrame is the universal frame type.** `AudioFrame` and `VideoFrame` do not exist. Both `StreamAudio` and `StreamAudioVideo` return `stream MediaFrame`. `MediaFrameType` enum declares the content: `MEDIA_FRAME_AUDIO` (PCM only) or `MEDIA_FRAME_AUDIO_VIDEO` (multiplexed). When the platform provides audio and video separately, the connector assembles them — Core never recombines separate frames.

3. **No locale in ConnectorConfig.** Locale is a Core concern. Connectors never generate user-facing text. Removed from the contract permanently.

4. **ConnectorConfig lives in lecture/connector.proto, not base.proto.** base.proto is a pure service contract. ConnectorConfig fields are class-specific.

5. **StreamTranscript is optional.** Only connectors declaring `"native_transcript"` implement it. The connector normalizes the platform transcript format into `TranscriptChunk`. No STT happens in the connector — that violates raw-data principle. No `spoken_language` in `TranscriptChunk` — the platform already handled language detection.

6. **InstructorInfo in ConnectRequest.** Core tells the connector who the instructor is. The connector matches against the platform roster to populate `MediaFrame.is_instructor` and `SpeakerChangedEvent.is_instructor`.

7. **LectureError is typed.** Use `LectureErrorType` enum + `LectureErrorSeverity` + typed `LectureErrorContext` oneof. Never stringly-typed errors.

8. **ConnectorManagementService is optional.** Set `management_supported=false` in HealthCheck if not implementing.

9. **Package version is `lecture.v2`.** v1 is the old contract. Any connector claiming PCAF compliance must use v2.

## Naming conventions

- connector_id: `{class}.{platform}` — e.g. `lecture.collaborate_guest`
- Proto packages: `hardys.connector.{class}.{version}`
- Repo names: `juvantio/hardys-connector-{class}-{platform}`
