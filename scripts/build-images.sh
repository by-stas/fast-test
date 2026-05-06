#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_TAG="${IMAGE_TAG:-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
REGISTRY="${REGISTRY:-ghcr.io/your-org}"

BACKEND_IMAGE="${BACKEND_IMAGE:-$REGISTRY/kerberos-webapp-api:$IMAGE_TAG}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-$REGISTRY/kerberos-webapp-ui:$IMAGE_TAG}"
PUSH_IMAGES="${PUSH_IMAGES:-false}"

docker build \
  -f "$REPO_ROOT/src/backend/KerberosWebApp.Api/Dockerfile" \
  -t "$BACKEND_IMAGE" \
  "$REPO_ROOT"

docker build \
  -f "$REPO_ROOT/src/frontend/Dockerfile" \
  -t "$FRONTEND_IMAGE" \
  "$REPO_ROOT"

if [[ "$PUSH_IMAGES" == "true" ]]; then
  docker push "$BACKEND_IMAGE"
  docker push "$FRONTEND_IMAGE"
fi

cat <<EOF
Built images:
  BACKEND_IMAGE=$BACKEND_IMAGE
  FRONTEND_IMAGE=$FRONTEND_IMAGE

Use these values with scripts/deploy.sh.
EOF
