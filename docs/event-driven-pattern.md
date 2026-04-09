# Event-Driven Pattern — StreamEvents and SendControl

Hardys Connector Framework v1.2 uses a fully event-driven architecture. There are **no callback servers** — no `HardysCoreCallbackService`, no second gRPC port to deploy or register.

## Two channels, one direction each

| Direction | Mechanism | Examples |
|---|---|---|
| Core → Connector | gRPC method calls on `BaseConnectorService` or `ConnectorService` | `Register`, `Connect`, `Disconnect`, `SendChat`, `SendControl` |
| Connector → Core | Typed events emitted on `StreamEvents` | All platform events, lifecycle control events |

## StreamEvents carries two categories of events

### Platform events (field numbers 1–20)
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
| `SpeakerMutedEvent` | A speaker was muted |
| `SpeakerUnmutedEvent` | A speaker was unmuted |
| `ParticipantJoinedEvent` | New participant joined — includes `SpeakerRole` |
| `ParticipantLeftEvent` | Participant left |
| `ParticipantRaisedHandEvent` | Participant raised hand (signal for Hardys intervention) |
| `ParticipantMutedEvent` | Participant was muted |
| `ScreenShareStartedEvent` | Screen share active |
| `ScreenShareStoppedEvent` | Screen share stopped |
| `PollStartedEvent` | Instructor launched a poll |
| `PollClosedEvent` | Poll closed |
| `BreakoutRoomStartedEvent` | Students entered breakout rooms |
| `BreakoutRoomClosedEvent` | Breakout rooms closed |
| `ChatMessageReceivedEvent` | Chat message received (complement to StreamChat) |

### Lifecycle control events (field numbers 21–23)
Events that signal connector state to Core. These replace the old `HardysCoreCallbackService`.

| Event | When emitted | Core response |
|---|---|---|
| `LectureStartedCallbackEvent` | Connector has joined the lecture and is ready to stream | Core opens audio/video/chat streams |
| `LectureClosedCallbackEvent` | Connector is about to close all streams | Core closes pipeline |
| `LectureErrorEvent` | An error has occurred (typed `LectureError`) | Core calls `SendControl(abort)` if non-recoverable |

## Lifecycle sequence

```
Core       → Connect(LectureRef, LectureConfig, InstructorInfo)
               ↳ connector joins the lecture
               ↳ connector emits LectureStartedCallbackEvent on StreamEvents

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
               ↳ connector emits LectureClosedCallbackEvent on StreamEvents
               ↳ connector closes all streams
```

## SendControl — Core → Connector commands

`SendControl` is the only Core→Connector command channel outside of lifecycle calls.

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
3. Connector stops streams, emits `LectureClosedCallbackEvent`, exits

## Adding new event types

New event types are added by:
1. Defining a new message (e.g. `MyNewEvent { ... }`)
2. Adding a new field to `LectureEvent.oneof` (next available field number)
3. Bumping the minor version of the package

This is backward-compatible — existing connectors that do not emit the new event continue to work.
