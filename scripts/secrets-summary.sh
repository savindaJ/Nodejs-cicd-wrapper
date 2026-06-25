#!/bin/bash

# Writes Gitleaks secret scan results to the GitHub Actions job summary page.
set -e

SECRETS_REPORT_DIR="${SECRETS_REPORT_DIR:-secrets-reports}"
JSON_REPORT="$SECRETS_REPORT_DIR/gitleaks.json"

if [ -z "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "GITHUB_STEP_SUMMARY is not set; skipping job summary."
  exit 0
fi

if [ ! -f "$JSON_REPORT" ]; then
  {
    echo "## Secret Scanning (Gitleaks)"
    echo
    echo "No Gitleaks JSON report found at \`$JSON_REPORT\`."
  } >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

python3 - "$JSON_REPORT" "$SECRETS_REPORT_DIR" >> "$GITHUB_STEP_SUMMARY" <<'PY'
import json
import sys
from collections import Counter

json_path, report_dir = sys.argv[1], sys.argv[2]

with open(json_path, encoding="utf-8") as handle:
    findings = json.load(handle)

if not isinstance(findings, list):
    findings = []

rule_counts = Counter(item.get("RuleID", "unknown") for item in findings)

print("## Secret Scanning (Gitleaks)")
print()
print("Gitleaks scans source code and Git history for hardcoded secrets such as API keys, tokens, passwords, and private keys.")
print()
print(f"**Total secrets found:** {len(findings)}")
print()

if rule_counts:
    print("| Rule | Count |")
    print("| --- | ---: |")
    for rule, count in rule_counts.most_common():
        print(f"| `{rule}` | {count} |")
    print()

if not findings:
    print("No secrets detected.")
else:
    print("### Detected secrets")
    print()
    print("| Rule | File | Line | Secret |")
    print("| --- | --- | ---: | --- |")
    for item in findings[:25]:
        rule = item.get("RuleID", "unknown").replace("|", "\\|")
        file_path = item.get("File", "-").replace("|", "\\|")
        line = item.get("StartLine", "-")
        secret = item.get("Secret", "redacted")
        if len(secret) > 8:
            secret = secret[:4] + "..." + secret[-2:]
        secret = secret.replace("|", "\\|")
        print(f"| `{rule}` | `{file_path}` | {line} | `{secret}` |")

    if len(findings) > 25:
        print()
        print(f"_Showing 25 of {len(findings)} findings. Download the full report from workflow artifacts._")

print()
print("### Report files")
print()
print(f"- JSON: `{report_dir}/gitleaks.json`")
print(f"- SARIF: `{report_dir}/gitleaks.sarif`")
PY
