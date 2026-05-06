#!/usr/bin/env bash
set -euo pipefail

APP_HOST="${APP_HOST:-app.example.com}"
SCHEME="${SCHEME:-https}"

echo "Checking anonymous health endpoint..."
curl --fail --show-error --silent "${SCHEME}://${APP_HOST}/health/ready"
echo

echo "Checking authenticated API challenge..."
curl --include --silent --output /tmp/kerberos-webapp-me.txt --write-out "%{http_code}" \
  "${SCHEME}://${APP_HOST}/api/me" | {
    read -r status
    if [[ "$status" != "401" && "$status" != "200" ]]; then
      echo "Unexpected /api/me status: $status"
      sed -n '1,40p' /tmp/kerberos-webapp-me.txt
      exit 1
    fi

    echo "/api/me returned HTTP $status"
  }

echo "If testing from a domain-joined workstation, open ${SCHEME}://${APP_HOST} in a browser configured for Integrated Authentication."
