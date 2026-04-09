# scripts/

Utility scripts for working with Hardys connector images locally and for CI/CD.

---

## run-connector

Pulls a connector image from `ghcr.io`, reads its `connector-manifest.json` via OCI annotation (without starting the container), then starts the connector and prints the gRPC endpoint.

Three equivalent versions — use whichever matches your OS:

| Script | Platform |
|---|---|
| `run-connector.sh` | macOS / Linux |
| `run-connector.bat` | Windows (Command Prompt) |
| `run-connector.ps1` | Windows (PowerShell) |

### Usage

**macOS / Linux:**
```bash
bash scripts/run-connector.sh <image> [port]

# Examples:
bash scripts/run-connector.sh ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0
bash scripts/run-connector.sh ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0 50052
```

**Windows (Command Prompt):**
```bat
scripts\run-connector.bat <image> [port]

scripts\run-connector.bat ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0
scripts\run-connector.bat ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0 50052
```

**Windows (PowerShell):**
```powershell
.\scripts\run-connector.ps1 -Image <image> [-Port <port>]

.\scripts\run-connector.ps1 -Image ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0
.\scripts\run-connector.ps1 -Image ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0 -Port 50052
```

### What it does

```
[1/4] Pull image from ghcr.io
[2/4] Read OCI annotation -> extract connector-manifest.json (no container started)
[3/4] Start container, bind gRPC port
[4/4] Print endpoint + health check + stop command
```

### Arguments

| Argument | Description | Default |
|---|---|---|
| `image` | Full image reference | required |
| `port` | Host port for gRPC server | `50051` |

### Example output

```
[1/4] Pulling image: ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0
...

[2/4] Reading OCI manifest annotation...
  Manifest path declared in image: /app/connector-manifest.json

  connector-manifest.json:
    {
      "manifest_version": "1.0",
      "connector_id": "lecture.teams",
      "connector_class": "lecture",
      ...
    }

[3/4] Starting container...
  Name:  hardys-connector-1744123456
  Image: ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0
  Port:  50051 -> 50051

[4/4] Connector started.

  gRPC endpoint:  localhost:50051
  Container name: hardys-connector-1744123456

  Health check:
    grpcurl -plaintext localhost:50051 hardys.connector.lecture.v2.ConnectorService/HealthCheck

  Stop the connector:
    docker stop hardys-connector-1744123456 && docker rm hardys-connector-1744123456
```

### Requirements

- Docker installed and running
- Access to `ghcr.io/juvantio` (login with `docker login ghcr.io` if needed)
- Optional: [grpcurl](https://github.com/fullstorydev/grpcurl) for the health check command

---

## docker-publish.yml

GitHub Actions workflow template for building and pushing the connector image to `ghcr.io`.

**Copy this file to your connector repo:**
```bash
mkdir -p .github/workflows
cp scripts/docker-publish.yml .github/workflows/docker-publish.yml
```

See [docs/getting-started.md](../docs/getting-started.md) for full setup instructions.
