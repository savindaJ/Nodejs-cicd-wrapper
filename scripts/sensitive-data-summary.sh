#!/bin/bash

# Writes sensitive-data / secrets SAST findings to the GitHub Actions job summary.
set -e

SAST_REPORT_DIR="${SAST_REPORT_DIR:-sast-reports}"
JSON_REPORT="$SAST_REPORT_DIR/sensitive-data.json"

if [ -z "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "GITHUB_STEP_SUMMARY is not set; skipping job summary."
  exit 0
fi

if [ ! -f "$JSON_REPORT" ]; then
  {
    echo "## Sensitive Data Scan"
    echo
    echo "No sensitive-data report found at \`$JSON_REPORT\`."
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

SECRET_KEYWORDS = (
    "secret", "password", "api-key", "apikey", "api_key", "token",
    "credential", "private-key", "private_key", "aws", "stripe",
    "hardcoded", "jwt", "database", "connection-string",
)

def is_secret_finding(item):
    check_id = item.get("check_id", "").lower()
    message = item.get("extra", {}).get("message", "").lower()
    combined = f"{check_id} {message}"
    return any(keyword in combined for keyword in SECRET_KEYWORDS) or "secrets" in check_id

findings = [item for item in results if is_secret_finding(item)]
if not findings:
    findings = results

counts = Counter(item.get("extra", {}).get("severity", "UNKNOWN") for item in findings)

print("## Sensitive Data Scan (Semgrep Secrets)")
print()
print("Detects hardcoded API keys, passwords, tokens, cloud credentials, and other sensitive values in source code.")
print()
print("| Severity | Count |")
print("| --- | ---: |")
for severity in ("ERROR", "WARNING", "INFO", "UNKNOWN"):
    if counts.get(severity, 0):
        print(f"| {severity} | {counts[severity]} |")
print(f"| **Total sensitive findings** | **{len(findings)}** |")
print()

if not findings:
    print("No hardcoded secrets or sensitive data detected.")
else:
    print("### Detected sensitive data")
    print()
    print("| Severity | Type | File | Line | Details |")
    print("| --- | --- | --- | ---: | --- |")
    for item in findings[:30]:
        extra = item.get("extra", {})
        path = item.get("path", "unknown")
        line = item.get("start", {}).get("line", "-")
        severity = extra.get("severity", "UNKNOWN")
        rule = extra.get("check_id", "unknown").split(".")[-1]
        message = extra.get("message", "").replace("|", "\\|").replace("\n", " ")
        if len(message) > 100:
            message = message[:97] + "..."
        print(f"| {severity} | `{rule}` | `{path}` | {line} | {message} |")

    if len(findings) > 30:
        print()
        print(f"_Showing 30 of {len(findings)} sensitive-data findings._")

print()
print("### Report files")
print()
print(f"- JSON: `{report_dir}/sensitive-data.json`")
print(f"- Text: `{report_dir}/sensitive-data.txt`")
print()
print("> **Action required:** Move secrets to GitHub Secrets, environment variables, or a vault. Never commit real credentials.")
PY
