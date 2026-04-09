# CLAUDE.md — hardys-connector-sdk

Context for Claude Code working in this repository.

## What this repo is

Normative gRPC proto definitions for the Hardys Connector Framework (HCF). This is the single source of truth — all connectors copy these protos, never modify them locally.

**Reference documents:** HCF v1.2 + LMS Architecture v0.6 (Apr 2026, in project knowledge).

## Proto files

| File | Package | Purpose |
|---|---|---|
| `protos/base/base.proto` | `hardys.connector.base.v1` | BaseConnectorService — mandatory all classes |
| `protos/lecture/connector.proto` | `hardys.connector.lecture.v2` | Lecture class contract |

## Key architecture decisions (do not change without explicit instruction)

1. **Fully event-driven — no callback servers.** Lifecycle signals (lecture start, close, error) travel as typed events on `StreamEvents` (fields 21–23 in the `LectureEvent` oneof). There is no `HardysCoreCallbackService`.

2. **Two mandatory services + one optional.** `BaseConnectorService` (all classes) + `ConnectorService` (lecture-specific) + optional `ConnectorManagementService`. Do not merge them.

3. **`StreamAudio` vs `StreamAudioVideo`.** These are two distinct methods — not one. `StreamAudio` returns `stream AudioFrame` (PCM only). `StreamAudioVideo` returns `stream MediaFrame` (audio+video synchronized). Both can coexist — connector declares which it supports via capabilities.

4. **`InstructorInfo` in `ConnectRequest`.** Core tells the connector who the instructor is. The connector matches against the platform roster and populates `AudioFrame.is_instructor`. The connector does NOT determine independently who the instructor is.

5. **`SpeakerRole` enum.** `SPEAKER_ROLE_PRESENTER` = has session control. `SPEAKER_ROLE_PARTICIPANT` = student or guest. The connector populates this from the platform roster — it is platform metadata, not inference.

6. **`LectureError` is typed.** Use `LectureErrorType` enum + `LectureErrorSeverity` + typed `LectureErrorContext` oneof. Never use stringly-typed error details.

7. **`ConnectorManagementService` is optional.** Set `management_supported=false` in `HealthCheck` if not implementing. Renaming: all session→lecture (`ListLectures`, `GetLecture`, `ActivateLecture`).

8. **Package version is `lecture.v2`.** `v1` is the old contract (single file, `SessionRef`, `StreamVideo`, no `LectureError`). Any connector claiming PCAF compliance must use `v2`.

## Adding new event types

To add a new event to `StreamEvents`:
1. Define the message (e.g. `MyNewEvent { ... }`)
2. Add a field to `LectureEvent.oneof` using the next available field number
3. Update `docs/governance.md` changelog
4. This is backward-compatible — minor version bump only

## Naming conventions

- connector_id: `{class}.{platform}` — e.g. `lecture.collaborate_guest`
- Proto packages: `hardys.connector.{class}.{version}` — e.g. `hardys.connector.lecture.v2`
- Repo names: `juvantio/hardys-connector-{class}-{platform}` — e.g. `juvantio/hardys-connector-lecture-collaborate-guest`
