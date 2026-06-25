#!/bin/bash

# Writes OWASP ZAP DAST results to the GitHub Actions job summary page.
set -e

DAST_REPORT_DIR="${DAST_REPORT_DIR:-dast-reports}"
JSON_REPORT="$DAST_REPORT_DIR/report_json.json"

if [ -z "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "GITHUB_STEP_SUMMARY is not set; skipping job summary."
  exit 0
fi

if [ ! -f "$JSON_REPORT" ]; then
  {
    echo "## DAST Dynamic Application Security Testing (OWASP ZAP)"
    echo
    echo "No ZAP JSON report found at \`$JSON_REPORT\`."
  } >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

python3 - "$JSON_REPORT" "$DAST_REPORT_DIR" >> "$GITHUB_STEP_SUMMARY" <<'PY'
import json
import sys
from collections import Counter

json_path, report_dir = sys.argv[1], sys.argv[2]

with open(json_path, encoding="utf-8") as handle:
    data = json.load(handle)

alerts = []
for site in data.get("site", []):
    alerts.extend(site.get("alerts", []))

risk_labels = {
    "3": "HIGH",
    "2": "MEDIUM",
    "1": "LOW",
    "0": "INFORMATIONAL",
}

counts = Counter(risk_labels.get(str(item.get("riskcode", "")), "UNKNOWN") for item in alerts)

print("## DAST Dynamic Application Security Testing (OWASP ZAP)")
print()
print("OWASP ZAP performs dynamic scanning against a running application to detect runtime vulnerabilities such as XSS, misconfigurations, and exposed endpoints.")
print()
print("| Risk | Count |")
print("| --- | ---: |")
for risk in ("HIGH", "MEDIUM", "LOW", "INFORMATIONAL", "UNKNOWN"):
    if counts.get(risk, 0):
        print(f"| {risk} | {counts[risk]} |")
print(f"| **Total** | **{len(alerts)}** |")
print()

if not alerts:
    print("No alerts detected.")
else:
    print("### Top alerts")
    print()
    print("| Risk | Alert | URL | Parameter |")
    print("| --- | --- | --- | --- |")
    for item in alerts[:25]:
        risk = risk_labels.get(str(item.get("riskcode", "")), "UNKNOWN")
        name = item.get("alert", "unknown").replace("|", "\\|")
        url = item.get("url", "-").replace("|", "\\|")
        if len(url) > 80:
            url = url[:77] + "..."
        param = item.get("param", "-").replace("|", "\\|")
        print(f"| {risk} | {name} | `{url}` | {param} |")

    if len(alerts) > 25:
        print()
        print(f"_Showing 25 of {len(alerts)} alerts. Download the full HTML/JSON report from workflow artifacts._")

print()
print("### Report files")
print()
print(f"- HTML: `{report_dir}/report_html.html`")
print(f"- JSON: `{report_dir}/report_json.json`")
print(f"- Markdown: `{report_dir}/report_md.md`")
PY
