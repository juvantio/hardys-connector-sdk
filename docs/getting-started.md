# Getting Started — Building a Hardys Connector

## What you need to implement

Every lecture connector implements **two mandatory services** and one optional service:

1. **`BaseConnectorService`** (from `protos/base/base.proto`) — common lifecycle, mandatory for all classes
2. **`ConnectorService`** (from `protos/lecture/connector.proto`) — lecture-specific streaming and control
3. **`ConnectorManagementService`** (optional) — pre-lecture discovery and activation

## Quickstart

### 1. Clone the proto files

```bash
git clone https://github.com/juvantio/hardys-connector-sdk.git
```

You need:
- `protos/base/base.proto` — `BaseConnectorService`
- `protos/lecture/connector.proto` — `ConnectorService` (lecture class v2)

### 2. Generate gRPC stubs

**Python:**
```bash
python -m grpc_tools.protoc \
  -I protos/base -I protos/lecture \
  --python_out=. --grpc_python_out=. \
  protos/base/base.proto protos/lecture/connector.proto
```

**Node.js:**
```bash
npm install @grpc/grpc-js @grpc/proto-loader
# Load protos dynamically — no codegen step required
```

**Go:**
```bash
protoc --go_out=. --go-grpc_out=. \
  -I protos/base -I protos/lecture \
  protos/base/base.proto protos/lecture/connector.proto
```

### 3. Implement the services

Minimum implementation for `BaseConnectorService`:
- `Register` — receive config, declare capabilities
- `Disconnect` — graceful shutdown
- `HealthCheck` — return healthy status, version, capabilities
- `GetConfigSchema` — return fields your connector needs in ConnectorConfig

Minimum implementation for `ConnectorService` (lecture):
- `Connect` — join the lecture; emit `LectureStartedCallbackEvent` on StreamEvents when ready
- `StreamAudio` or `StreamAudioVideo` — stream audio (and optionally video)
- `StreamChat` — stream incoming chat messages
- `StreamEvents` — emit platform events + lifecycle control events
- `SendChat` — send a message to session chat
- `SendControl` — receive abort/pause/resume commands from Core
- `TestStream` — return synthetic audio frames (for testing)

### 4. Emit lifecycle events correctly

All lifecycle signals travel as typed events on `StreamEvents`. No callback servers needed.

```python
# When connector has joined and is ready:
yield LectureEvent(
    lecture_started_cb=LectureStartedCallbackEvent(
        lecture=lecture_ref,
        details=lecture_details
    ),
    timestamp=int(time.time() * 1000)
)

# When an error occurs:
yield LectureEvent(
    lecture_error=LectureErrorEvent(
        error=LectureError(
            error_id=str(uuid.uuid4()),
            type=LectureErrorType.ERROR_PLATFORM_DISCONNECT,
            severity=LectureErrorSeverity.SEVERITY_ERROR,
            retryable=True,
            retry_after_ms=5000,
            timestamp=int(time.time() * 1000)
        )
    ),
    timestamp=int(time.time() * 1000)
)

# Before closing streams:
yield LectureEvent(
    lecture_closed_cb=LectureClosedCallbackEvent(
        lecture=lecture_ref,
        reason="disconnect_requested"
    ),
    timestamp=int(time.time() * 1000)
)
```

### 5. Populate AudioFrame correctly

```python
# Core passes InstructorInfo in ConnectRequest.
# Match against platform roster to populate is_instructor.
audio_frame = AudioFrame(
    data=pcm_bytes,              # PCM 16-bit 16kHz mono
    timestamp=epoch_ms,
    speaker_id=platform_user_id,
    speaker_name=display_name,
    speaker_role=SpeakerRole.SPEAKER_ROLE_PRESENTER,
    is_instructor=(display_name == instructor_info.full_name),
    source=AudioSource.AUDIO_SOURCE_MIX
)
```

### 6. Add mandatory CLI entry points

```bash
python connector.py health --config config.json
python connector.py run --lecture <lecture_id> --output all
python connector.py run --mock --duration 60
```

## Repository structure

```
hardys-connector-{class}-{platform}/
  connector.py           ← CLI entry point + gRPC server
  config.py              ← config model
  requirements.txt
  package.json           ← if Node.js components present
  protos/
    base.proto           ← copy from hardys-connector-sdk
    connector.proto      ← copy from hardys-connector-sdk
  CLAUDE.md              ← context for Claude Code
  Dockerfile
  docker-compose.yml
  config.json            ← local dev only — NOT used in production
```

## Testing your connector

Every connector must work in isolation:

```bash
# Health check
python connector.py health --config config.json

# Mock mode — no real lecture needed
python connector.py run --mock --duration 60

# Real lecture
python connector.py run --lecture <id> --output all
```

See `docs/governance.md` for certification requirements.
