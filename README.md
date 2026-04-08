# hardys-connector-sdk

The multi-class SDK for Hardys Connector agents.

This repository is the **normative home for all `.proto` files** across all
Hardys connector classes. It defines the gRPC contracts that every connector
must implement to be compatible with Hardys Core.

**Class-specific SDKs** (reference implementations and templates) live in
separate repos — one per class:

| Class | SDK repo | What it integrates |
|-------|----------|--------------------|
| `lecture` | [`juvantio/hardys-connector-sdk-lecture`](https://github.com/juvantio/hardys-connector-sdk-lecture) | Live teaching sessions (Collaborate, Teams, Zoom, Meet) |
| `content` | `juvantio/hardys-connector-sdk-content` (future) | Content repositories |
| `identity` | `juvantio/hardys-connector-sdk-identity` (future) | Identity systems |
| `assessment` | `juvantio/hardys-connector-sdk-assessment` (future) | Assessment platforms |

---

## Repository structure

```
hardys-connector-sdk/
  protos/
    lecture/
      connector.proto    <- lecture class contract (ConnectorService + ManagementService)
    content/             <- future
    identity/            <- future
    assessment/          <- future
  docs/
    getting-started.md   <- how to build a connector
    connector-classes.md <- class taxonomy and data flows
    governance.md        <- how to propose new classes or contract changes
  README.md
  CLAUDE.md
```

---

## How to use the protos

Copy the relevant `.proto` file into your connector repo and generate stubs:

```bash
# Python
python -m grpc_tools.protoc \
  -I protos \
  --python_out=. \
  --grpc_python_out=. \
  protos/lecture/connector.proto

# Go
protoc --go_out=. --go-grpc_out=. protos/lecture/connector.proto

# Node.js — use @grpc/proto-loader at runtime (no codegen needed)
```

---

## Connector naming conventions

**connector_id:** `{class}.{platform}` — e.g. `lecture.collaborate_guest`

**Connector implementation repos:** `juvantio/hardys-connector-{class}-{platform}`

**Class SDK repos:** `juvantio/hardys-connector-sdk-{class}`

---

## Configuration model (ADR-008)

Three levels, three lifecycle owners:

| Level | Fields | Owner | When |
|-------|--------|-------|------|
| **Static** | connector_class, connector_id, version | Baked into Docker image | Build time |
| **Instance** | instance_url, credentials, locale, timeouts | Hardys Core via RegisterResponse | Container boot |
| **Session** | session_id, session_token, join_url | Hardys Core via ConnectRequest | Each session |

**GetConfigSchema()** — every connector exposes a JSON Schema describing its
instance-level configuration fields. Hardys Core reads this and dynamically
generates the admin UI form. No hardcoded connector fields in Core.

---

## Related

- [ADR-005](https://github.com/juvantio/hardys-pm/blob/main/docs/decisions/ADR-005-grpc-connector-protocol.md) — gRPC as connector protocol
- [ADR-006](https://github.com/juvantio/hardys-pm/blob/main/docs/decisions/ADR-006-connector-class-taxonomy.md) — connector class taxonomy
- [ADR-007](https://github.com/juvantio/hardys-pm/blob/main/docs/decisions/ADR-007-connector-deployment-model.md) — deployment model
- [ADR-008](https://github.com/juvantio/hardys-pm/blob/main/docs/decisions/ADR-008-connector-configuration-model.md) — configuration model
- HCF v1.0 — Hardys Connector Framework specification
