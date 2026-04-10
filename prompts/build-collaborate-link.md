# Claude Code Prompt 1 — Build `hardys-connector-lecture-collaborate-link` (scaffold)

## Context

You are working in the repository `juvantio/hardys-connector-lecture-collaborate-link`.

This is the first step of a two-step process:

1. **Prompt 1 (this prompt):** Scaffold the repository from the SDK — same structure as `juvantio/hardys-connector-lecture-example`, but configured for `lecture.collaborate_link`. All methods use mock/synthetic data. Tests must pass. The repo must compile and run.
2. **Prompt 2 (next session):** Port the real Collaborate business logic from `hardys-connector-lecture-collaborate-guest` into this scaffold.

Do NOT implement any real Collaborate logic in this prompt. Mock data only.

Before writing any code, read the following files from `juvantio/hardys-connector-sdk`:

- `protos/lecture/connector.proto` — normative gRPC contract (source of truth)
- `connector-manifest-example.json` — manifest format
- `connector-manifest-schema.json` — manifest JSON schema
- `CLAUDE.md` — architectural decisions (do not violate any of these)
- `docs/getting-started.md` — implementation guide
- `docs/event-driven-pattern.md` — lifecycle event pattern
- `docs/governance.md` — versioning and certification rules

Also read `juvantio/hardys-connector-lecture-example` as the reference implementation — this scaffold must follow the same structure exactly.

---

## Repository: `hardys-connector-lecture-collaborate-link`

### connector_id
`lecture.collaborate_link`

### capabilities
`["audio", "chat_read", "chat_write"]`

### Description
`Joins a Blackboard Collaborate session using a guest link (join URL). No institutional credentials or API key required. The instructor shares a link; Hardys uses it to join as a named participant.`

---

## What to implement

### 1. `protos/connector.proto`
Copy `protos/lecture/connector.proto` verbatim from `juvantio/hardys-connector-sdk`. Do not modify.

### 2. `connector-manifest.json`
Create the manifest for `lecture.collaborate_link`. Key fields:
- `connector_id`: `lecture.collaborate_link`
- `connector_class`: `lecture`
- `version`: `0.1.0`
- `display_name`: `Blackboard Collaborate — Link`
- `description`: (see above)
- `capabilities`: `["audio", "chat_read", "chat_write"]`
- All four field categories: `readonly_fields`, `instance_fields`, `runtime_fields`, `debug_fields`

`instance_fields`:
```json
[
  {
    "name": "instance_url",
    "type": "url",
    "label": "Collaborate Base URL",
    "description": "Base URL of the Collaborate instance (e.g. https://eu.bbcollab.com)",
    "required": true,
    "editable": true,
    "example": "https://eu.bbcollab.com"
  },
  {
    "name": "inactivity_timeout_seconds",
    "type": "integer",
    "label": "Inactivity Timeout (seconds)",
    "description": "Emit timeout event after N seconds of audio silence",
    "required": false,
    "editable": true,
    "default": 600,
    "min": 60,
    "max": 3600
  }
]
```

`runtime_fields`: same as `connector-manifest-example.json` in the SDK — `lecture_id`, `lecture_name`, `join_url` (required), `instructor_id`, `instructor_full_name` (required), `instructor_email`, `audio_enabled`, `video_enabled`, `chat_read_enabled`, `chat_write_enabled`.

`debug_fields`: `debug_enabled` boolean, default false.

**Important:** Do NOT add `api_key` to `instance_fields` — this connector is link-only, no API credentials.

### 3. `config.py`
Typed config object built from a `ConnectRequest`. Same structure as `hardys-connector-lecture-example/config.py`.

Required fields to validate (from manifest):
- Instance: `instance_url`
- Runtime: `lecture_id`, `join_url`, `instructor_full_name`

### 4. `mock_data.py`
Identical to `hardys-connector-lecture-example/mock_data.py`. Pure functions, no I/O.

### 5. `servicer.py`
Full mock implementation of `ConnectorService`. Identical structure to `hardys-connector-lecture-example/servicer.py`. All methods use synthetic data.

Every method must have a docstring explaining what the real Collaborate implementation will replace it with (Prompt 2).

CRITICAL ordering rules (same as example):
- `Connect()`: validate required fields FIRST → emit `LectureStartEvent` FIRST → return `ConnectResponse(connected=True)`
- `Disconnect()`: emit `LectureCloseEvent` FIRST → clean up → return `DisconnectResponse()`
- No `sys.exit()` anywhere
- `TestStream` works without a prior `Connect()` call

### 6. `connector.py`
CLI entry point. Identical to `hardys-connector-lecture-example/connector.py`.
Subcommands: `serve`, `health`, `run`.

### 7. `generate_proto.sh`
```bash
python -m grpc_tools.protoc \
  -I protos \
  --python_out=. \
  --grpc_python_out=. \
  protos/connector.proto
```

### 8. `requirements.txt`
```
grpcio>=1.62.0
grpcio-tools>=1.62.0
pytest>=8.0.0
pytest-asyncio>=0.23.0
```

### 9. `Dockerfile`
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY protos/ protos/
RUN python -m grpc_tools.protoc \
    -I protos \
    --python_out=. \
    --grpc_python_out=. \
    protos/connector.proto
