#!/bin/bash
# Run sensitive-data scan locally (same rules as CI composite action).
set -e

TARGET="${1:-.}"
WRAPPER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES="$WRAPPER_ROOT/sast/rules/sensitive-data.yml"
REPORT_DIR="${SAST_REPORT_DIR:-sast-reports}"

mkdir -p "$REPORT_DIR"

if ! command -v semgrep >/dev/null 2>&1; then
  echo "Installing Semgrep..."
  python3 -m pip install --quiet semgrep
fi

echo "Scanning: $TARGET"
echo "Rules: p/secrets + $RULES"
echo

semgrep scan \
  --config=p/secrets \
  --config="$RULES" \
  --metrics=off \
  --exclude=node_modules --exclude=dist --exclude=build \
  --json --json-output="$REPORT_DIR/sensitive-data.json" \
  "$TARGET"

COUNT=$(python3 -c "import json; print(len(json.load(open('$REPORT_DIR/sensitive-data.json')).get('results',[])))")
echo
echo "Sensitive data findings: $COUNT"
echo "Report: $REPORT_DIR/sensitive-data.json"

if [ "$COUNT" -gt 0 ]; then
  python3 - <<PY
import json
for item in json.load(open("$REPORT_DIR/sensitive-data.json")).get("results", []):
    print(f"  - {item['path']}:{item['start']['line']} [{item['check_id']}] {item['extra'].get('message','')}")
PY
  exit 1
fi

echo "No sensitive data detected."
