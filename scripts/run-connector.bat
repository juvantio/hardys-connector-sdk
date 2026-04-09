@echo off
REM =============================================================================
REM run-connector.bat
REM Pull a Hardys connector image, read its OCI manifest, and start the container.
REM
REM Usage:
REM   run-connector.bat <image> [port]
REM
REM Examples:
REM   run-connector.bat ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0
REM   run-connector.bat ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0 50052
REM
REM Requirements: docker
REM =============================================================================

setlocal EnableDelayedExpansion

REM ---------------------------------------------------------------------------
REM Arguments
REM ---------------------------------------------------------------------------

set IMAGE=%~1
set PORT=%~2

if "%IMAGE%"=="" (
  echo Usage: run-connector.bat ^<image^> [port]
  echo.
  echo   ^<image^>  Full image reference, e.g. ghcr.io/juvantio/hardys-connector-lecture-teams:1.0.0
  echo   [port]   Host port to bind the gRPC server on (default: 50051^)
  exit /b 1
)

if "%PORT%"=="" set PORT=50051

REM ---------------------------------------------------------------------------
REM Step 1 - Pull the image
REM ---------------------------------------------------------------------------

echo.
echo [1/4] Pulling image: %IMAGE%
docker pull %IMAGE%
if errorlevel 1 (
  echo ERROR: Failed to pull image.
  exit /b 1
)

REM ---------------------------------------------------------------------------
REM Step 2 - Read connector-manifest.json via OCI annotation
REM ---------------------------------------------------------------------------

echo.
echo [2/4] Reading OCI manifest annotation...

for /f "delims=" %%L in ('docker inspect %IMAGE% --format "{{index .Config.Labels \"org.hardys.connector.manifest-path\"}}" 2^>nul') do (
  set MANIFEST_PATH=%%L
)

if "%MANIFEST_PATH%"=="" (
  echo WARNING: OCI annotation 'org.hardys.connector.manifest-path' not found on image.
  echo          This image may not be a valid Hardys connector.
) else (
  echo   Manifest path declared in image: %MANIFEST_PATH%

  REM Create a temporary container to extract the manifest
  for /f "delims=" %%C in ('docker create %IMAGE% 2^>nul') do set TMP_CONTAINER=%%C

  echo.
  echo   Extracting connector-manifest.json...
  docker cp "%TMP_CONTAINER%:%MANIFEST_PATH%" "%TEMP%\hardys-manifest.json" >nul 2>&1
  docker rm %TMP_CONTAINER% >nul 2>&1

  if exist "%TEMP%\hardys-manifest.json" (
    echo   connector-manifest.json:
    type "%TEMP%\hardys-manifest.json"
    del "%TEMP%\hardys-manifest.json" >nul 2>&1
  ) else (
    echo WARNING: Could not read manifest file from container at %MANIFEST_PATH%
  )
)

REM ---------------------------------------------------------------------------
REM Step 3 - Start the container
REM ---------------------------------------------------------------------------

for /f "delims=" %%T in ('powershell -command "[int](Get-Date -UFormat %%s)"') do set TIMESTAMP=%%T
set CONTAINER_NAME=hardys-connector-%TIMESTAMP%

echo.
echo [3/4] Starting container...
echo   Name:  %CONTAINER_NAME%
echo   Image: %IMAGE%
echo   Port:  %PORT% -^> 50051

docker run ^
  --detach ^
  --name "%CONTAINER_NAME%" ^
  --publish "%PORT%:50051" ^
  %IMAGE%

if errorlevel 1 (
  echo ERROR: Failed to start container.
  exit /b 1
)

REM ---------------------------------------------------------------------------
REM Step 4 - Print endpoint
REM ---------------------------------------------------------------------------

echo.
echo [4/4] Connector started.
echo.
echo   gRPC endpoint:  localhost:%PORT%
echo   Container name: %CONTAINER_NAME%
echo.
echo   Health check:
echo     grpcurl -plaintext localhost:%PORT% hardys.connector.lecture.v2.ConnectorService/HealthCheck
echo.
echo   Stop the connector:
echo     docker stop %CONTAINER_NAME% ^&^& docker rm %CONTAINER_NAME%
echo.

endlocal
