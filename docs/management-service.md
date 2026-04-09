# ConnectorManagementService — Pre-Lecture Discovery and Activation

## Overview

`ConnectorManagementService` is an **optional** service. Connectors declare whether they implement it via `management_supported` in `HealthCheckResponse`.

**Faculty App UX based on `management_supported`:**
- `true` → Faculty App shows a list of today's lectures. Instructor taps to activate Hardys.
- `false` → Faculty App shows a text field. Instructor pastes the guest link or session token.

**Design principle: the Faculty App never calls platform APIs directly.** All platform interaction — lecture discovery, enrollment creation, join — goes through the connector's `ConnectorManagementService`.

## Which connectors implement it?

| Connector | `management_supported` | Reason |
|---|---|---|
| `lecture.collaborate_guest` | `false` | No API access — guest link only |
| `lecture.collaborate_api` | `true` | Collaborate REST API with LTI credentials |
| `lecture.teams` | `true` | Teams Meeting Bot SDK |
| `lecture.google_meet` | `true` | Google Meet Media API |
| `lecture.zoom` | `true` | Zoom Meeting SDK server-to-server OAuth |

## Methods

### ListLectures
Returns today's lectures for a course. Faculty App calls this to show the lecture list.

```proto
message ListLecturesRequest {
  string course_id = 1;
  string date      = 2;  // ISO date YYYY-MM-DD — defaults to today
}

message LectureInfo {
  string lecture_id    = 1;
  string lecture_name  = 2;
  string start_time    = 3;  // ISO 8601
  string end_time      = 4;  // ISO 8601
  bool   is_active     = 5;
  bool   audio_enabled = 6;
}
```

### GetLecture
Returns details for a specific lecture.

### ActivateLecture
Core calls this when the instructor taps to activate Hardys. The connector:
1. Creates enrollment (if needed)
2. Obtains the join URL
3. Internally triggers the full `Connect` flow
4. Returns `ActivateLectureResponse` with `ConnectResponse` details

```proto
message ActivateLectureRequest {
  string         lecture_id  = 1;
  LectureConfig  config      = 2;
  InstructorInfo instructor  = 3;  // Core passes who the instructor is
}

message ActivateLectureResponse {
  bool            success = 1;
  string          error   = 2;
  ConnectResponse details = 3;  // populated on success
}
```

`InstructorInfo` is included in `ActivateLectureRequest` so the connector can match the instructor immediately when the lecture starts — without waiting for a separate `Connect` call.

## Faculty App code path

The Faculty App uses a single code path regardless of connector type:

```
1. Call HealthCheck → read management_supported
2. If true:  Call ListLectures → show list → instructor taps → Call ActivateLecture
   If false: Show text field → instructor pastes link → Core calls Connect directly
```

No platform-specific branching in the Faculty App.
