# Event-Driven Pattern — StreamEvents and SendControl

Hardys Connector Framework v1.2 uses a fully event-driven architecture. There are **no callback servers** — no second gRPC port to deploy or register.

## Two channels, one direction each

| Direction | Mechanism | Examples |
|---|---|---|
| Core -> Connector | gRPC method calls on `BaseConnectorService` or `ConnectorService` | `Register`, `Connect`, `Disconnect`, `SendChat`, `SendControl` |
| Connector -> Core | Typed events emitted on `StreamEvents` | All platform events, lifecycle control events |

## StreamEvents carries two categories of events

### Platform events (field numbers 1–19)

| Event | When emitted |
|---|---|
| `LectureStartedEvent` | The lecture has started on the platform |
| `LectureClosedEvent` | The lecture has ended on the platform |
| `LecturePausedEvent` | The instructor has paused the session |
| `LectureResumedEvent` | The session has resumed |
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
| `PollStartedEvent` | Instructor launched a poll |
| `PollClosedEvent` | Poll closed |
| `BreakoutRoomStartedEvent` | Students entered breakout rooms |
| `BreakoutRoomClosedEvent` | Breakout rooms closed |
| `ChatMessageReceivedEvent` | Chat message received |

### Lifecycle control events (field numbers 20–22)

| Event | When emitted | Semantics |
|---|---|---|
| `LectureStartEvent` | **First instruction inside `Connect()`** | Core allocates resources before connector completes platform join |
| `LectureCloseEvent` | **First instruction inside `Disconnect()`** | Core deallocates resources before connector leaves platform |
| `LectureErrorEvent` | When an error occurs | Core may respond with `SendControl(abort)` if non-recoverable |

**Key naming distinction:**
- `LectureStartEvent` / `LectureCloseEvent` = **connector lifecycle signals**
- `LectureStartedEvent` / `LectureClosedEvent` = **platform state events**

## Lifecycle sequence

```
Core    -> Connect(LectureRef, LectureConfig, InstructorInfo)
             -> connector emits LectureStartEvent     <- FIRST instruction
             -> connector joins lecture on platform
             -> returns ConnectResponse + LectureDetails

             StreamAudio / StreamAudioVideo  \
             StreamChat                       |- in parallel
             StreamTranscript (if supported)  |
             StreamEvents                    /
             SendChat                        <- on demand
             SendControl                     <- Core responds to errors

Core    -> Disconnect()
             -> connector emits LectureCloseEvent     <- FIRST instruction
             -> connector leaves platform
             -> closes all streams
```

## SendControl

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
3. Connector emits `LectureCloseEvent`, stops all streams, exits
