# Claude Code Prompt — Build `hardys-connector-sdk-lecture-example`

## Context

You are working in the repository `juvantio/hardys-connector-sdk-lecture-example`.

This repository is the **reference implementation** of a Hardys lecture connector. It implements the full `ConnectorService` contract defined in `juvantio/hardys-connector-sdk` using **mock/synthetic data only** — no real lecture platform is involved. Its purpose is to:

1. Demonstrate correct implementation of every method in the contract
2. Serve as a starting template for developers building real connectors
3. Validate that the SDK contract and documentation are sufficient to build from

Before writing any code, read the following files from `juvantio/hardys-connector-sdk` (clone or fetch them):

- `protos/lecture/connector.proto` — the normative gRPC contract (source of truth)
- `connector-manifest-example.json` — the manifest format
- `connector-manifest-schema.json` — the manifest JSON schema
- `CLAUDE.md` — architectural decisions (do not violate any of these)
- `docs/getting-started.md` — implementation guide
- `docs/event-driven-pattern.md` — lifecycle event pattern
- `docs/governance.md` — versioning and certification rules

---

## Repository to create: `hardys-connector-sdk-lecture-example`

### connector_id
`lecture.example`

### capabilities
`["audio", "chat_read", "chat_write", "native_transcript"]`

---

## What to implement

### 1. `protos/connector.proto`
Copy `protos/lecture/connector.proto` verbatim from `juvantio/hardys-connector-sdk`. Do not modify it.

### 2. `connector-manifest.json`
Create the manifest for `lecture.example` following `connector-manifest-example.json` from the SDK. Set:
- `connector_id`: `lecture.example`
- `version`: `1.0.0`
- `capabilities`: `["audio", "chat_read", "chat_write", "native_transcript"]`
- Keep all four field categories: `readonly_fields`, `instance_fields`, `runtime_fields`, `debug_fields`

### 3. `Dockerfile`
Standard Python 3.12 slim image. Must:
- `COPY connector-manifest.json /app/connector-manifest.json`
- `LABEL org.hardys.connector.manifest-path=/app/connector-manifest.json`
- Expose port `50051`
- Entrypoint: `python connector.py serve`

### 4. `requirements.txt`
```
grpcio>=1.62.0
grpcio-tools>=1.62.0
pytest>=8.0.0
pytest-asyncio>=0.23.0
```

### 5. `generate_proto.sh`
Script to generate Python stubs from `protos/connector.proto`:
```bash
python -m grpc_tools.protoc \
  -I protos \
  --python_out=. \
  --grpc_python_out=. \
  protos/connector.proto
```

### 6. `config.py`
Typed config object built from a `ConnectRequest`. Must expose:
- `session_id`
- `instance_url`, `credentials`, `params`, `inactivity_timeout_seconds`, `debug_enabled`
- `lecture_id`, `lecture_name`, `join_url`
- `instructor_id`, `instructor_full_name`, `instructor_email`
- `audio_enabled`, `video_enabled`, `chat_read_enabled`, `chat_write_enabled`

Helper method: `LectureConfig.from_connect_request(request) -> LectureConfig`

Also provide: `validate_required_fields(request) -> tuple[bool, str | None]`

Required fields to validate (from manifest):
- Instance: `instance_url`
- Runtime: `lecture_id`, `join_url`, `instructor_full_name`

### 7. `mock_data.py`
Pure functions — no I/O, no gRPC dependency. Implement:

```python
def generate_pcm_frame(t_start: float, frequency: float = 440.0) -> bytes
    # 20ms PCM 16-bit 16kHz mono sine wave

def synthetic_media_frame(session_id: str, t: float, frame_type: str = "AUDIO") -> MediaFrame
    # Returns MediaFrame with type MEDIA_FRAME_AUDIO or MEDIA_FRAME_AUDIO_VIDEO

def synthetic_chat_message(session_id: str) -> ChatMessage
    # Returns a random ChatMessage from a pool of realistic lecture questions

def synthetic_transcript_chunk(session_id: str, t: float) -> TranscriptChunk
    # Returns a TranscriptChunk with is_final alternating every 3 chunks

def synthetic_lecture_event(session_id: str, event_type: str) -> LectureEvent
    # Returns a LectureEvent for the given type string
    # Must cover all 22 event types

def synthetic_lectures(date_str: str) -> list[dict]
    # Returns 3 synthetic lecture dicts: one active, two future

def wav_header(num_samples: int) -> bytes
    # RIFF/WAV header for 16-bit mono 16kHz audio
```

