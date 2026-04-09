# Event-Driven Pattern — StreamEvents and SendControl

The Hardys Connector Framework uses a fully event-driven architecture. There are **no callback servers** — no second gRPC port to deploy or register.

## Two channels, one direction each

| Direction | Mechanism | Examples |
|---|---|---|
| Core → Connector | gRPC method calls on `ConnectorService` | `Connect`, `Disconnect`, `SendChat`, `SendControl` |
| Connector → Core | Typed events emitted on `StreamEvents` | All platform events, lifecycle control events |

## StreamEvents carries two categories of events

### Platform events (field numbers 1–19)
Reflect what happens in the lecture on the platform side:

| Event | When emitted |
|---|---|
| `LectureStartedEvent` | Lecture has started on the platform |
| `LectureClosedEvent` | Lecture has ended on the platform |
| `LecturePausedEvent` | Session paused |
| `LectureResumedEvent` | Session resumed |
| `LectureRecordingStartedEvent` | Recording started |
| `LectureRecordingStoppedEvent` | Recording stopped |
| `SpeakerChangedEvent` | Active speaker changed — includes `speaker_role` and `is_instructor` |
| `ParticipantJoinedEvent` | New participant joined |
| `ParticipantLeftEvent` | Participant left |
| `ParticipantRaisedHandEvent` | Participant raised hand |
| `ParticipantMutedEvent` | A participant was muted |
| `ParticipantUnmutedEvent` | A participant was unmuted |
| `ScreenShareStartedEvent` | Screen share active |
| `ScreenShareStoppedEvent` | Screen share stopped |
| `PollStartedEvent` | Poll launched |
| `PollClosedEvent` | Poll closed |
| `BreakoutRoomStartedEvent` | Students entered breakout rooms |
| `BreakoutRoomClosedEvent` | Breakout rooms closed |
| `ChatMessageReceivedEvent` | Chat message received |

### Lifecycle control events (field numbers 20–22)
Connector state signals to Core — no callback servers needed.

| Event | When emitted | Semantics |
|---|---|---|
| `LectureStartEvent` | **First instruction inside `Connect()`** | Core allocates resources before connector completes platform join |
| `LectureCloseEvent` | **First instruction inside `Disconnect()`** | Core deallocates resources before connector leaves platform |
| `LectureErrorEvent` | When an error occurs | Core may respond with `SendControl(abort)` if non-recoverable |

**Key naming distinction:**
- `LectureStartEvent` / `LectureCloseEvent` = **connector lifecycle signals** (emitted inside `Connect()`/`Disconnect()`)
- `LectureStartedEvent` / `LectureClosedEvent` = **platform state events** (what happened on the platform)

## Lifecycle sequence

```
Core   → Connect(session_id, instance_config, lecture_runtime)
           → connector validates required fields FIRST
           → connector emits LectureStartEvent        ← FIRST instruction after validation
           → connector joins lecture on platform
           → returns ConnectResponse

           StreamAudio / StreamAudioVideo  \
           StreamChat                       |— in parallel
           StreamTranscript (if supported) |
           StreamEvents                    /
           SendChat                        ← on demand
           SendControl                     ← Core responds to errors

// On error:
           Connector emits LectureErrorEvent
           Core evaluates severity and retryable
           If non-recoverable: Core calls SendControl(abort)

Core   → Disconnect(session_id)
           → connector emits LectureCloseEvent        ← FIRST instruction
           → connector leaves platform
           → closes all streams
           → waits (does NOT exit — Core stops the container via ACA API)
```

## SendControl — Core → Connector commands

```proto
message ControlMessage {
  oneof command {
    AbortCommand  abort  = 1;  // non-recoverable — stop immediately
    PauseCommand  pause  = 2;
    ResumeCommand resume = 3;
  }
}
```

Typical abort flow:
1. Connector emits `LectureErrorEvent` with `severity=FATAL`, `retryable=false`
2. Core calls `SendControl(abort)`
3. Connector emits `LectureCloseEvent`, stops all streams
4. Core stops the ACA Container App via Azure API

## Config validation — non-negotiable rule

Every connector MUST validate all required fields at the start of `Connect()` before any platform operation:

```python
def validate_connect_request(request):
    required_instance = ["instance_url"]  # from your manifest instance_fields
    required_runtime  = ["lecture_id", "join_url", "instructor_full_name"]  # from runtime_fields

    for field in required_instance + required_runtime:
        if not getattr(request, field, None):
            return False, f"Missing required field: {field}"
    return True, None
```

If validation fails: return `ConnectResponse(connected=False, error="Missing required field: {name}")` — do NOT proceed.
