#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NAMESPACE="${NAMESPACE:-kerberos-webapp}"
APP_HOST="${APP_HOST:-app.example.com}"
TLS_SECRET_NAME="${TLS_SECRET_NAME:-kerberos-webapp-tls}"
INGRESS_CLASS_NAME="${INGRESS_CLASS_NAME:-nginx}"
BACKEND_IMAGE="${BACKEND_IMAGE:-ghcr.io/example/kerberos-webapp-api:latest}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-ghcr.io/example/kerberos-webapp-ui:latest}"

GENERATED_DIR="$REPO_ROOT/deploy/k8s/generated/runtime"
mkdir -p "$GENERATED_DIR"

cat > "$GENERATED_DIR/kustomization.yaml" <<EOF
resources:
  - ../..

namespace: $NAMESPACE

images:
  - name: ghcr.io/example/kerberos-webapp-api
    newName: ${BACKEND_IMAGE%:*}
    newTag: ${BACKEND_IMAGE##*:}
  - name: ghcr.io/example/kerberos-webapp-ui
    newName: ${FRONTEND_IMAGE%:*}
    newTag: ${FRONTEND_IMAGE##*:}

patches:
  - target:
      kind: Namespace
      name: kerberos-webapp
    patch: |-
      - op: replace
        path: /metadata/name
        value: $NAMESPACE
  - target:
      kind: Ingress
      name: kerberos-webapp
    patch: |-
      - op: replace
        path: /spec/ingressClassName
        value: $INGRESS_CLASS_NAME
      - op: replace
        path: /spec/rules/0/host
        value: $APP_HOST
      - op: replace
        path: /spec/tls/0/hosts/0
        value: $APP_HOST
      - op: replace
        path: /spec/tls/0/secretName
        value: $TLS_SECRET_NAME
EOF

kubectl apply -k "$GENERATED_DIR"
kubectl -n "$NAMESPACE" rollout status deployment/kerberos-webapp-api
kubectl -n "$NAMESPACE" rollout status deployment/kerberos-webapp-ui

cat <<EOF
Deployment complete.

Namespace: $NAMESPACE
Host:      https://$APP_HOST

Confirm the following before testing Kerberos in a browser:
  1. DNS for $APP_HOST resolves to the ingress controller.
  2. TLS secret $TLS_SECRET_NAME exists in namespace $NAMESPACE.
  3. Secret kerberos-webapp-keytab exists and contains app.keytab.
  4. deploy/k8s/krb5-configmap.yaml has been updated for your AD realm/KDCs.
EOF