Participant pool for mock data (at least 5 names):
```
user_001 — Alice Romano
user_002 — Marco Bianchi
user_003 — Sofia Esposito
user_004 — Luca Ferrari
user_005 — Giulia Marino
```

### 8. `servicer.py`
Full implementation of `ConnectorService`. All methods use mock data. Every method has a detailed docstring explaining what a real implementation must replace.

#### `HealthCheck`
Return:
```python
HealthCheckResponse(
    healthy=True,
    version="1.0.0",
    connector_id="lecture.example",
    connector_class="lecture",
    diagnostics={"mock_mode": "true"}
)
```

#### `GetLectureConfigSchema`
Return the `runtime_fields` from `connector-manifest.json` as `repeated ConfigField`.

#### `Connect`
**CRITICAL — follow this exact order:**
1. Call `validate_required_fields(request)` — if invalid, return `ConnectResponse(connected=False, error="Missing required field: {name}")`
2. Store config: `self._sessions[request.session_id] = LectureConfig.from_connect_request(request)`
3. Emit `LectureStartEvent` on `StreamEvents` queue — FIRST instruction after validation
4. Return `ConnectResponse(connected=True)`

#### `Disconnect`
**CRITICAL — follow this exact order:**
1. Emit `LectureCloseEvent` on `StreamEvents` queue — FIRST instruction
2. Remove session: `self._sessions.pop(request.session_id, None)`
3. **Do NOT call `sys.exit()` or `os._exit()`** — container lifecycle is managed by Core
4. Return `DisconnectResponse()`

#### `StreamAudio`
- Yield `MediaFrame` with `type=MEDIA_FRAME_AUDIO` every 20ms
- Alternate speakers every 30 seconds using `speaker_id_for_time()`
- Populate `is_instructor` by matching `speaker_name` against `instructor_full_name` from session config
- Stop when session is removed from `self._sessions`

#### `StreamAudioVideo`
- Yield `MediaFrame` with `type=MEDIA_FRAME_AUDIO_VIDEO` every 20ms
- Same speaker logic as `StreamAudio`
- `data` contains the same PCM frame (mock — no real video)

#### `StreamChat`
- Yield one `ChatMessage` every 8–15 seconds (random interval)
- Use `synthetic_chat_message()`
- Stop when session removed

#### `StreamEvents`
- On `Connect()`: yield `LectureStartEvent` immediately
- On `Disconnect()`: yield `LectureCloseEvent` immediately
- Between lifecycle events: yield platform events at realistic intervals:
  - `LectureStartedEvent` shortly after connect
  - `SpeakerChangedEvent` every ~30 seconds
  - `ParticipantJoinedEvent` / `ParticipantLeftEvent` occasionally
  - `LectureRecordingStartedEvent` after ~60 seconds
- Use an `asyncio.Queue` to decouple lifecycle events from the stream loop

#### `StreamTranscript`
- Yield `TranscriptChunk` every ~5 seconds
- Alternate `is_final=False` (partial) and `is_final=True` (final) chunks
- Match `is_instructor` from session config

#### `SendChat`
- Log the message
- Return `ChatOutResponse(success=True)`
- Docstring must explain: real implementation calls platform chat API; handle HTML formatting per platform

#### `SendControl`
- Handle `abort`: log, mark session for teardown
- Handle `pause`: log, set pause flag
- Handle `resume`: log, clear pause flag
- Return `ControlResponse(acknowledged=True)`

#### `TestStream`
- Yield `MediaFrame` with `type=MEDIA_FRAME_AUDIO` for `request.duration_seconds`
- Works without a prior `Connect()` call — session_id can be a generated UUID
- Used by Core to validate the connector without a real lecture

