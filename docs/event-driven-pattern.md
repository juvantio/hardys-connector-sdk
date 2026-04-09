# Event-Driven Pattern — StreamEvents and SendControl

Hardys Connector Framework v1.2 uses a fully event-driven architecture. There are **no callback servers** — no `HardysCoreCallbackService`, no second gRPC port to deploy or register.

## Two channels, one direction each

| Direction | Mechanism | Examples |
|---|---|---|
| Core → Connector | gRPC method calls on `BaseConnectorService` or `ConnectorService` | `Register`, `Connect`, `Disconnect`, `SendChat`, `SendControl` |
| Connector → Core | Typed events emitted on `StreamEvents` | All platform events, lifecycle control events |

## StreamEvents carries two categories of events

### Platform events (field numbers 1–19)
Events that reflect what is happening in the lecture:

| Event | When emitted |
|---|---|
| `LectureStartedEvent` | The lecture has started on the platform |
| `LectureClosedEvent` | The lecture has ended on the platform |
| `LecturePausedEvent` | The instructor has paused the session |
| `LectureResumedEvent` | The session has resumed |
| `LectureRecordingStartedEvent` | Recording started (compliance/consent relevance) |
| `LectureRecordingStoppedEvent` | Recording stopped |
| `SpeakerChangedEvent` | Active speaker changed — includes `speaker_role` and `is_instructor` |
| `ParticipantJoinedEvent` | New participant joined — includes `SpeakerRole` |
| `ParticipantLeftEvent` | Participant left |
| `ParticipantRaisedHandEvent` | Participant raised hand (signal for Hardys intervention) |
| `ParticipantMutedEvent` | A participant was muted |
| `ParticipantUnmutedEvent` | A participant was unmuted |
| `ScreenShareStartedEvent` | Screen share active |
| `ScreenShareStoppedEvent` | Screen share stopped |
| `PollStartedEvent` | Instructor launched a poll |
| `PollClosedEvent` | Poll closed |
| `BreakoutRoomStartedEvent` | Students entered breakout rooms |
| `BreakoutRoomClosedEvent` | Breakout rooms closed |
| `ChatMessageReceivedEvent` | Chat message received (complement to StreamChat) |

### Lifecycle control events (field numbers 20–22)
Events that signal connector lifecycle state to Core. No callback servers needed.

| Event | When emitted | Semantics |
|---|---|---|
| `LectureStartEvent` | **First instruction inside `Connect()`** | Core allocates resources and prepares the ingestion pipeline before the connector completes the platform join |
| `LectureCloseEvent` | **First instruction inside `Disconnect()`** | Core deallocates resources and closes the ingestion pipeline before the connector leaves the platform |
| `LectureErrorEvent` | When an error occurs during the lecture | Core may respond with `SendControl(abort)` if non-recoverable |

**Key naming distinction:**
- `LectureStartEvent` / `LectureCloseEvent` = connector lifecycle signals (emitted inside `Connect()`/`Disconnect()`)
- `LectureStartedEvent` / `LectureClosedEvent` (platform events, fields 1–2) = platform state events (lecture starting/ending on the platform)

## Lifecycle sequence

```
Core       → Connect(LectureRef, LectureConfig, InstructorInfo)
               ↳ connector emits LectureStartEvent     ← FIRST instruction
               ↳ connector joins the lecture on the platform
               ↳ connector matches instructor via InstructorInfo
               ↳ returns ConnectResponse + LectureDetails

               StreamAudio / StreamAudioVideo  ↘
               StreamChat                       ├  in parallel
               StreamEvents                    ↗  (platform + lifecycle events)
               SendChat                         ←  on demand
               SendControl                      ←  Core responds to errors

// On error:
               Connector emits LectureErrorEvent on StreamEvents
               Core evaluates LectureError.severity and .retryable
               If non-recoverable: Core calls SendControl(abort)

Core       → Disconnect()
               ↳ connector emits LectureCloseEvent     ← FIRST instruction
               ↳ connector leaves the platform
               ↳ closes all streams
```

## SendControl — Core → Connector commands

`SendControl` is the Core→Connector command channel, used primarily to respond to `LectureErrorEvent`.

```proto
message ControlMessage {
  oneof command {
    AbortCommand  abort  = 1;  // non-recoverable — stop immediately
    PauseCommand  pause  = 2;  // temporary pause
    ResumeCommand resume = 3;  // resume after pause
  }
}
```

**Typical abort flow:**
1. Connector emits `LectureErrorEvent` with `severity=FATAL` and `retryable=false`
2. Core calls `SendControl(abort)`
3. Connector emits `LectureCloseEvent`, stops streams, exits

## Adding new event types

New event types are added by:
1. Defining a new message (e.g. `MyNewEvent { ... }`)
2. Adding a new field to `LectureEvent.oneof` (next available field number)
3. Updating `docs/governance.md` changelog
4. This is backward-compatible — minor version bump only
