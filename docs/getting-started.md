# Getting Started — Building a Hardys Connector

## What you need to implement

Every lecture connector implements **two mandatory services** and one optional:

1. **`BaseConnectorService`** (`protos/base/base.proto`) — common lifecycle, mandatory all classes
2. **`ConnectorService`** (`protos/lecture/connector.proto`) — lecture streaming and control
3. **`ConnectorManagementService`** (optional) — pre-lecture discovery and activation

## Key architectural rules

- **No locale in connectors.** Locale is a Core concern. Connectors never generate user-facing text in a specific language — they pass raw data.
- **MediaFrame is the universal frame type.** Both `StreamAudio` and `StreamAudioVideo` return `stream MediaFrame`. The `type` field (`AUDIO` or `AUDIO_VIDEO`) declares the content of `data`. There is no separate `AudioFrame` or `VideoFrame`.
- **Connectors assemble audio+video.** When the platform provides audio and video as separate streams, the connector multiplexes them into a single `data` blob before yielding the frame. Core never recombines two separate frames.
- **StreamTranscript for native transcripts.** Teams, Zoom and similar platforms provide transcription natively. If the connector can receive these, it normalizes them into `TranscriptChunk` and declares capability `"native_transcript"`. The connector does NOT perform STT — that violates the raw-data principle.

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

### 3. Implement the services

**BaseConnectorService** (mandatory):
- `Register` — receive config, store it, return capabilities
- `Disconnect` — graceful shutdown
- `HealthCheck` — healthy status, version, capabilities
- `GetConfigSchema` — declare your config fields for admin UI

**ConnectorService** (lecture):
- `Connect` — emit `LectureStartEvent` FIRST, then join platform
- `StreamAudio` or `StreamAudioVideo` — yield `MediaFrame` continuously
- `StreamChat` — yield `ChatMessage` as they arrive
- `StreamEvents` — yield `LectureEvent` (platform + lifecycle events)
- `StreamTranscript` — yield `TranscriptChunk` (if `native_transcript` capability)
- `SendChat` — post a message to platform chat
- `SendControl` — handle abort/pause/resume commands from Core
- `TestStream` — yield synthetic `MediaFrame` for testing

### 4. Emit lifecycle events correctly

```python
# FIRST instruction inside Connect():
yield LectureEvent(
    lecture_start=LectureStartEvent(lecture=lecture_ref, details=lecture_details),
    timestamp=int(time.time() * 1000)
)

# FIRST instruction inside Disconnect():
yield LectureEvent(
    lecture_close=LectureCloseEvent(lecture=lecture_ref, reason="disconnect_requested"),
    timestamp=int(time.time() * 1000)
)

# On error:
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
```

### 5. Populate MediaFrame correctly

```python
# StreamAudio — audio only
frame = MediaFrame(
    data=pcm_bytes,                    # PCM 16-bit 16kHz mono
    timestamp=epoch_ms,
    type=MediaFrameType.MEDIA_FRAME_AUDIO,
    speaker_id=platform_user_id,
    speaker_name=display_name,
    speaker_role=SpeakerRole.SPEAKER_ROLE_PRESENTER,
    is_instructor=(display_name == instructor_info.full_name),
    source=AudioSource.AUDIO_SOURCE_MIX
)

# StreamAudioVideo — audio+video multiplexed by connector
frame = MediaFrame(
    data=multiplexed_bytes,            # audio+video assembled by connector
    timestamp=epoch_ms,
    type=MediaFrameType.MEDIA_FRAME_AUDIO_VIDEO,
    speaker_id=platform_user_id,
    speaker_name=display_name,
    speaker_role=SpeakerRole.SPEAKER_ROLE_PRESENTER,
    is_instructor=True,
    source=AudioSource.AUDIO_SOURCE_SPEAKER
)
```

### 6. Mandatory CLI entry points

```bash
python connector.py health --config config.json
python connector.py run --lecture <id> --output all
python connector.py run --mock --duration 60
```

## Repository structure

```
hardys-connector-{class}-{platform}/
  connector.py
  config.py
  requirements.txt
  protos/
    base.proto
    connector.proto
  CLAUDE.md
  Dockerfile
  docker-compose.yml
  config.json   <- local dev only — NOT used in production
```