### 9. `connector.py`
CLI entry point. Implement three subcommands:

#### `serve`
```bash
python connector.py serve [--port 50051]
```
- Start gRPC server with `ConnectorService`
- Handle `SIGTERM` and `SIGINT` for graceful shutdown (5-second grace period)
- Log startup with connector_id, version, port

#### `health`
```bash
python connector.py health
```
- Print JSON health report to stdout (no server needed)
- Exit 0 on healthy, exit 1 on error

#### `run`
```bash
python connector.py run --mock --duration <seconds> --output <audio.wav|chat|all>
```
- `--output audio.wav`: write mock audio to WAV file
- `--output chat`: print chat messages as JSON lines to stdout
- `--output all`: both simultaneously
- Does not require a running server

### 10. `docker-compose.yml`
```yaml
services:
  connector:
    build: .
    ports:
      - "50051:50051"
    volumes:
      - ./connector-manifest.json:/app/connector-manifest.json:ro
```

---

## Tests

### `tests/test_config.py` — Unit tests for config validation

Test cases:
- `test_validate_all_required_present` — all required fields present → `(True, None)`
- `test_validate_missing_instance_url` → `(False, "Missing required field: instance_url")`
- `test_validate_missing_lecture_id` → `(False, "Missing required field: lecture_id")`
- `test_validate_missing_join_url` → `(False, "Missing required field: join_url")`
- `test_validate_missing_instructor_full_name` → `(False, "Missing required field: instructor_full_name")`
- `test_from_connect_request_maps_all_fields` — all fields mapped correctly
- `test_from_connect_request_defaults` — missing optional bool fields default correctly

### `tests/test_mock_data.py` — Unit tests for mock data generators

Test cases:
- `test_pcm_frame_length` — frame is exactly 640 bytes (320 samples × 2 bytes)
- `test_pcm_frame_is_bytes` — returns bytes
- `test_synthetic_media_frame_audio_type` — `type == MEDIA_FRAME_AUDIO`
- `test_synthetic_media_frame_audio_video_type` — `type == MEDIA_FRAME_AUDIO_VIDEO`
- `test_synthetic_chat_message_has_text` — `text` is non-empty
- `test_synthetic_transcript_chunk_has_text` — `text` is non-empty
- `test_synthetic_lectures_count` — returns exactly 3 lectures
- `test_synthetic_lectures_one_active` — exactly one lecture has `is_active=True`
- `test_wav_header_length` — WAV header is exactly 44 bytes
- `test_all_22_event_types_covered` — `synthetic_lecture_event()` covers all 22 event type strings

### `tests/test_servicer.py` — Unit tests for ConnectorService methods

Test cases:
- `test_health_check_returns_healthy` — `healthy=True`, `connector_id="lecture.example"`
- `test_connect_validates_required_fields` — missing `instance_url` → `connected=False`
- `test_connect_valid_request_returns_connected` — valid request → `connected=True`
- `test_connect_stores_session` — after Connect, session is in `self._sessions`
- `test_disconnect_removes_session` — after Disconnect, session removed
- `test_disconnect_does_not_exit` — `sys.exit` is never called (mock `sys.exit`, assert not called)
- `test_send_chat_returns_success` — `success=True`
- `test_send_control_abort_acknowledged` — `acknowledged=True`
- `test_send_control_pause_acknowledged` — `acknowledged=True`
- `test_send_control_resume_acknowledged` — `acknowledged=True`
- `test_get_lecture_config_schema_returns_runtime_fields` — returns non-empty list of `ConfigField`

### `tests/test_manifest.py` — Consistency tests between manifest and contract

These tests validate that `connector-manifest.json` is consistent with the proto contract and SDK schema. They are the most important tests in the repo.

