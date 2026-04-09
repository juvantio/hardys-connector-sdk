# Governance

## Versioning

```
package hardys.connector.lecture.v2;
package hardys.connector.content.v1;
```

- **Backward-compatible additions** (new optional fields, new methods, new `LectureEvent` types) → minor version bump
- **Breaking changes** (removed fields, changed semantics) → major version bump, new package name

### Current versions

| Package | Version | Status |
|---|---|---|
| `hardys.connector.lecture` | v2 | Active — see CHANGELOG |

## Proposing a new connector class

1. Open an issue titled `Proposal: new connector class — {class_name}`
2. Describe: what it integrates, what data flows, why existing class cannot be extended
3. Juvant reviews and approves or redirects
4. Upon approval: define connector.proto, create class spec doc, update `docs/connector-classes.md`

## Third-party connector certification

To be listed in the Hardys Connector Registry, a connector must:

- Implement all mandatory methods of `ConnectorService`
- Publish `connector-manifest.json` as OCI annotation on the image
- Emit `LectureStartEvent` as the **first instruction** inside `Connect()` (after validation)
- Emit `LectureCloseEvent` as the **first instruction** inside `Disconnect()`
- Emit `LectureErrorEvent` on `StreamEvents` when errors occur
- Validate all required fields at start of `Connect()` — return error immediately if missing
- Never perform AI inference, transcription, or translation — raw data only
- Never call `sys.exit()` or terminate the process — Core manages container lifecycle
- Pass the SDK test harness in both real and mock mode
- Provide `auth-flow.md` and `session-flow.md` documentation
- Pass a security review of credential handling (no secrets in logs)

## CHANGELOG

### lecture.v2 — Apr 2026 (final architecture)
- **BaseConnectorService removed** — all methods in single `ConnectorService`
- **base.proto removed** — no separate base contract file
- **Register/RegisterResponse removed** — config arrives in `ConnectRequest`
- **ConnectorConfig removed from proto** — lives in `ConnectRequest` instance fields
- **GetConfigSchema removed from proto** — becomes `connector-manifest.json` OCI annotation
- **ConnectorManagementService removed from proto** — implement if needed, return UNIMPLEMENTED otherwise
- **management_supported removed** from `HealthCheckResponse`
- **ConnectorCapabilities removed from proto** — declared in `connector-manifest.json`
- **session_id** added to all requests — disambiguates concurrent sessions
- **ConnectRequest** carries everything: session_id + instance config + lecture runtime
- **GetLectureConfigSchema()** added — optional, dynamic runtime field schema
- **ConfigField** message added
- **ValidationErrorDetail** + `ERROR_MISSING_REQUIRED_FIELD` added
- **Config validation rule**: mandatory at start of `Connect()` before any platform operation
- **Container never exits by itself** — Core stops ACA Container App via Azure API
- **ACA Container App** (not Job) — long-running process per connector type
- **Single/multi session** is Core policy — connector is indifferent
- **locale removed** from config — locale is a Core concern
- `AudioFrame` and `VideoFrame` eliminated — `MediaFrame` with `MediaFrameType` is universal
- `StreamTranscript` + `TranscriptChunk` added — optional, native transcript normalization only
- `SpeakerMutedEvent` / `SpeakerUnmutedEvent` removed — redundant with `ParticipantMutedEvent`
- `ParticipantUnmutedEvent` added — was missing
- `LectureStartedCallbackEvent` → `LectureStartEvent` (first instruction in `Connect()`)
- `LectureClosedCallbackEvent` → `LectureCloseEvent` (first instruction in `Disconnect()`)
- `session` → `lecture` rename throughout
- `InstructorInfo` fields flattened into `ConnectRequest`
- `connector-manifest.json` schema and example published in repo

### lecture.v1 — Mar 2026
- Initial release
