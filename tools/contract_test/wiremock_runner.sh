#!/usr/bin/env bash
# Starts WireMock seeded with the stubs JAR, then runs the consumer test command passed as remaining args.
set -euo pipefail

WIREMOCK_JAR="$1"
STUBS_JAR="$2"
WIREMOCK_PORT="$3"
shift 3

STUBS_DIR="$(mktemp -d)"
trap 'rm -rf "$STUBS_DIR"; kill "$WIREMOCK_PID" 2>/dev/null || true' EXIT

# Extract WireMock mappings from stubs JAR
(cd "$STUBS_DIR" && jar xf "$STUBS_JAR" mappings/ 2>/dev/null || true)

# Start WireMock
java -jar "$WIREMOCK_JAR" \
  --port "$WIREMOCK_PORT" \
  --root-dir "$STUBS_DIR" \
  --no-request-journal \
  &>/tmp/wiremock.log &
WIREMOCK_PID=$!

# Wait for WireMock to be ready (up to 10 seconds)
for i in $(seq 1 20); do
  if curl -sf "http://localhost:$WIREMOCK_PORT/__admin/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

export CONTRACT_TEST_BASE_URL="http://localhost:$WIREMOCK_PORT"
"$@"
