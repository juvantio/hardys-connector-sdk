# Governance

## Versioning

Each class contract is versioned independently using semantic versioning on the proto package:

```
package hardys.connector.lecture.v2;
package hardys.connector.content.v1;
```

- **Backward-compatible additions** (new optional fields, new methods, new `LectureEvent` types in the `oneof`) → minor version bump
- **Breaking changes** (removed fields, changed semantics, renamed messages) → major version bump, new package name
- `BaseConnectorService` (`base.v1`) is versioned separately and changes infrequently

### Current versions

| Package | Version | Status |
|---|---|---|
| `hardys.connector.base` | v1 | Stable |
| `hardys.connector.lecture` | v2 | Active — see CHANGELOG |

## Proposing a new connector class

A new connector class is needed when you are integrating a **new category** of external system, not a new platform within an existing class.

1. Open an issue in `juvantio/hardys-connector-sdk` titled `Proposal: new connector class — {class_name}`
2. Describe: what external system category this class integrates, what data flows are required, why an existing class cannot be extended
3. Juvant reviews and either approves or proposes an extension of an existing class
4. Upon approval: define `base.proto` and `connector.proto` for the new class, create the class specification document, update `docs/connector-classes.md`

## Third-party connector certification

Third-party developers are free to build connectors implementing any class contract. To be listed in the official Hardys Connector Registry, a connector must:

- Implement all mandatory methods of `BaseConnectorService`
- Implement all mandatory methods of the class-specific `ConnectorService`
- Emit `LectureStartEvent` as the first instruction inside `Connect()`
- Emit `LectureCloseEvent` as the first instruction inside `Disconnect()`
- Emit `LectureErrorEvent` on `StreamEvents` when errors occur
- Pass the SDK test harness in both real and mock mode
- Expose all mandatory CLI entry points (`health`, `run`, `run --mock`)
- Provide `auth-flow.md` and `session-flow.md` documentation
- Pass a security review of credential handling

Certification is managed by Juvant. Uncertified connectors can be used but are not listed in the official registry.

## CHANGELOG

### lecture.v2 (Apr 2026)
- **BREAKING:** `hardys.connector.lecture.v1` → `hardys.connector.lecture.v2`
- `StreamVideo` removed → `StreamAudio` (audio-only) + `StreamAudioVideo` (`MediaFrame`, audio+video)
- `SessionEvents` → `StreamEvents` with full typed `LectureEvent` oneof (22 event types)
- `SpeakerMutedEvent` and `SpeakerUnmutedEvent` removed — redundant with `ParticipantMutedEvent`
- `ParticipantUnmutedEvent` added — was missing, obvious counterpart to `ParticipantMutedEvent`
- Three lifecycle control events on StreamEvents:
  - `LectureStartEvent` — emitted as **first instruction inside `Connect()`**; Core allocates resources
  - `LectureCloseEvent` — emitted as **first instruction inside `Disconnect()`**; Core deallocates resources
  - `LectureErrorEvent` — typed error event; Core may respond with `SendControl(abort)`
- `SendControl` added (`AbortCommand`, `PauseCommand`, `ResumeCommand`)
- `session` → `lecture` rename throughout (`SessionRef`→`LectureRef`, `SessionConfig`→`LectureConfig`, etc.)
- `InstructorInfo` struct in `ConnectRequest` (replaces `instructor_name` string)
- `SpeakerRole` enum + `speaker_name` + `is_instructor` in `AudioFrame`
- `SpeakerChangedEvent` extended with `speaker_role` + `is_instructor`
- `ParticipantJoinedEvent` extended with `role` (`SpeakerRole`)
- `ConnectorManagementService` renamed: `ListSessions`→`ListLectures`, `GetSession`→`GetLecture`, `ActivateSession`→`ActivateLecture`
- `ActivateLectureRequest` includes `InstructorInfo`
- `LectureError` full taxonomy: 25 error types, 4 severity levels, typed `LectureErrorContext` oneof
- `ConnectorCapabilities` extended: `native_diarization`, `native_transcript`
- `HardysCoreCallbackService` removed — no callback servers
- `BaseConnectorService` extracted to `protos/base/base.proto` with `ConfigSchemaField` replacing JSON Schema string

### lecture.v1 (Mar 2026)
- Initial release
