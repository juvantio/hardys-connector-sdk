# Claude Code Prompt 2 — Migrate real Collaborate logic into `hardys-connector-lecture-collaborate-link`

## Context

This is the second step of a two-step process.

**Prompt 1** has already been completed: `juvantio/hardys-connector-lecture-collaborate-link` exists, compiles, all tests pass, with mock/synthetic data.

**This prompt (Prompt 2):** Port the real Blackboard Collaborate business logic from `hardys-connector-lecture-collaborate-guest` into `hardys-connector-lecture-collaborate-link`, adapting it to the v2 gRPC contract.

The source of the business logic is `juvantio/hardys-connector-lecture-collaborate-guest` (local path: `/Users/antonio/Projects/hardys-connector-lecture-collaborate-guest`).

Before writing any code:
1. Read `juvantio/hardys-connector-sdk/CLAUDE.md` — the 14 architectural decisions
2. Read `juvantio/hardys-connector-sdk/protos/lecture/connector.proto` — the v2 contract
3. Read `juvantio/hardys-connector-sdk/docs/event-driven-pattern.md` — lifecycle events
4. Read the current state of this repo (Prompt 1 output) — understand the scaffold
5. Read the source files listed below from `collaborate-guest`

---

## What changed between v1 (collaborate-guest) and v2 (collaborate-link)

The collaborate-guest connector was written against an older contract. Here is the complete diff that matters:

### Config model
| v1 (guest) | v2 (link) |
|---|---|
| Config loaded from `config.json` file | Config arrives entirely in `ConnectRequest` — zero config files |
| `Register()` receives `ConnectorConfig` from Core | No `Register()` — config is in `Connect()` |
| `session.join_url`, `session.session_token` | `request.join_url`, `request.instructor_full_name`, etc. (flat fields) |
| `config.instance_url`, `config.params["guest_token"]` | `request.instance_url`, `request.join_url` |
| `config.inactivity_timeout_seconds` | `request.inactivity_timeout_seconds` |
| `config.chime_audio_port` | `CHIME_AUDIO_PORT` env var (default 8765) |
| `config.chime_meta_port` | `CHIME_META_PORT` env var (default 8766) |
| `config.chime_volume_threshold` | `CHIME_VOLUME_THRESHOLD` env var (default 0.1) |
| `config.node_executable` | `NODE_EXECUTABLE` env var (default "node") |
| `config.locale` | Removed — locale is a Core concern |

### gRPC contract
| v1 (guest) | v2 (link) |
|---|---|
| `Register()` method | Removed — no registration step |
| `ConnectorConfig` proto message | Removed — config in `ConnectRequest` |
| `ConnectRequest.session.join_url` | `ConnectRequest.join_url` (flat) |
| `ConnectRequest.session.session_id` | `ConnectRequest.session_id` (flat) |
| `StreamAudio()` returns `stream AudioFrame` | `StreamAudio()` returns `stream MediaFrame` with `type=MEDIA_FRAME_AUDIO` |
| `StreamVideo()` returns `stream VideoFrame` | `StreamAudioVideo()` returns `stream MediaFrame` with `type=MEDIA_FRAME_AUDIO_VIDEO` |
| `SessionEvents()` returns `stream SessionEndedEvent` | `StreamEvents()` returns `stream LectureEvent` with typed oneof |
| `SessionEndedEvent(reason=...)` | `LectureEvent(lecture_close=LectureCloseEvent(...))` on `StreamEvents` |
| No lifecycle events inside Connect/Disconnect | `LectureStartEvent` = FIRST instruction in `Connect()` after validation |
| No lifecycle events inside Connect/Disconnect | `LectureCloseEvent` = FIRST instruction in `Disconnect()` |
| `ChatOutMessage` parameter in `SendChat` | `SendChatRequest(session_id, text)` |
| `HealthCheckResponse.caps = ConnectorCapabilities(audio=True, ...)` | `HealthCheckResponse.diagnostics` dict — no caps field |
| `management_supported` in HealthCheck | Removed |

