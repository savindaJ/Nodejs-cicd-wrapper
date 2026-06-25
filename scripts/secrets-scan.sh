#!/bin/bash

# Installs Gitleaks and scans the repository for hardcoded secrets in code and Git history.
set -e

SECRETS_REPORT_DIR="${SECRETS_REPORT_DIR:-secrets-reports}"
SECRETS_FAIL_ON_FINDINGS="${SECRETS_FAIL_ON_FINDINGS:-true}"
SECRETS_SCAN_HISTORY="${SECRETS_SCAN_HISTORY:-true}"
GITLEAKS_VERSION="${GITLEAKS_VERSION:-8.21.2}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
log_warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

log_info "Running Gitleaks secret scanning..."
log_info "Detects API keys, tokens, passwords, and credentials in source code and Git history."

mkdir -p "$SECRETS_REPORT_DIR"

if ! command -v gitleaks >/dev/null 2>&1; then
  log_info "Installing Gitleaks v${GITLEAKS_VERSION}..."
  GITLEAKS_BIN_DIR="${RUNNER_TEMP:-/tmp}/gitleaks-bin"
  mkdir -p "$GITLEAKS_BIN_DIR"
  curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
    | tar xz -C "$GITLEAKS_BIN_DIR" gitleaks
  chmod +x "$GITLEAKS_BIN_DIR/gitleaks"
  echo "$GITLEAKS_BIN_DIR" >> "${GITHUB_PATH:-/dev/null}"
  export PATH="$GITLEAKS_BIN_DIR:$PATH"
fi

GITLEAKS_ARGS=(detect --source . --verbose --log-level info)

if [ "$SECRETS_SCAN_HISTORY" = "false" ]; then
  GITLEAKS_ARGS+=(--no-git)
  log_info "Scanning working tree only (--no-git)."
else
  log_info "Scanning full Git history. Ensure checkout uses fetch-depth: 0 for complete results."
fi

set +e
gitleaks "${GITLEAKS_ARGS[@]}" \
  --report-format json \
  --report-path "$SECRETS_REPORT_DIR/gitleaks.json"
GITLEAKS_EXIT=$?

gitleaks "${GITLEAKS_ARGS[@]}" \
  --report-format sarif \
  --report-path "$SECRETS_REPORT_DIR/gitleaks.sarif" \
  --log-level warn >/dev/null 2>&1
set -e

FINDING_COUNT=0
if [ -f "$SECRETS_REPORT_DIR/gitleaks.json" ]; then
  FINDING_COUNT=$(python3 - <<PY
import json
with open("$SECRETS_REPORT_DIR/gitleaks.json", encoding="utf-8") as handle:
    data = json.load(handle)
print(len(data) if isinstance(data, list) else 0)
PY
)
fi

log_info "Gitleaks findings detected: $FINDING_COUNT"
log_info "Reports written to: $SECRETS_REPORT_DIR/"

if [ "$FINDING_COUNT" -gt 0 ]; then
  if [ "$SECRETS_FAIL_ON_FINDINGS" = "true" ]; then
    log_error "Gitleaks found $FINDING_COUNT secret(s). Remove exposed credentials and rotate affected keys."
  else
    log_warning "Gitleaks found $FINDING_COUNT secret(s), but secrets-fail-on-findings is disabled."
  fi
else
  log_success "Gitleaks secret scan completed with no exposed secrets found."
fi

if [ "$GITLEAKS_EXIT" -ne 0 ] && [ "$FINDING_COUNT" -eq 0 ]; then
  log_error "Gitleaks scan failed to run. Check installation and repository checkout."
fi
