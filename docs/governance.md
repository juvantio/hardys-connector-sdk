# Governance

## Versioning

```
package hardys.connector.lecture.v2;
package hardys.connector.content.v1;
```

- **Backward-compatible additions** (new optional fields, new methods, new `LectureEvent` types) -> minor version bump
- **Breaking changes** (removed fields, changed semantics) -> major version bump, new package name
- `BaseConnectorService` (`base.v1`) is versioned separately and changes infrequently

### Current versions

| Package | Version | Status |
|---|---|---|
| `hardys.connector.base` | v1 | Stable |
| `hardys.connector.lecture` | v2 | Active — see CHANGELOG |

## Proposing a new connector class

1. Open an issue titled `Proposal: new connector class — {class_name}`
2. Describe: what it integrates, what data flows, why existing class cannot be extended
3. Juvant reviews and approves or redirects
4. Upon approval: define protos, create class spec document, update `docs/connector-classes.md`

## Third-party connector certification

To be listed in the Hardys Connector Registry, a connector must:

- Implement all mandatory methods of `BaseConnectorService`
- Implement all mandatory methods of the class-specific `ConnectorService`
- Emit `LectureStartEvent` as the **first instruction** inside `Connect()`
- Emit `LectureCloseEvent` as the **first instruction** inside `Disconnect()`
- Emit `LectureErrorEvent` on `StreamEvents` when errors occur
- Never perform AI inference, transcription, or translation — raw data only
- Pass the SDK test harness in both real and mock mode
- Expose all mandatory CLI entry points
- Provide `auth-flow.md` and `session-flow.md` documentation
- Pass a security review of credential handling

## CHANGELOG

### lecture.v2 — Apr 2026 (final cleanup)
- `locale` removed from `ConnectorConfig` — locale is a Core concern
- `ConnectorConfig` moved from `base.proto` to `lecture/connector.proto`
- `base.proto` is now a pure service contract with no platform/class-specific fields
- `AudioFrame` and `VideoFrame` eliminated — `MediaFrame` is the universal frame type
- `MediaFrameType` enum added: `MEDIA_FRAME_AUDIO` / `MEDIA_FRAME_AUDIO_VIDEO`
- Both `StreamAudio` and `StreamAudioVideo` return `stream MediaFrame`
- Connector assembles audio+video internally — Core never recombines separate frames
- `StreamTranscript` added — optional, for native-transcript platforms (Teams, Zoom)
- `TranscriptChunk` added — no `spoken_language` (platform already handled detection)
- `SpeakerMutedEvent` and `SpeakerUnmutedEvent` removed — redundant with `ParticipantMutedEvent`
- `ParticipantUnmutedEvent` added — was missing
- `LectureStartedCallbackEvent` -> `LectureStartEvent` (first instruction in `Connect()`)
- `LectureClosedCallbackEvent` -> `LectureCloseEvent` (first instruction in `Disconnect()`)
- `SendControl` added (`AbortCommand`, `PauseCommand`, `ResumeCommand`)
- `session` -> `lecture` rename throughout
- `InstructorInfo` struct in `ConnectRequest` (replaces `instructor_name` string)
- `SpeakerRole` enum + `speaker_name` + `is_instructor` in `MediaFrame`
- `SpeakerChangedEvent` extended with `speaker_role` + `is_instructor`
- `ConnectorManagementService` renamed: `ListSessions`->`ListLectures`, etc.
- `LectureError` full taxonomy: 25 types, 4 severity levels, typed context oneof
- `HardysCoreCallbackService` removed — no callback servers

### lecture.v1 — Mar 2026
- Initial release