### ChimeBridge
| v1 (guest) | v2 (link) |
|---|---|
| Builds `pb2.AudioFrame(...)` internally | Must build `pb2.MediaFrame(type=MEDIA_FRAME_AUDIO, ...)` |
| `audio_queue` contains `AudioFrame` objects | `audio_queue` must contain `MediaFrame` objects |
| `chime_audio_port`, `chime_meta_port`, `chime_volume_threshold` from `config` | Read from env vars: `CHIME_AUDIO_PORT`, `CHIME_META_PORT`, `CHIME_VOLUME_THRESHOLD` |
| `node_executable` from `config` | Read from env var: `NODE_EXECUTABLE` |

---

## Files to migrate from collaborate-guest

### Copy unchanged (no v1/v2 delta — these files are platform-specific and protocol-agnostic)

- `collaborate/jinx.py` — jinx binary WebSocket protocol implementation
- `collaborate/client.py` — Collaborate HTTP join flow (5 steps) + jinx IPC
- `collaborate/chime_receiver.js` — Node.js Chime SDK audio receiver
- `collaborate/__init__.py`
- `docs/auth-flow.md` — Collaborate join flow documentation
- `docs/session-flow.md` — session lifecycle documentation
- `package.json` — Node.js dependencies for chime_receiver.js
- `package-lock.json` — Node.js lockfile

### Migrate with adaptations

#### `collaborate/chime_bridge.py`

This file builds `AudioFrame` objects internally — must be updated to build `MediaFrame` instead.

Specific changes:
1. Change import: no `pb2.AudioFrame` — use `pb2.MediaFrame` and `pb2.MediaFrameType`
2. In `_handle_audio_ws()`, replace:
   ```python
   # v1
   audio_frame = pb2.AudioFrame(
       data=frame_bytes,
       timestamp=ts,
       speaker_id=self._current_speaker_id if is_speaking else "",
       confidence=0.0,
       is_speaking=is_speaking,
       source=pb2.AUDIO_SOURCE_MIX,
   )
   ```
   With:
   ```python
   # v2
   audio_frame = pb2.MediaFrame(
       data=frame_bytes,
       timestamp=ts,
       type=pb2.MediaFrameType.MEDIA_FRAME_AUDIO,
       speaker_id=self._current_speaker_id if is_speaking else "",
       speaker_name="",  # Chime volume indicator does not provide names
       confidence=0.0,
       is_speaking=is_speaking,
       source=pb2.AudioSource.AUDIO_SOURCE_MIX,
       speaker_role=pb2.SpeakerRole.SPEAKER_ROLE_UNKNOWN,
       is_instructor=False,  # servicer overrides this
   )
   ```
3. Replace config parameters with env vars:
   ```python
   # v1: from config object
   def __init__(self, chime_params, *, audio_port, meta_port, node_executable, volume_threshold)
   
   # v2: from env vars with defaults
   import os
   CHIME_AUDIO_PORT      = int(os.environ.get("CHIME_AUDIO_PORT", 8765))
   CHIME_META_PORT       = int(os.environ.get("CHIME_META_PORT", 8766))
   CHIME_VOLUME_THRESHOLD = float(os.environ.get("CHIME_VOLUME_THRESHOLD", 0.1))
   NODE_EXECUTABLE       = os.environ.get("NODE_EXECUTABLE", "node")
   
   def __init__(self, chime_params: dict) -> None:
       # use module-level constants above
   ```
4. `audio_queue` type comment: `asyncio.Queue[pb2.MediaFrame]`

#### `servicer.py`

This is the most complex migration. The business logic stays — the gRPC layer changes.

