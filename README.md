# Kerberos authenticated Angular + ASP.NET Core web application

This repository is a complete starter project for a simple web application that
uses Windows Integrated Authentication / Kerberos from a browser, with:

- Angular frontend
- ASP.NET Core C# backend
- Linux containers
- Kubernetes manifests
- Deployment scripts

The recommended production shape is one public HTTPS host:

```text
https://app.example.com/          -> Angular frontend
https://app.example.com/api/...   -> ASP.NET Core backend
https://app.example.com/health... -> ASP.NET Core health endpoints
```

The browser performs Kerberos/SPNEGO negotiation with the backend. Angular does
not implement Kerberos itself; it calls `/api/me` and renders the authenticated
identity returned by the API.

## Repository layout

```text
src/
  backend/KerberosWebApp.Api/   ASP.NET Core API with Negotiate auth
  frontend/                     Angular standalone frontend
deploy/
  k8s/                          Kubernetes base manifests
  local/                        Local Kerberos config example
scripts/
  build-images.sh               Build backend and frontend container images
  create-keytab-secret.sh       Create/update Kubernetes keytab Secret
  deploy.sh                     Deploy generated kustomize overlay
  smoke-test.sh                 Check health and auth challenge behavior
docker-compose.yml              Optional local container run
```

## How authentication works

```text
Browser
  -> GET /api/me
Backend
  -> 401 WWW-Authenticate: Negotiate
Browser
  -> requests Kerberos ticket for HTTP/app.example.com
  -> sends Authorization: Negotiate <token>
Backend
  -> validates token with mounted keytab
  -> returns authenticated user information
```

The Service Principal Name (SPN) must match the DNS name used by users in the
browser. If users open `https://app.example.com`, the SPN should be:

```text
HTTP/app.example.com@EXAMPLE.COM
```

## Prerequisites

Local development:

- .NET SDK 8
- Node.js 20+
- Docker or compatible container runtime
- kubectl with access to the target Kubernetes cluster

Infrastructure:

- Active Directory / Kerberos realm
- Domain-joined client machines for browser SSO
- Stable DNS name for the app, for example `app.example.com`
- TLS certificate/secret for the ingress host
- Kubernetes ingress controller, for example ingress-nginx
- Accurate time synchronization on clients, domain controllers, and cluster
  nodes

## Active Directory setup

Create a dedicated AD service account, for example:

```text
EXAMPLE\svc-kerberos-webapp
```

Register the SPN:

```powershell
setspn -S HTTP/app.example.com EXAMPLE\svc-kerberos-webapp
```

Generate a keytab for the service account. The exact command depends on your AD
policy and encryption requirements. A common Windows example is:

```powershell
ktpass `
  /princ HTTP/app.example.com@EXAMPLE.COM `
  /mapuser EXAMPLE\svc-kerberos-webapp `
  /crypto AES256-SHA1 `
  /ptype KRB5_NT_PRINCIPAL `
  /pass * `
  /out app.keytab
```

Store the generated `app.keytab` securely. Do not commit it to Git.

## Backend

The backend is in `src/backend/KerberosWebApp.Api`.

Important files:

- `Program.cs` configures ASP.NET Core Negotiate authentication.
- `/health/live` and `/health/ready` are anonymous Kubernetes probe endpoints.
- `/api/me` requires Kerberos and returns the current identity and claims.
- `Dockerfile` installs Kerberos/GSSAPI packages in the Linux runtime image.

Run locally without containers:

```bash
cd src/backend/KerberosWebApp.Api
dotnet restore
dotnet run
```

For real Kerberos validation on Linux, the process needs:

```bash
export KRB5_CONFIG=/etc/krb5.conf
export KRB5_KTNAME=/etc/security/keytabs/app.keytab
```

## Frontend

The frontend is in `src/frontend`.

Run locally:

```bash
cd src/frontend
npm install
npm start
```

The Angular dev server proxies `/api` to `http://localhost:8080` using
`proxy.conf.json`.

Build for production:

```bash
cd src/frontend
npm run build
```

## Container image build

Build both images:

