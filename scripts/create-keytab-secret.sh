#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Create or update the Kubernetes Secret that stores the Kerberos keytab.

Required:
  KEYTAB_PATH=/path/to/app.keytab

Optional:
  NAMESPACE=kerberos-webapp
  SECRET_NAME=kerberos-webapp-keytab
  KEYTAB_KEY=app.keytab

Example:
  KEYTAB_PATH=./secrets/app.keytab ./scripts/create-keytab-secret.sh
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

NAMESPACE="${NAMESPACE:-kerberos-webapp}"
SECRET_NAME="${SECRET_NAME:-kerberos-webapp-keytab}"
KEYTAB_KEY="${KEYTAB_KEY:-app.keytab}"

if [[ -z "${KEYTAB_PATH:-}" ]]; then
  echo "KEYTAB_PATH is required." >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$KEYTAB_PATH" ]]; then
  echo "Keytab file not found: $KEYTAB_PATH" >&2
  exit 1
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NAMESPACE" create secret generic "$SECRET_NAME" \
  --from-file="${KEYTAB_KEY}=${KEYTAB_PATH}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret '$SECRET_NAME' has been applied in namespace '$NAMESPACE'."