**Keep unchanged (internal Collaborate logic):**
- `_extract_join_url()` — was `_extract_guest_token()`, but now extracts the full join URL from `request.join_url` directly (no parsing needed — it arrives flat in ConnectRequest)
- `_launch_client()` — launch subprocess, extract token from join_url internally
- `_read_chime_params()` — stdout parsing logic unchanged
- `_route_stdout_line()` — IPC parsing unchanged
- `_run_stdout_reader()` — background task unchanged
- `_run_stderr_logger()` — unchanged
- `_cleanup()` — subprocess teardown unchanged
- `_attendee_ids` dict — persistence logic unchanged

**Rewrite (v1→v2 gRPC layer):**

1. **Remove `Register()`** — not in v2 contract

2. **Rewrite `__init__`:**
   - No `config: ConnectorConfig` parameter — servicer is now stateless at init
   - Keep: `_sessions`, `_proc`, `_bridge`, `_disconnect_event`, `_jinx_queue`, `_raw_event_queue`, `_stdout_reader_task`, `_stderr_logger_task`, `_frames_sent`, `_last_audio_time`, `_is_stub`, `_attendee_ids`
   - Add: `_pause_flags` dict (for SendControl pause/resume)
   - Read Chime constants from env vars (not config)

3. **Rewrite `Connect()`:**
   ```python
   async def Connect(self, request, context):
       # STEP 1: validate required fields
       ok, err = validate_required_fields(request)
       if not ok:
           return ConnectResponse(connected=False, error=err)

       # STEP 2: store config
       self._sessions[request.session_id] = LectureConfig.from_connect_request(request)

       # STEP 3: emit LectureStartEvent — FIRST instruction after validation
       queue = self._get_or_create_queue(request.session_id)
       await queue.put(LectureEvent(
           lecture_start=LectureStartEvent(
               session_id=request.session_id,
               lecture_id=request.lecture_id,
               lecture_name=request.lecture_name,
           ),
           timestamp=now_ms(),
       ))

       # STEP 4: real Collaborate join (same as v1 but using request fields directly)
       join_url = request.join_url  # arrives flat — no parsing needed
       try:
           await self._launch_client(join_url)  # pass join_url, extract token internally
           chime_params = await self._read_chime_params()
           self._stdout_reader_task = asyncio.create_task(self._run_stdout_reader())
           self._stderr_logger_task = asyncio.create_task(self._run_stderr_logger())
           self._bridge = ChimeBridge(chime_params)  # no config params — uses env vars
           await self._bridge.start()
           ...
           return ConnectResponse(connected=True)
       except Exception as exc:
           await self._cleanup()
           return ConnectResponse(connected=False, error=str(exc))
   ```

4. **Rewrite `Disconnect()`:**
   ```python
   async def Disconnect(self, request, context):
       # STEP 1: emit LectureCloseEvent — FIRST instruction
       queue = self._get_or_create_queue(request.session_id)
       await queue.put(LectureEvent(
           lecture_close=LectureCloseEvent(
               session_id=request.session_id,
               reason="disconnect_requested",
           ),
           timestamp=now_ms(),
       ))

       # STEP 2: teardown
       self._disconnect_event.set()
       await self._cleanup()
       self._sessions.pop(request.session_id, None)
       # Do NOT call sys.exit() — Core stops the container via ACA API
       return DisconnectResponse()
   ```

5. **Rewrite `StreamAudio()`:**
   - Parameter: `StreamRequest` (carries `session_id`) — not `ConnectRequest`
   - Returns `stream MediaFrame` — not `stream AudioFrame`
   - Pull from `self._bridge.audio_queue` — same as v1 but queue now contains `MediaFrame`
   - Populate `is_instructor` by matching `bridge.speaker_name` against `config.instructor_full_name`

6. **Rename `StreamVideo()` → `StreamAudioVideo()`:**
   - Was `UNIMPLEMENTED` in v1 — keep `UNIMPLEMENTED` in v2 (video not supported for Collaborate)
   - Parameter: `StreamRequest`
   - Returns `stream MediaFrame`