Test cases:
- `test_manifest_is_valid_json` — parses without error
- `test_manifest_version_present` — `manifest_version` field exists
- `test_connector_id_format` — matches pattern `^[a-z]+\.[a-z_]+$`
- `test_connector_class_is_lecture` — `connector_class == "lecture"`
- `test_capabilities_are_known_strings` — all declared capabilities are in the known set: `["audio", "audio_video", "chat_read", "chat_write", "native_diarization", "native_transcript"]`
- `test_all_four_schema_categories_present` — `readonly_fields`, `instance_fields`, `runtime_fields`, `debug_fields` all present
- `test_required_runtime_fields_present` — `lecture_id`, `join_url`, `instructor_full_name` are declared in `runtime_fields` with `required=True`
- `test_instance_url_required` — `instance_url` is in `instance_fields` with `required=True`
- `test_field_types_are_valid` — every field in every category has `type` in `["string", "url", "secret", "integer", "boolean"]`
- `test_readonly_fields_have_value` — every `readonly_field` has a non-empty `value`
- `test_debug_enabled_field_present` — `debug_enabled` is in `debug_fields`
- `test_native_transcript_capability_matches_implementation` — if `native_transcript` in capabilities, `StreamTranscript` must be implemented in `servicer.py` (check via `hasattr` or method inspection)
- `test_get_lecture_config_schema_matches_manifest_runtime_fields` — the field names returned by `GetLectureConfigSchema()` match the names declared in `runtime_fields` in the manifest

---

## GitHub Actions workflows

### `.github/workflows/ci.yml` — Run tests on every push and PR

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Generate gRPC stubs
        run: bash generate_proto.sh
      - name: Run tests
        run: pytest tests/ -v
```

### `.github/workflows/docker-publish.yml`
Copy from `juvantio/hardys-connector-sdk/scripts/docker-publish.yml` verbatim. No changes needed.

---

## `CLAUDE.md`
Create a `CLAUDE.md` at the repo root explaining:
- What this repo is (reference implementation, not a real connector)
- Where the normative contract lives (`juvantio/hardys-connector-sdk`)
- The 14 architectural decisions from `juvantio/hardys-connector-sdk/CLAUDE.md` — copy them verbatim, as they all apply
- Additional rule: **this repo uses mock data only** — no platform SDK, no real network calls
- How to run tests: `pytest tests/ -v`
- How to regenerate stubs: `bash generate_proto.sh`
- How to run locally: `python connector.py serve` or `docker-compose up`

---

## `README.md`
Include:
- What this repo is and its relationship to `juvantio/hardys-connector-sdk`
- Prerequisites: Python 3.12+, Docker, grpcurl (optional)
- Quick start: clone → `pip install -r requirements.txt` → `bash generate_proto.sh` → `python connector.py health`
- CLI reference (serve, health, run)
- How to run tests: `pytest tests/ -v`
- How to build and run with Docker
- Section: "Implementing a real connector" — files to modify, files NOT to modify, what each mock method must be replaced with
- Link to `juvantio/hardys-connector-sdk` for the normative contract and governance

---

## Final checklist before committing

- [ ] `protos/connector.proto` is an exact copy — no modifications
- [ ] `connector-manifest.json` validates against `connector-manifest-schema.json`
- [ ] `Connect()` validates required fields BEFORE emitting `LectureStartEvent`
- [ ] `Disconnect()` emits `LectureCloseEvent` as FIRST instruction
- [ ] No `sys.exit()` anywhere in servicer code
- [ ] `StreamAudio` and `StreamAudioVideo` both return `MediaFrame` (never `AudioFrame`)
- [ ] `TestStream` works without a prior `Connect()` call
- [ ] All 22 `LectureEvent` types are covered in `synthetic_lecture_event()`
- [ ] All tests pass: `pytest tests/ -v`
- [ ] `test_manifest.py` tests pass — manifest is consistent with contract
- [ ] `python connector.py health` exits 0
- [ ] `python connector.py run --mock --duration 5 --output all` runs without error
- [ ] `docker-compose up` builds and starts without error
- [ ] OCI annotation is present: `docker inspect hardys-connector-sdk-lecture-example_connector --format '{{index .Config.Labels "org.hardys.connector.manifest-path"}}'`
- [ ] `.github/workflows/ci.yml` and `.github/workflows/docker-publish.yml` are present
