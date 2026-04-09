# =============================================================================
# run-connector.ps1
# Pull a Hardys connector image, read its OCI manifest, and start the container.
#
# Usage:
#   .\scripts\run-connector.ps1 -Image <image> [-Port <port>]
#
# Examples:
#   .\scripts\run-connector.ps1 -Image ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0
#   .\scripts\run-connector.ps1 -Image ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0 -Port 50052
#
# Requirements: docker
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0,
        HelpMessage = "Full image reference, e.g. ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0")]
    [string]$Image,

    [Parameter(Mandatory = $false, Position = 1,
        HelpMessage = "Host port to bind the gRPC server on (default: 50051)")]
    [int]$Port = 50051
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Step 1 - Pull the image
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "[1/4] Pulling image: $Image" -ForegroundColor Cyan
docker pull $Image
if ($LASTEXITCODE -ne 0) { throw "Failed to pull image: $Image" }

# ---------------------------------------------------------------------------
# Step 2 - Read connector-manifest.json via OCI annotation
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "[2/4] Reading OCI manifest annotation..." -ForegroundColor Cyan

$ManifestPath = docker inspect $Image --format '{{index .Config.Labels "org.hardys.connector.manifest-path"}}' 2>$null

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    Write-Host "WARNING: OCI annotation 'org.hardys.connector.manifest-path' not found on image." -ForegroundColor Yellow
    Write-Host "         This image may not be a valid Hardys connector." -ForegroundColor Yellow
} else {
    Write-Host "  Manifest path declared in image: $ManifestPath"

    # Create a temporary container to extract the manifest (without starting it)
    $TmpContainer = docker create $Image 2>$null
    $TmpFile = [System.IO.Path]::GetTempFileName()

    try {
        docker cp "${TmpContainer}:${ManifestPath}" $TmpFile 2>$null | Out-Null
        if (Test-Path $TmpFile) {
            $ManifestJson = Get-Content $TmpFile -Raw | ConvertFrom-Json
            Write-Host ""
            Write-Host "  connector-manifest.json:"
            Write-Host ($ManifestJson | ConvertTo-Json -Depth 10) -ForegroundColor Gray
        } else {
            Write-Host "WARNING: Could not read manifest file from container at $ManifestPath" -ForegroundColor Yellow
        }
    } finally {
        docker rm $TmpContainer 2>$null | Out-Null
        Remove-Item $TmpFile -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Step 3 - Start the container
# ---------------------------------------------------------------------------

$Timestamp = [int](Get-Date -UFormat "%s")
$ContainerName = "hardys-connector-$Timestamp"

Write-Host ""
Write-Host "[3/4] Starting container..." -ForegroundColor Cyan
Write-Host "  Name:  $ContainerName"
Write-Host "  Image: $Image"
Write-Host "  Port:  $Port -> 50051"

docker run `
    --detach `
    --name $ContainerName `
    --publish "${Port}:50051" `
    $Image

if ($LASTEXITCODE -ne 0) { throw "Failed to start container." }

# ---------------------------------------------------------------------------
# Step 4 - Print endpoint
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "[4/4] Connector started." -ForegroundColor Green
Write-Host ""
Write-Host "  gRPC endpoint:  " -NoNewline
Write-Host "localhost:$Port" -ForegroundColor Yellow
Write-Host "  Container name: $ContainerName"
Write-Host ""
Write-Host "  Health check:"
Write-Host "    grpcurl -plaintext localhost:$Port hardys.connector.lecture.v2.ConnectorService/HealthCheck" -ForegroundColor Gray
Write-Host ""
Write-Host "  Stop the connector:"
Write-Host "    docker stop $ContainerName; docker rm $ContainerName" -ForegroundColor Gray
Write-Host ""