7. **Rename `SessionEvents()` → `StreamEvents()`:**
   - Parameter: `StreamRequest` (carries `session_id`)
   - Returns `stream LectureEvent`
   - Use `asyncio.Queue` pattern from mock servicer (same as `hardys-connector-lecture-example`)
   - Platform disconnected (from `_raw_event_queue` or bridge `event_queue`):
     ```python
     # v1
     yield pb2.SessionEndedEvent(session_id=..., reason="platform_disconnected", ...)
     
     # v2
     await queue.put(LectureEvent(
         lecture_error=LectureErrorEvent(
             error=LectureError(
                 error_id=str(uuid.uuid4()),
                 type=LectureErrorType.ERROR_PLATFORM_DISCONNECT,
                 severity=LectureErrorSeverity.SEVERITY_ERROR,
                 method="StreamEvents",
                 retryable=False,
                 timestamp=now_ms(),
             )
         ),
         timestamp=now_ms(),
     ))
     ```
   - Inactivity timeout → same `LectureErrorEvent` with `ERROR_STREAM_INTERRUPTED`
   - Stop on `lecture_close` event (yielded by `Disconnect()`)

8. **Rewrite `SendChat()`:**
   - Parameter: `SendChatRequest` (carries `session_id` and `text`)
   - IPC logic unchanged: write `SEND_CHAT:{text}\n` to subprocess stdin

9. **Add `SendControl()`:**
   - Handle `abort`: call `_cleanup()`, remove session
   - Handle `pause`: set `_pause_flags[session_id] = True`
   - Handle `resume`: clear `_pause_flags[session_id]`
   - Return `ControlResponse(acknowledged=True)`

10. **Rewrite `HealthCheck()`:**
    - No `caps` field — not in v2
    - No `management_supported` — not in v2
    - Keep `diagnostics` dict with Collaborate-specific info

11. **Add `GetLectureConfigSchema()`:**
    - Same as mock implementation — read `runtime_fields` from `connector-manifest.json`

12. **Rewrite `TestStream()`:**
    - Parameter: `TestStreamRequest`
    - Returns `stream MediaFrame` with `type=MEDIA_FRAME_AUDIO` — same synthetic PCM as mock

#### `config.py`

Replace the file-based config with a `from_connect_request()` model:

```python
REQUIRED_INSTANCE_FIELDS = ["instance_url"]
REQUIRED_RUNTIME_FIELDS  = ["lecture_id", "join_url", "instructor_full_name"]

@dataclass
class LectureConfig:
    session_id: str
    instance_url: str
    credentials: dict
    params: dict
    inactivity_timeout_seconds: int
    debug_enabled: bool
    lecture_id: str
    lecture_name: str
    join_url: str
    instructor_id: str
    instructor_full_name: str
    instructor_email: str
    audio_enabled: bool
    video_enabled: bool
    chat_read_enabled: bool
    chat_write_enabled: bool

    @classmethod
    def from_connect_request(cls, request) -> "LectureConfig": ...

def validate_required_fields(request) -> tuple[bool, str | None]: ...
```

Remove: `load_config()`, `ConnectorConfig`, all config.json logic.

---

## Files to add (new in v2, not in guest)

- `.gitignore` — include `node_modules/`, `*.wav`, `config.local.json`, `connector_pb2*.py`, `__pycache__/`, `.pytest_cache/`
- `pytest.ini` — same as `hardys-connector-lecture-example`

---

## Files to remove (v1 artifacts, not needed in v2)

- `config.json` — all config arrives in `ConnectRequest`, no config file in production
- `i18n.py` — locale is a Core concern, not a connector concern
- `management_servicer.py` — no management service for link connector
- `test_live.py` — replace with proper unit tests
- `jinx_spy.log`, `jinx_debug.py`, `cdp_jinx_spy.py`, `cdp_chime_spy.py`, `analyze_raw_audio.py` — dev/debug tools, not production code
- `audio.wav`, `hardys_audio_test.wav` — generated files

---

## Tests

Same four test files as the scaffold (Prompt 1), updated for real implementation:

