#!/bin/bash

# Prepares DAST target URL, verifies connectivity, and optionally starts the application.
set -e

DAST_TARGET="${DAST_TARGET:-}"
DAST_START_COMMAND="${DAST_START_COMMAND:-}"
DAST_START_WAIT_SECONDS="${DAST_START_WAIT_SECONDS:-15}"
DAST_REPORT_DIR="${DAST_REPORT_DIR:-dast-reports}"
DAST_FAIL_ON_UNREACHABLE="${DAST_FAIL_ON_UNREACHABLE:-false}"
DAST_CONNECT_TIMEOUT="${DAST_CONNECT_TIMEOUT:-30}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
log_warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

write_unreachable_status() {
  local reason="$1"
  mkdir -p "$DAST_REPORT_DIR"
  cat > "$DAST_REPORT_DIR/dast-status.txt" <<EOF
status=unreachable
target=$DAST_TARGET
reason=$reason
hint=Ensure the target is publicly reachable from GitHub Actions runners. Firewalls, WAFs, and geo-blocks often block cloud CI IPs. Allow GitHub Actions IP ranges or use a self-hosted runner inside your network.
docs=https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-githubs-ip-addresses
EOF
  echo "DAST_TARGET_REACHABLE=false" >> "${GITHUB_ENV:-/dev/null}"
}

if [ -z "$DAST_TARGET" ]; then
  echo "DAST_TARGET is not set; skipping DAST preparation."
  exit 0
fi

mkdir -p "$DAST_REPORT_DIR"

# ZAP runs inside Docker on Linux runners — localhost must be rewritten to the runner IP.
if echo "$DAST_TARGET" | grep -qE 'localhost|127\.0\.0\.1'; then
  RUNNER_IP="$(hostname -I | awk '{print $1}')"
  DAST_TARGET="$(echo "$DAST_TARGET" | sed "s/localhost/${RUNNER_IP}/g" | sed "s/127\.0\.0\.1/${RUNNER_IP}/g")"
  log_info "Rewrote localhost DAST target for Docker-based ZAP scan: $DAST_TARGET"
fi

echo "DAST_TARGET=$DAST_TARGET" >> "${GITHUB_ENV:-/dev/null}"

if [ -n "$DAST_START_COMMAND" ]; then
  log_info "Starting application for DAST: $DAST_START_COMMAND"
  bash -lc "$DAST_START_COMMAND" &
  echo $! > /tmp/dast-app.pid
  log_info "Waiting ${DAST_START_WAIT_SECONDS}s for application to become ready..."
  sleep "$DAST_START_WAIT_SECONDS"
fi

log_info "Checking DAST target connectivity: $DAST_TARGET"
if curl -sSf --connect-timeout "$DAST_CONNECT_TIMEOUT" --max-time "$((DAST_CONNECT_TIMEOUT * 2))" \
  -o /dev/null "$DAST_TARGET"; then
  log_success "DAST target is reachable."
  echo "DAST_TARGET_REACHABLE=true" >> "${GITHUB_ENV:-/dev/null}"
else
  log_warning "DAST target is not reachable from the GitHub Actions runner (connect timeout or blocked)."
  write_unreachable_status "Connect timed out or connection refused from GitHub Actions runner."

  if [ "$DAST_FAIL_ON_UNREACHABLE" = "true" ]; then
    log_error "DAST target $DAST_TARGET is unreachable. Allow GitHub Actions IPs or use a self-hosted runner."
  fi

  log_warning "Skipping OWASP ZAP scan because the target is unreachable."
  exit 0
fi

log_info "DAST target ready: $DAST_TARGET"
