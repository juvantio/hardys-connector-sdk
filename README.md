# hardys-connector-sdk

Normative gRPC contract definitions for all Hardys connector classes.

This repository is the single source of truth for the Hardys Connector Framework (HCF). All connectors implement the contracts defined here.

## Repository structure

```
protos/
  lecture/
    connector.proto              ← Lecture class ConnectorService (v2)
  content/                       ← future
  identity/                      ← future
  assessment/                    ← future
connector-manifest-schema.json   ← JSON schema for connector-manifest.json
connector-manifest-example.json  ← Complete example manifest
scripts/
  docker-publish.yml             ← GitHub Actions workflow template — copy to your connector repo
docs/
  getting-started.md             ← Build your first connector
  connector-classes.md           ← Class taxonomy and naming
  event-driven-pattern.md        ← StreamEvents + SendControl pattern
  management-service.md          ← Optional management service pattern
  governance.md                  ← Versioning, changelog, certification
README.md
CLAUDE.md
```

## Quick start

1. Read `docs/getting-started.md`
2. Copy `protos/lecture/connector.proto` into your connector repo
3. Generate stubs for your language
4. Implement `ConnectorService`
5. Publish `connector-manifest.json` as OCI annotation on your image
6. Copy `scripts/docker-publish.yml` to `.github/workflows/` in your repo
7. See `docs/event-driven-pattern.md` for lifecycle event pattern

## Architecture

### Deployment model

- **One ACA Container App per connector type** — long-running process (not a Job)
- **Core manages container lifecycle** via Azure API (`azure-mgmt-appcontainers`)
- **Container never exits by itself** — Core starts and stops it
- **Single/multi session** is a Core policy decision — connector is indifferent

### Configuration model

- **Zero env vars for config** — everything arrives in `ConnectRequest`
- **`connector-manifest.json`** published as OCI annotation — read by Core without starting the container
- **Admin configures `instance_fields`** in Core UI → saved to Cosmos DB
- **Core passes `runtime_fields`** (lecture_id, join_url, instructor, etc.) in `ConnectRequest` at lecture time

### Fully event-driven — no callback servers

- **Core → Connector:** method calls (`Connect`, `SendControl`, etc.)
- **Connector → Core:** typed events on `StreamEvents`

### MediaFrame — universal media frame

Both `StreamAudio` and `StreamAudioVideo` return `stream MediaFrame`. `MediaFrameType` declares the content:
- `MEDIA_FRAME_AUDIO` — PCM 16-bit 16kHz mono
- `MEDIA_FRAME_AUDIO_VIDEO` — audio+video multiplexed by the connector

No separate `AudioFrame` or `VideoFrame`.

### Config validation — mandatory

Every connector MUST validate all `required=true` fields at the start of `Connect()` before any platform operation. Return error immediately if any field is missing.

## Docker image publishing

**Setup (one-time per connector repo):**
```bash
mkdir -p .github/workflows
cp scripts/docker-publish.yml .github/workflows/docker-publish.yml
git add .github/workflows/docker-publish.yml
git commit -m "ci: add Docker publish workflow"
git push
```

**No secrets required** — the workflow uses the built-in `GITHUB_TOKEN`.

**Publish a release:**
```bash
git tag v1.0.0 && git push origin v1.0.0
# Produces: ghcr.io/{org}/{repo}:1.0.0, :1.0, :1, :latest
```

**Run a connector locally:**
```bash
# Use run-connector scripts from juvantio/juvant-dev-tools/hardys/scripts/
bash run-connector.sh ghcr.io/{org}/{repo}:1.0.0 [port]
```

## Package versions

| Package | Version | File |
|---|---|---|
| `hardys.connector.lecture` | v2 | `protos/lecture/connector.proto` |

See `docs/governance.md` for the full changelog.

## Related repositories

- `juvantio/hardys-connector-lecture-example` — Reference implementation (lecture class)
- `juvantio/juvant-dev-tools` — Dev tools, run scripts, prompts
- `juvantio/hardys-pm` — Project management
