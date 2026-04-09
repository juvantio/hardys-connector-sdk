# ConnectorManagementService — Optional Pre-Lecture Discovery

`ConnectorManagementService` is **not defined in the proto contract**. If your platform has an API for lecture discovery and activation, you may implement it as an additional gRPC service in your connector.

If not implemented, return `UNIMPLEMENTED` status on any management-related calls.

## Faculty App UX (implemented by Core)

- If the connector supports management → Faculty App shows a lecture list, tap to activate
- If not → Faculty App shows a text field for guest link / join URL

Core determines support by inspecting the connector's capabilities or by attempting a `ListLectures` call.

## Recommended interface (if implementing)

```proto
service ConnectorManagementService {
  rpc ListLectures    (ListLecturesRequest)    returns (ListLecturesResponse);
  rpc GetLecture      (GetLectureRequest)      returns (LectureInfo);
  rpc ActivateLecture (ActivateLectureRequest) returns (ActivateLectureResponse);
}

message ListLecturesRequest   { string course_id = 1; string date = 2; }
message LectureInfo           { string lecture_id = 1; string lecture_name = 2; string start_time = 3; string end_time = 4; bool is_active = 5; bool audio_enabled = 6; }
message ListLecturesResponse  { repeated LectureInfo lectures = 1; }
message GetLectureRequest     { string lecture_id = 1; }

message ActivateLectureRequest {
  string lecture_id           = 1;
  bool   audio_enabled        = 2;
  bool   video_enabled        = 3;
  bool   chat_read_enabled    = 4;
  bool   chat_write_enabled   = 5;
  string instructor_id        = 6;
  string instructor_full_name = 7;
  string instructor_email     = 8;
}

message ActivateLectureResponse {
  bool   success    = 1;
  string error      = 2;
  string lecture_id = 3;
  string join_url   = 4;  // populated on success — used in ConnectRequest
}
```

`ActivateLecture` internally creates the enrollment/join URL via the platform API. The Faculty App never sees platform credentials. The returned `join_url` is then used by Core in the subsequent `ConnectRequest`.