COPY connector-manifest.json /app/connector-manifest.json
COPY config.py mock_data.py servicer.py connector.py ./
LABEL org.hardys.connector.manifest-path=/app/connector-manifest.json
EXPOSE 50051
ENTRYPOINT ["python", "connector.py", "serve"]
```

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

### 11. `docs/auth-flow.md`
Document the Collaborate guest link authentication flow (stub — Prompt 2 will fill in details):
- Input: `join_url` from `ConnectRequest`
- Extract guest token from URL last path segment
- No API credentials required
- Placeholder for the 5-step HTTP join flow

### 12. `docs/session-flow.md`
Document the session lifecycle (stub — Prompt 2 will fill in details):
- Connect → join Collaborate → capture audio via Chime SDK → chat via jinx WebSocket
- Disconnect → graceful teardown

---

## Tests

Same test structure as `hardys-connector-lecture-example`. Four files:

### `tests/test_config.py`
- `test_validate_all_required_present`
- `test_validate_missing_instance_url`
- `test_validate_missing_lecture_id`
- `test_validate_missing_join_url`
- `test_validate_missing_instructor_full_name`
- `test_from_connect_request_maps_all_fields`
- `test_from_connect_request_defaults`

### `tests/test_mock_data.py`
- `test_pcm_frame_length` — exactly 640 bytes
- `test_pcm_frame_is_bytes`
- `test_synthetic_media_frame_audio_type`
- `test_synthetic_media_frame_audio_video_type`
- `test_synthetic_chat_message_has_text`
- `test_synthetic_transcript_chunk_has_text`
- `test_synthetic_lectures_count` — 3 lectures
- `test_synthetic_lectures_one_active`
- `test_wav_header_length` — 44 bytes
- `test_all_22_event_types_covered`

### `tests/test_servicer.py`
- `test_health_check_returns_healthy` — `connector_id="lecture.collaborate_link"`
- `test_connect_validates_required_fields`
- `test_connect_valid_request_returns_connected`
- `test_connect_stores_session`
- `test_disconnect_removes_session`
- `test_disconnect_does_not_exit`
- `test_send_chat_returns_success`
- `test_send_control_abort_acknowledged`
- `test_send_control_pause_acknowledged`
- `test_send_control_resume_acknowledged`
- `test_get_lecture_config_schema_returns_runtime_fields`

### `tests/test_manifest.py`
- `test_manifest_is_valid_json`
- `test_manifest_version_present`
- `test_connector_id_format` — matches `^[a-z]+\.[a-z_]+$`
- `test_connector_id_is_collaborate_link` — `connector_id == "lecture.collaborate_link"`
- `test_connector_class_is_lecture`
- `test_capabilities_are_known_strings`
- `test_no_api_key_in_instance_fields` — `api_key` must NOT be in instance_fields
- `test_all_four_schema_categories_present`
- `test_required_runtime_fields_present` — `lecture_id`, `join_url`, `instructor_full_name` required
- `test_instance_url_required`
- `test_field_types_are_valid`
- `test_readonly_fields_have_value`
- `test_debug_enabled_field_present`
- `test_get_lecture_config_schema_matches_manifest_runtime_fields`

---

## GitHub Actions

### `.github/workflows/ci.yml`
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
Copy from `juvantio/hardys-connector-sdk/scripts/docker-publish.yml` verbatim.

---

## `CLAUDE.md`

Create a `CLAUDE.md` at the repo root. Include:
- What this repo is (Blackboard Collaborate link connector, real implementation pending in Prompt 2)
- Where the normative contract lives (`juvantio/hardys-connector-sdk`)
- The 14 architectural decisions from `juvantio/hardys-connector-sdk/CLAUDE.md` — copy verbatim
- Additional Collaborate-specific decisions:
  - `connector_id` is `lecture.collaborate_link` — not `collaborate_guest`
  - `join_url` from `ConnectRequest` is the Collaborate guest link — extract token from last URL path segment
  - No API credentials — this connector is link-only
  - Chime bridge internal parameters (`CHIME_AUDIO_PORT`, `CHIME_META_PORT`, `CHIME_VOLUME_THRESHOLD`) are NOT config manifest fields — they are internal implementation constants overridable via env vars
  - `management_supported`: false — no Collaborate API, guest link only
- How to run tests: `pytest tests/ -v`
- How to run locally: `python connector.py serve` or `docker-compose up`
- Note: Prompt 2 will port the real Collaborate business logic

## `README.md`

Include:
- What this connector does (Collaborate link-based join)
- Relationship to `juvantio/hardys-connector-sdk`
- Prerequisites: Python 3.12+, Docker, Node.js 18+ (required for real implementation)
- Quick start (mock mode, no real lecture needed)
- CLI reference
- Tests
- Docker
- Note: real Collaborate implementation is in `collaborate/` folder (added in Prompt 2)

---

## Final checklist before committing

- [ ] `protos/connector.proto` is an exact copy — no modifications
- [ ] `connector-manifest.json` validates against SDK schema
- [ ] `connector_id` is `lecture.collaborate_link` everywhere (manifest, servicer, connector.py, CLAUDE.md, README.md)
- [ ] No `api_key` field anywhere in manifest
- [ ] `Connect()` validates required fields BEFORE emitting `LectureStartEvent`
- [ ] `Disconnect()` emits `LectureCloseEvent` as FIRST instruction
- [ ] No `sys.exit()` anywhere in servicer code
- [ ] `TestStream` works without a prior `Connect()` call
- [ ] All 22 `LectureEvent` types covered in `synthetic_lecture_event()`
- [ ] All tests pass: `pytest tests/ -v`
- [ ] `python connector.py health` exits 0
- [ ] `python connector.py run --mock --duration 5 --output all` runs without error
- [ ] `docker-compose up` builds and starts without error
- [ ] OCI annotation present: `docker inspect hardys-connector-lecture-collaborate-link_connector --format '{{index .Config.Labels "org.hardys.connector.manifest-path"}}'`
- [ ] `.github/workflows/ci.yml` and `docker-publish.yml` present