```bash
REGISTRY=ghcr.io/your-org ./scripts/build-images.sh
```

Push as part of the build:

```bash
REGISTRY=ghcr.io/your-org PUSH_IMAGES=true ./scripts/build-images.sh
```

You can override image names directly:

```bash
BACKEND_IMAGE=registry.example.com/kerberos-webapp-api:1.0.0 \
FRONTEND_IMAGE=registry.example.com/kerberos-webapp-ui:1.0.0 \
PUSH_IMAGES=true \
./scripts/build-images.sh
```

## Optional local container run

Copy a real keytab into `deploy/local/app.keytab` and update
`deploy/local/krb5.conf` for your realm.

```bash
docker compose up --build
```

Open:

```text
http://localhost:8080
```

Browser Kerberos SSO generally requires the public hostname to match the SPN, so
local container runs are mainly useful for image wiring and health checks.

## Kubernetes configuration

Update `deploy/k8s/krb5-configmap.yaml`:

```text
EXAMPLE.COM       -> your Kerberos realm
dc01.example.com  -> your domain controller/KDC
example.com       -> your DNS suffix
```

Create the keytab Secret:

```bash
KEYTAB_PATH=/secure/path/app.keytab ./scripts/create-keytab-secret.sh
```

If using a custom namespace:

```bash
NAMESPACE=my-webapp \
KEYTAB_PATH=/secure/path/app.keytab \
./scripts/create-keytab-secret.sh
```

Create the TLS Secret expected by the ingress, for example:

```bash
kubectl -n kerberos-webapp create secret tls kerberos-webapp-tls \
  --cert=/path/to/tls.crt \
  --key=/path/to/tls.key
```

Deploy:

```bash
APP_HOST=app.example.com \
TLS_SECRET_NAME=kerberos-webapp-tls \
BACKEND_IMAGE=ghcr.io/your-org/kerberos-webapp-api:latest \
FRONTEND_IMAGE=ghcr.io/your-org/kerberos-webapp-ui:latest \
./scripts/deploy.sh
```

The deploy script generates an ignored kustomize overlay under
`deploy/k8s/generated/runtime` and applies it with `kubectl apply -k`.

## Smoke test

After deployment:

```bash
APP_HOST=app.example.com ./scripts/smoke-test.sh
```

Expected behavior:

- `/health/ready` returns HTTP 200 without authentication.
- `/api/me` returns either:
  - HTTP 401 with `WWW-Authenticate: Negotiate` when called without Kerberos, or
  - HTTP 200 when called from a configured domain-joined client/browser.

## Browser requirements

Kerberos SSO works only when:

- The client is joined to the domain.
- The user logged into the client has a valid domain session.
- The browser trusts the app host for Integrated Authentication.
- DNS host, TLS certificate, ingress host, and SPN all use the same name.
- The ingress preserves `Authorization: Negotiate` and
  `WWW-Authenticate: Negotiate` headers.

For Chrome/Edge on managed Windows devices, configure the site in the browser's
authentication allowlist. Firefox uses `network.negotiate-auth.trusted-uris`.

## Troubleshooting

Check SPN registration:

```powershell
setspn -Q HTTP/app.example.com
```

Check Kubernetes resources:

```bash
kubectl -n kerberos-webapp get pods,svc,ingress
kubectl -n kerberos-webapp logs deployment/kerberos-webapp-api
```

Common issues:

- **401 loop**: browser does not trust the host for Integrated Authentication,
  the SPN does not match the host, or the keytab was generated for a different
  principal.
- **KRB_AP_ERR_SKEW**: clocks differ too much between client, KDC, and server.
- **Server not found in Kerberos database**: missing or incorrect SPN.
- **Cannot decrypt ticket**: keytab does not match the AD service account
  password or encryption type.
- **Works by hostname but not IP**: Kerberos uses host-based SPNs; use DNS.

## Notes on delegation

This starter authenticates the user to the backend. If the backend must call
SQL Server, SMB shares, or another service as the signed-in user, you also need
Kerberos delegation/constrained delegation in Active Directory. Keep that out of
the first version unless it is explicitly required.