### `tests/test_config.py`
Unchanged from scaffold — validates `from_connect_request()` and `validate_required_fields()`.

### `tests/test_mock_data.py`
Unchanged from scaffold — `mock_data.py` is pure synthetic data.

### `tests/test_servicer.py`
Expand scaffold tests with Collaborate-specific cases:
- `test_connect_missing_join_url` — join_url required
- `test_connect_emits_lecture_start_event` — verify `LectureStartEvent` is in StreamEvents queue after Connect
- `test_disconnect_emits_lecture_close_event` — verify `LectureCloseEvent` is in StreamEvents queue
- `test_send_control_abort_removes_session`
- `test_send_control_pause_sets_flag`
- `test_send_control_resume_clears_flag`
- `test_stream_audio_requires_connect` — abort with FAILED_PRECONDITION if bridge is None
- `test_test_stream_works_without_connect` — TestStream works with no prior Connect

All real Collaborate tests (subprocess launch, Chime, jinx) must be mocked. No real network calls in tests.

### `tests/test_manifest.py`
Same as scaffold — unchanged.

---

## `CLAUDE.md` updates

Replace the scaffold CLAUDE.md stub sections with real content:
- Document the 5-step HTTP join flow (from `docs/auth-flow.md`)
- Document the jinx protocol key facts
- Document the Chime bridge env vars (`CHIME_AUDIO_PORT`, `CHIME_META_PORT`, `CHIME_VOLUME_THRESHOLD`, `NODE_EXECUTABLE`)
- Document the subprocess IPC protocol (stdout lines: `JINX_CHAT:`, `ATTENDEE_ID:`, `SESSION_ENDED:`; stdin lines: `SEND_CHAT:`, `DISCONNECT`)
- Document known issue: Chime audio peak=0 in headless mode (under investigation)

---

## `README.md` updates

Expand README with:
- Node.js 18+ as prerequisite
- `npm install` step before running
- How the connector works (Collaborate join → Chime audio → jinx chat)
- Known issue: Chime audio in headless mode
- Env vars for Chime bridge configuration

---

## Final checklist before committing

- [ ] `collaborate/` folder present with: `__init__.py`, `jinx.py`, `client.py`, `chime_bridge.py`, `chime_receiver.js`
- [ ] `chime_bridge.py` builds `MediaFrame` (not `AudioFrame`) — verified by grep
- [ ] `chime_bridge.py` uses env vars (not config object) — verified by grep
- [ ] `servicer.py` has no `Register()` method
- [ ] `servicer.py` has no `SessionEvents()` method — replaced by `StreamEvents()`
- [ ] `servicer.py` `Connect()` emits `LectureStartEvent` as FIRST instruction after validation
- [ ] `servicer.py` `Disconnect()` emits `LectureCloseEvent` as FIRST instruction
- [ ] `servicer.py` has no `sys.exit()` call
- [ ] `servicer.py` `StreamAudio()` takes `StreamRequest` parameter (not `ConnectRequest`)
- [ ] `servicer.py` `StreamAudio()` returns `MediaFrame` with `type=MEDIA_FRAME_AUDIO`
- [ ] `config.py` has `from_connect_request()` and `validate_required_fields()` — no `load_config()`
- [ ] `config.json` does NOT exist in the repo
- [ ] `i18n.py` does NOT exist in the repo
- [ ] `management_servicer.py` does NOT exist in the repo
- [ ] `node_modules/` is in `.gitignore`
- [ ] `package.json` is present for chime_receiver.js dependencies
- [ ] All tests pass: `pytest tests/ -v`
- [ ] `python connector.py health` exits 0
- [ ] `python connector.py run --mock --duration 5 --output all` runs without error
- [ ] No `AudioFrame` reference anywhere in the codebase — use grep to verify
- [ ] No `SessionEvents` reference anywhere in the codebase — use grep to verify
- [ ] No `Register` method anywhere in `servicer.py` — use grep to verify
