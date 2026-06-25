#!/bin/bash

# Writes a SAST report summary to the GitHub Actions job summary page.
set -e

SAST_REPORT_DIR="${SAST_REPORT_DIR:-sast-reports}"
JSON_REPORT="$SAST_REPORT_DIR/semgrep.json"

if [ -z "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "GITHUB_STEP_SUMMARY is not set; skipping job summary."
  exit 0
fi

if [ ! -f "$JSON_REPORT" ]; then
  {
    echo "## SAST Static Code Analysis"
    echo
    echo "No Semgrep JSON report found at \`$JSON_REPORT\`."
  } >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

python3 - "$JSON_REPORT" "$SAST_REPORT_DIR" >> "$GITHUB_STEP_SUMMARY" <<'PY'
import json
import sys
from collections import Counter

json_path, report_dir = sys.argv[1], sys.argv[2]

with open(json_path, encoding="utf-8") as handle:
    data = json.load(handle)

results = data.get("results", [])
counts = Counter(item.get("extra", {}).get("severity", "UNKNOWN") for item in results)

print("## SAST Static Code Analysis (Semgrep)")
print()
print("| Severity | Count |")
print("| --- | ---: |")
for severity in ("ERROR", "WARNING", "INFO", "UNKNOWN"):
    if counts.get(severity, 0):
        print(f"| {severity} | {counts[severity]} |")
print(f"| **Total** | **{len(results)}** |")
print()
print("Semgrep checks for syntax issues, security vulnerabilities, programming errors, coding standard violations, and undefined-value patterns.")
print()

if not results:
    print("No findings detected.")
else:
    print("### Top findings")
    print()
    print("| Severity | Rule | File | Line | Message |")
    print("| --- | --- | --- | ---: | --- |")
    for item in results[:25]:
        extra = item.get("extra", {})
        path = item.get("path", "unknown")
        line = item.get("start", {}).get("line", "-")
        severity = extra.get("severity", "UNKNOWN")
        rule = extra.get("metadata", {}).get("shortid") or extra.get("check_id", "unknown")
        message = extra.get("message", "").replace("|", "\\|").replace("\n", " ")
        if len(message) > 120:
            message = message[:117] + "..."
        print(f"| {severity} | `{rule}` | `{path}` | {line} | {message} |")

    if len(results) > 25:
        print()
        print(f"_Showing 25 of {len(results)} findings. Download the full report from workflow artifacts._")

print()
print("### Report files")
print()
print(f"- SARIF: `{report_dir}/semgrep.sarif` (GitHub Security tab when SARIF upload is enabled)")
print(f"- JSON: `{report_dir}/semgrep.json`")
print(f"- Text: `{report_dir}/semgrep.txt`")
PY
