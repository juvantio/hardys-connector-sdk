# Getting Started — Hardys Connector SDK

This guide explains how to build a Hardys connector using the SDK.

## What you need

- The `.proto` file for your connector class from this repo
- The class-specific SDK repo as your starting point
  (e.g. `juvantio/hardys-connector-sdk-lecture` for the lecture class)
- Docker for packaging
- Python 3.12+ (or Go, Node.js, Java — the proto is language-agnostic)

## Step 1 — Fork the class SDK

```bash
git clone https://github.com/juvantio/hardys-connector-sdk-lecture.git
cd hardys-connector-sdk-lecture
```

The class SDK contains a full mock implementation. Replace mock methods with
your platform-specific logic.

## Step 2 — Understand the configuration model (ADR-008)

| Level | Fields | Owner | When |
|-------|--------|-------|------|
| Static | connector_class, connector_id, version | Docker image | Build time |
| Instance | instance_url, credentials, locale, timeouts | Core via RegisterResponse | Container boot |
| Session | session_id, session_token, join_url | Core via ConnectRequest | Each session |

In production, `config.json` is not used — all config arrives from Hardys Core via gRPC.

## Step 3 — Implement GetConfigSchema()

Every connector must return a JSON Schema describing its instance-level config:

```python
CONNECTOR_CONFIG_SCHEMA = {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "My Platform Connector",
    "type": "object",
    "properties": {
        "instance_url": {"type": "string", "title": "Platform Base URL"},
        # "api_key": {"type": "password", "title": "API Key"},
        # "region": {"type": "enum", "enum": ["eu", "us"], "title": "Region"},
    },
    "required": ["instance_url"],
}
```

Supported admin UI field types: `string`, `password`, `integer`, `boolean`, `enum`.

## Step 4 — Implement the streaming methods

- `Register()` — apply instance config from `RegisterResponse.config`
- `Connect()` — join using `request.session.session_token` / `request.session.join_url`
- `StreamAudio()` — yield raw PCM frames (16-bit, 16kHz, mono, 20ms)
- `StreamChat()` — yield plain text (strip HTML)
- `SessionEvents()` — emit `platform_disconnected` when session ends
- `GetConfigSchema()` — return JSON Schema for instance config

## Step 5 — Test in isolation

```bash
python connector.py health
python connector.py run --mock --duration 30 --output audio.wav
python connector.py serve --port 50051
```

## Step 6 — Package and publish

```bash
docker build -t ghcr.io/YOUR_ORG/hardys-connector-{class}-{platform}:1.0.0 .
docker push ghcr.io/YOUR_ORG/hardys-connector-{class}-{platform}:1.0.0
```
