#!/bin/bash

# Exit immediately if any command fails
set -e

# Record the script start time
START_TIME=$(date +%s)

# ==========================================
# Colors and Logging Functions
# ==========================================
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
log_warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

# ==========================================
# Reusable Retry Function
# ==========================================
with_retry() {
    local max_attempts=$1
    local timeout=$2
    shift 2
    local attempt=1
    local exitCode=0

    while (( attempt <= max_attempts ))
    do
        "$@"
        exitCode=$?

        if [[ $exitCode == 0 ]]; then
            break
        fi

        log_warning "Command failed! Attempt $attempt of $max_attempts."
        
        if (( attempt < max_attempts )); then
            log_info "Retrying in $timeout seconds..."
            sleep $timeout
        fi
        
        ((attempt++))
    done

    if [[ $exitCode != 0 ]]; then
        log_error "Command failed after $max_attempts attempts: $*"
    fi

    return $exitCode
}

# ==========================================
# Parse Dynamic Arguments (Flags)
# ==========================================
SKIP_TESTS=false
SKIP_LINT=false
SKIP_SAST=false
SAST_REPORT_DIR="${SAST_REPORT_DIR:-sast-reports}"
SAST_FAIL_ON_FINDINGS="${SAST_FAIL_ON_FINDINGS:-false}"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-tests) SKIP_TESTS=true ;;
        --skip-lint) SKIP_LINT=true ;;
        --skip-sast) SKIP_SAST=true ;;
        *) log_warning "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

log_info "Starting Node.js CI/CD Pipeline Wrapper..."

# ==========================================
# Validate Environment Variables
# ==========================================
# Add any required variables here (e.g. NODE_ENV)
REQUIRED_VARS=("NODE_ENV")

log_info "Checking required environment variables..."
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        # Currently logged as a warning; use log_error instead to fail the script if required.
        log_warning "Environment variable '$var' is missing! Make sure it is set in GitHub Actions."
    fi
done

# ==========================================
# Pre-build: Validate Node and NPM
# ==========================================
log_info "Checking Environment Details:"
node -v || log_error "Node.js is not installed!"
npm -v || log_error "NPM is not installed!"

# ==========================================
# Step 1: Clean Install (with retry logic)
# ==========================================
log_info "Running 'npm ci' to install clean dependencies..."
with_retry 3 10 npm ci --include=dev
log_success "Dependencies installed successfully."

# ==========================================
# Step 2: Security Audit
# ==========================================
log_info "Running Security Audit..."
# Fail only when high or critical vulnerabilities are found
npm audit --audit-level=high || log_error "High/Critical security vulnerabilities found! Please fix them."
log_success "Security audit passed."

# ==========================================
# Step 3: SAST Static Code Analysis
# ==========================================
if [ "$SKIP_SAST" = true ]; then
    log_warning "Skipping SAST static analysis as requested by --skip-sast flag."
else
    log_info "Running SAST Static Code Analysis (Semgrep)..."
    log_info "Checks: security vulnerabilities, programming errors, coding standards, and unsafe patterns."

    mkdir -p "$SAST_REPORT_DIR"

    if ! command -v semgrep >/dev/null 2>&1; then
        log_info "Installing Semgrep..."
        python3 -m pip install --quiet semgrep
    fi

    # Explicit rule packs work with --metrics=off (--config=auto requires metrics enabled).
    SEMGREP_COMMON=(
        scan
        --config=p/default
        --config=p/javascript
        --config=p/typescript
        --config=p/nodejs
        --config=p/security-audit
        --metrics=off
        --exclude=node_modules
        --exclude=dist
        --exclude=build
        --exclude=.next
        --exclude=coverage
    )

    set +e
    semgrep "${SEMGREP_COMMON[@]}" --json --json-output="$SAST_REPORT_DIR/semgrep.json" .
    SAST_EXIT=$?
    set -e

    # Semgrep allows only one output format per run (--json and --sarif are mutually exclusive).
    semgrep "${SEMGREP_COMMON[@]}" --sarif --output="$SAST_REPORT_DIR/semgrep.sarif" . >/dev/null 2>&1 || true
    semgrep "${SEMGREP_COMMON[@]}" --text --output="$SAST_REPORT_DIR/semgrep.txt" . >/dev/null 2>&1 || true

    if [ -f "$SAST_REPORT_DIR/semgrep.json" ]; then
        FINDING_COUNT=$(python3 - <<PY
import json
with open("$SAST_REPORT_DIR/semgrep.json", encoding="utf-8") as handle:
    print(len(json.load(handle).get("results", [])))
PY
)
        log_info "SAST findings detected: $FINDING_COUNT"
        log_info "Reports written to: $SAST_REPORT_DIR/"

        if [ "$SAST_FAIL_ON_FINDINGS" = "true" ] && [ "$FINDING_COUNT" -gt 0 ]; then
            log_error "SAST scan found $FINDING_COUNT issue(s). Review the report in the GitHub Actions summary or artifacts."
        fi
    else
        log_warning "SAST JSON report was not generated."
        if [ "$SAST_EXIT" -ne 0 ]; then
            log_error "SAST scan failed to run. Check Semgrep installation and logs above."
        fi
    fi

    log_success "SAST static analysis completed."
fi

# ==========================================
# Step 4: Code Linting
# ==========================================
if [ "$SKIP_LINT" = true ]; then
    log_warning "Skipping linting as requested by --skip-lint flag."
elif npm run | grep -q "lint"; then
    log_info "Running Code Linting..."
    npm run lint || log_error "Linting failed. Please fix code quality issues!"
    log_success "Linting passed."
else
    log_info "No 'lint' script found in package.json, skipping..."
fi

# ==========================================
# Step 5: Unit Testing
# ==========================================
if [ "$SKIP_TESTS" = true ]; then
    log_warning "Skipping tests as requested by --skip-tests flag."
elif npm run | grep -q "test"; then
    log_info "Running Unit Tests..."
    npm run test || log_error "Tests failed!"
    log_success "All tests passed successfully."
else
    log_info "No 'test' script found in package.json, skipping..."
fi

# ==========================================
# Step 6: Build Application
# ==========================================
log_info "Building the Node.js application..."
npm run build || log_error "Build process failed!"

# Verify the build output directory exists (.next, build, or dist for Next.js/React/Node)
if [ ! -d "build" ] && [ ! -d "dist" ] && [ ! -d ".next" ]; then
    log_error "Build directory (build/dist/.next) not found! The build might have failed silently."
fi
log_success "Build completed and verified successfully."

# ==========================================
# Calculate Execution Time
# ==========================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "---------------------------------------------------"
log_success "Pipeline Wrapper Script Executed Successfully!"
log_info "Total Execution Time: $DURATION seconds."
echo "---------------------------------------------------"