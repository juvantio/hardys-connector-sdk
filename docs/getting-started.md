# Getting Started — Building a Hardys Connector

## What you need to implement

Every lecture connector implements **one service**:

**`ConnectorService`** (`protos/lecture/connector.proto`) — all lifecycle, streaming, and control methods.

There is no `BaseConnectorService`. All methods are in `ConnectorService`.

## Key architectural rules

**Zero env vars for config.** Configuration does NOT come from environment variables. Everything arrives in `ConnectRequest` — instance config (from Cosmos DB) + lecture runtime info. The container starts clean and waits for `Connect()`.

**Container never exits by itself.** After `Disconnect()`, the connector closes the session and waits. It does NOT call `sys.exit()`. Core stops the ACA Container App via Azure API.

**No locale in connectors.** Locale is a Core concern. Connectors pass raw data and never generate user-facing text in a specific language.

**MediaFrame is the universal frame type.** Both `StreamAudio` and `StreamAudioVideo` return `stream MediaFrame`. The `MediaFrameType` field declares the content. There is no separate `AudioFrame` or `VideoFrame`.

**Config validation is mandatory.** Validate all `required=true` fields at the start of `Connect()` before any platform operation. Return error immediately if any field is missing.

**No STT in connectors.** If the platform provides native transcripts, normalize them into `TranscriptChunk`. Never perform speech-to-text — that violates the raw-data principle.

## connector-manifest.json

Every connector image must include a `connector-manifest.json` file and publish it as an OCI annotation:

```dockerfile
COPY connector-manifest.json /app/connector-manifest.json
LABEL org.hardys.connector.manifest-path=/app/connector-manifest.json
```

Core reads the manifest with `docker inspect` — without starting the container — to build the admin UI dynamically.

See `connector-manifest-schema.json` for the full schema and `connector-manifest-example.json` for a complete example.

## Quickstart

### 1. Clone the proto file

```bash
git clone https://github.com/juvantio/hardys-connector-sdk.git
```

You need: `protos/lecture/connector.proto`

### 2. Generate gRPC stubs

**Python:**
```bash
python -m grpc_tools.protoc \
  -I protos/lecture \
  --python_out=. --grpc_python_out=. \
  protos/lecture/connector.proto
```

**Node.js:**
```bash
npm install @grpc/grpc-js @grpc/proto-loader
# Load proto dynamically — no codegen step required
```

### 3. Implement ConnectorService

Mandatory methods:
- `HealthCheck` — return healthy status, version, connector_id
- `Connect` — validate required fields FIRST, emit `LectureStartEvent`, join platform
- `Disconnect` — emit `LectureCloseEvent` FIRST, leave platform, wait (do NOT exit)
- `StreamAudio` or `StreamAudioVideo` — yield `MediaFrame` continuously
- `StreamChat` — yield `ChatMessage` as they arrive
- `StreamEvents` — yield `LectureEvent` (platform + lifecycle events)
- `SendChat` — post message to platform chat
- `SendControl` — handle abort/pause/resume
- `TestStream` — yield synthetic `MediaFrame` (always implement — Core uses for validation)

Optional methods:
- `GetLectureConfigSchema` — return runtime_fields schema dynamically
- `StreamTranscript` — only if `native_transcript` capability declared in manifest

### 4. Emit lifecycle events correctly

```python
async def Connect(self, request, context):
    # STEP 1: validate required fields
    ok, err = validate_required_fields(request)
    if not ok:
        return ConnectResponse(connected=False, error=err)

    # STEP 2: emit LectureStartEvent — FIRST instruction after validation
    await emit_event(LectureEvent(
        lecture_start=LectureStartEvent(
            session_id=request.session_id,
            lecture_id=request.lecture_id,
            lecture_name=request.lecture_name
        ),
        timestamp=now_ms()
    ))

    # STEP 3: join platform
    # ... platform-specific join logic ...

    return ConnectResponse(connected=True)

async def Disconnect(self, request, context):
    # STEP 1: emit LectureCloseEvent — FIRST instruction
    await emit_event(LectureEvent(
        lecture_close=LectureCloseEvent(
            session_id=request.session_id,
            reason="disconnect_requested"
        ),
        timestamp=now_ms()
    ))

    # STEP 2: leave platform
    # ... platform-specific leave logic ...

    # STEP 3: wait — do NOT exit. Core stops the container via ACA API.
    return DisconnectResponse()
```

### 5. Populate MediaFrame correctly

```python
# Determine is_instructor by matching speaker against ConnectRequest fields
def is_instructor(speaker_name, request):
    return (
        speaker_name == request.instructor_full_name or
        (request.instructor_id and speaker_id == request.instructor_id)
    )

# StreamAudio — audio only
frame = MediaFrame(
    data=pcm_bytes,            # PCM 16-bit 16kHz mono
    timestamp=now_ms(),
    type=MediaFrameType.MEDIA_FRAME_AUDIO,
    speaker_role=SpeakerRole.SPEAKER_ROLE_PRESENTER,
    is_instructor=is_instructor(speaker_name, request),
    source=AudioSource.AUDIO_SOURCE_MIX
)

# StreamAudioVideo — audio+video multiplexed by connector
frame = MediaFrame(
    data=multiplexed_bytes,    # connector assembles — Core never recombines
    timestamp=now_ms(),
    type=MediaFrameType.MEDIA_FRAME_AUDIO_VIDEO,
    speaker_role=SpeakerRole.SPEAKER_ROLE_PRESENTER,
    is_instructor=True,
    source=AudioSource.AUDIO_SOURCE_SPEAKER
)
```

### 6. Mandatory CLI entry points

```bash
python connector.py health
python connector.py run --mock --duration 60
```

## Repository structure

```
hardys-connector-{class}-{platform}/
  connector.py             ← CLI entry point + gRPC server
  servicer.py              ← ConnectorService implementation
  mock_data.py             ← synthetic data generators
  config.py                ← config model (reads ConnectRequest)
  requirements.txt
  protos/
    connector.proto        ← copy from hardys-connector-sdk
  connector-manifest.json  ← OCI annotation source
  Dockerfile               ← includes LABEL for manifest
  docker-compose.yml
  CLAUDE.md
  docs/
    auth-flow.md
    session-flow.md
```

## Testing your connector

```bash
# Health check — no server needed
python connector.py health

# Mock mode — no real lecture needed
python connector.py run --mock --duration 60
```
