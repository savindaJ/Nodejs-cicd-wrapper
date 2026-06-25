#!/bin/bash

# Prepares DAST target URL and optionally starts the application before OWASP ZAP runs.
set -e

DAST_TARGET="${DAST_TARGET:-}"
DAST_START_COMMAND="${DAST_START_COMMAND:-}"
DAST_START_WAIT_SECONDS="${DAST_START_WAIT_SECONDS:-15}"
DAST_REPORT_DIR="${DAST_REPORT_DIR:-dast-reports}"

if [ -z "$DAST_TARGET" ]; then
  echo "DAST_TARGET is not set; skipping DAST preparation."
  exit 0
fi

# ZAP runs inside Docker on Linux runners — localhost must be rewritten to the runner IP.
if echo "$DAST_TARGET" | grep -qE 'localhost|127\.0\.0\.1'; then
  RUNNER_IP="$(hostname -I | awk '{print $1}')"
  DAST_TARGET="$(echo "$DAST_TARGET" | sed "s/localhost/${RUNNER_IP}/g" | sed "s/127\.0\.0\.1/${RUNNER_IP}/g")"
  echo "Rewrote localhost DAST target for Docker-based ZAP scan: $DAST_TARGET"
fi

mkdir -p "$DAST_REPORT_DIR"
echo "DAST_TARGET=$DAST_TARGET" >> "${GITHUB_ENV:-/dev/null}"

if [ -n "$DAST_START_COMMAND" ]; then
  echo "Starting application for DAST: $DAST_START_COMMAND"
  bash -lc "$DAST_START_COMMAND" &
  echo $! > /tmp/dast-app.pid
  echo "Waiting ${DAST_START_WAIT_SECONDS}s for application to become ready..."
  sleep "$DAST_START_WAIT_SECONDS"
fi

echo "DAST target ready: $DAST_TARGET"
