#!/bin/bash

# Stops the application started for DAST and collects ZAP report files.
set -e

DAST_REPORT_DIR="${DAST_REPORT_DIR:-dast-reports}"
DAST_START_COMMAND="${DAST_START_COMMAND:-}"

if [ -f /tmp/dast-app.pid ]; then
  kill "$(cat /tmp/dast-app.pid)" >/dev/null 2>&1 || true
  rm -f /tmp/dast-app.pid
fi

mkdir -p "$DAST_REPORT_DIR"

for file in report_html.html report_json.json report_md.md; do
  if [ -f "$file" ]; then
    mv "$file" "$DAST_REPORT_DIR/$file"
  fi
done

if [ -f "$DAST_REPORT_DIR/report_json.json" ]; then
  echo "DAST reports collected in $DAST_REPORT_DIR/"
else
  echo "Warning: ZAP report files were not found."
fi
