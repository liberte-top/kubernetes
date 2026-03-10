# Kubernetes AGENTS Guide

## Document Index
- `AGENTS.md`: kubernetes collaboration and execution conventions.

## Current Flow
- This repository now deploys the live `service.auth` stack.
- Default apply includes both `manifests/core` and `manifests/service`.
- `service/auth` is the current deployable workload baseline.
- Use `scripts/kubectl.sh` for remote cluster operations via SSH tunnel reuse.

## 60-Second Local Start
- Copy `.env.example` to `.env` and fill in the SSH host, user, local base64 private key, and kubeconfig path.
- Validate direct connectivity with `./scripts/ssh.sh`.
- Validate tunnel setup with `./scripts/kubectl.sh tunnel status` or `./scripts/kubectl.sh tunnel restart`.
- Inspect cluster access with `./scripts/kubectl.sh get nodes -o wide`.
- Apply and verify the current baseline with `./scripts/kubectl.sh apply -k manifests`.

## Single Source of Truth
- Runtime parameters live in `.env`.
- Execution entry is `scripts/kubectl.sh`.
- Kubernetes desired state lives in `manifests/`.

## Repository Structure (Refactor Map)
Use this as the baseline module map before iterative refactor.

```text
kubernetes/
├── .github/workflows/        # CI entrypoints
├── manifests/                # Kubernetes desired state
│   ├── kustomization.yaml
│   ├── core/
│   ├── argocd/
│   └── service/
│       ├── namespace.yaml
│       └── auth/
│           ├── api/
│           ├── web/
│           └── ingress.yaml
├── scripts/                  # Operational entrypoints and local tooling
│   ├── kubectl.sh            # Single kubectl runtime wrapper (SSH tunnel reuse)
│   ├── ssh.sh                # Direct SSH connectivity helper
│   └── utils.sh              # Shared shell helpers for scripts
├── .env(.example)            # Runtime parameters
└── AGENTS.md                 # Collaboration and execution conventions
```

## Runtime Parameters
- `INFRA_SSH_HOST`: target host/IP for SSH.
- `INFRA_SSH_USER`: SSH user for target host.
- `INFRA_SSH_PRIVATE_KEY_B64` (required): base64-encoded private key, decoded at runtime.
- `INFRA_SSH_KNOWN_HOSTS` (CI only): exact `known_hosts` line for `INFRA_SSH_HOST`, used by workflow SSH with strict host key checking.
- `INFRA_KUBECONFIG_PATH` (required by `scripts/kubectl.sh`): remote kubeconfig path copied to a temp file for each kubectl invocation.
- `INFRA_KUBECTL_TUNNEL_LOCAL_PORT` (optional, default `56443`): fixed local loopback port forwarded to remote apiserver `127.0.0.1:6443`.
- `INFRA_SSH_CONTROL_PERSIST_SECONDS` (optional, default `600`): SSH control connection idle keepalive seconds.
- `INFRA_SSH_CONTROL_SOCKET` (optional): explicit SSH ControlPath socket file.

## Execution Entry
- Always run kubectl through `scripts/kubectl.sh`.
- Behavior:
  - No arguments: execute `kubectl get nodes --request-timeout=15s`.
  - With arguments: pass through directly to kubectl.
  - `tunnel` subcommand supports `status|start|stop|restart`.

## Common Commands
- `./scripts/kubectl.sh tunnel status`
- `./scripts/kubectl.sh tunnel restart`
- `./scripts/ssh.sh`
- `./scripts/ssh.sh uname -a`
- `./scripts/kubectl.sh`
- `./scripts/kubectl.sh get nodes -o wide`
- `./scripts/kubectl.sh apply -k manifests`
- `./scripts/kubectl.sh -n service get deploy,svc,ingress,pod`
- `./scripts/kubectl.sh -n core get statefulset,svc,secret`

## Kubectl Tunnel Workflow
- `scripts/kubectl.sh` uses SSH `ControlMaster/ControlPersist` tunnel reuse with fixed local port.
- Tunnel start is lazy and lock-protected to avoid concurrent bootstrap races.
- Each invocation still copies remote kubeconfig from `INFRA_KUBECONFIG_PATH` to a temporary local file before running kubectl with `--server` + `--kubeconfig`.

## Minimal Baseline Regression Checklist
- `./scripts/kubectl.sh tunnel status`
- `./scripts/kubectl.sh get nodes --request-timeout=15s`
- `./scripts/kubectl.sh apply -k manifests`
- `./scripts/kubectl.sh apply -k manifests` (idempotency pass)
- `./scripts/kubectl.sh -n core get statefulset,svc,secret`
- `./scripts/kubectl.sh -n service get deploy,svc,ingress,pod`

## CI Apply Strategy
- Keep `.github/workflows/ci.apply.yml` simple: SSH setup, upload `manifests/` to remote temp dir, dry-run apply, apply, rollout verify, cleanup.
- ArgoCD is now the active reconciler for `core` and `service`.
- Avoid coupling CI to local helper scripts unless the workflow itself needs script-specific behavior.
- Use `REMOTE_TMPDIR=/tmp/liberte-k8s-${GITHUB_SHA}` as release workspace and always clean it via shell `trap`.
- Require `INFRA_SSH_KNOWN_HOSTS` in CI and fail fast if host identity is missing.
- Create runtime Kubernetes secrets from CI secrets before applying manifests.
- Keep `auth-api` / `auth-web` image SHAs explicit in git.
- Use `.github/workflows/ci.promote-service-auth.yml` to advance those image tags to the latest successful `service.auth` builds.
- `ci.apply` now validates `core` / `service`, applies ArgoCD project/applications, refreshes them, and waits for `Synced Healthy`.
- Run a public smoke check against `https://auth.liberte.top` after rollout completes.

## Change Policy
- Keep `scripts/kubectl.sh` as the single operational entrypoint.
- Keep service layer deployable at all times, even during refactor.
- If service modules are reintroduced, keep kustomization composition explicit and reviewable.
- Keep `manifests/argocd` as prepared GitOps resources until ArgoCD becomes the active reconciler.

## Troubleshooting
- Missing `.env`: copy from `.env.example` and fill in SSH settings before running helper scripts.
- SSH works in CI but not locally: confirm local `.env` uses `INFRA_SSH_PRIVATE_KEY_B64`, not raw private key text.
- Tunnel is stopped: rerun `./scripts/kubectl.sh tunnel restart` and then retry the kubectl command.
- CI host key verification failure: refresh `INFRA_SSH_KNOWN_HOSTS` from a trusted local `known_hosts` entry for `INFRA_SSH_HOST`.
