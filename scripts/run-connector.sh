#!/usr/bin/env bash
# =============================================================================
# run-connector.sh
# Pull a Hardys connector image, read its OCI manifest, and start the container.
#
# Usage:
#   bash scripts/run-connector.sh <image> [port]
#
# Examples:
#   bash scripts/run-connector.sh ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0
#   bash scripts/run-connector.sh ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0 50052
#
# Requirements: docker
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

IMAGE="${1:-}"
PORT="${2:-50051}"

if [[ -z "$IMAGE" ]]; then
  echo "Usage: bash scripts/run-connector.sh <image> [port]"
  echo ""
  echo "  <image>  Full image reference, e.g. ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0"
  echo "  [port]   Host port to bind the gRPC server on (default: 50051)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 1 — Pull the image
# ---------------------------------------------------------------------------

echo ""
echo "[1/4] Pulling image: $IMAGE"
docker pull "$IMAGE"

# ---------------------------------------------------------------------------
# Step 2 — Read connector-manifest.json via OCI annotation
# ---------------------------------------------------------------------------

echo ""
echo "[2/4] Reading OCI manifest annotation..."

MANIFEST_PATH=$(docker inspect "$IMAGE" \
  --format '{{index .Config.Labels "org.hardys.connector.manifest-path"}}' 2>/dev/null || true)

if [[ -z "$MANIFEST_PATH" ]]; then
  echo "WARNING: OCI annotation 'org.hardys.connector.manifest-path' not found on image."
  echo "         This image may not be a valid Hardys connector."
else
  echo "  Manifest path declared in image: $MANIFEST_PATH"

  # Create a temporary container to extract the manifest (without starting it)
  TMP_CONTAINER=$(docker create "$IMAGE" 2>/dev/null)
  MANIFEST_JSON=$(docker cp "${TMP_CONTAINER}:${MANIFEST_PATH}" - 2>/dev/null \
    | tar -xO 2>/dev/null || echo "")
  docker rm "$TMP_CONTAINER" > /dev/null 2>&1 || true

  if [[ -n "$MANIFEST_JSON" ]]; then
    echo ""
    echo "  connector-manifest.json:"
    echo "$MANIFEST_JSON" | sed 's/^/    /'
  else
    echo "WARNING: Could not read manifest file from container at $MANIFEST_PATH"
  fi
fi

# ---------------------------------------------------------------------------
# Step 3 — Start the container
# ---------------------------------------------------------------------------

CONTAINER_NAME="hardys-connector-$(date +%s)"

echo ""
echo "[3/4] Starting container..."
echo "  Name:  $CONTAINER_NAME"
echo "  Image: $IMAGE"
echo "  Port:  $PORT -> 50051"

docker run \
  --detach \
  --name "$CONTAINER_NAME" \
  --publish "${PORT}:50051" \
  "$IMAGE"

# ---------------------------------------------------------------------------
# Step 4 — Print endpoint
# ---------------------------------------------------------------------------

echo ""
echo "[4/4] Connector started."
echo ""
echo "  gRPC endpoint:  localhost:${PORT}"
echo "  Container name: $CONTAINER_NAME"
echo ""
echo "  Health check:"
echo "    grpcurl -plaintext localhost:${PORT} hardys.connector.lecture.v2.ConnectorService/HealthCheck"
echo ""
echo "  Stop the connector:"
echo "    docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
echo ""
