# Kubernetes AGENTS Guide

## Document Index
- `AGENTS.md`: kubernetes collaboration and execution conventions.
- `ROADMAP.md`: long-term improvement guide for cluster access, GitOps, secrets, and operational cleanup.

## Current Flow
- This repository now deploys the live `service.auth` stack.
- Default Kustomize apply includes `manifests/system`, `manifests/core`, and declarative service secrets.
- `service/auth`, `app/smoke`, `app/registry`, and `service/packages` are deployed by ArgoCD from Helm sources.
- Use `scripts/kubectl.sh` for remote cluster operations via SSH tunnel reuse.

## 60-Second Local Start
- Copy `.env.example` to `.env` and fill in the SSH host, user, local base64 private key, and kubeconfig path.
- Validate direct connectivity with `./scripts/ssh.sh`.
- Validate tunnel setup with `./scripts/kubectl.sh tunnel status` or `./scripts/kubectl.sh tunnel restart`.
- Inspect cluster access with `./scripts/kubectl.sh get nodes -o wide`.
- Render service-layer Helm output with `./scripts/render-helm.sh`.
- Validate the Kustomize baseline with `./scripts/kubectl.sh apply -k manifests --dry-run=server`.
- Seal runtime secrets with `./scripts/seal.sh`.

## Single Source of Truth
- Runtime parameters live in `.env`.
- Execution entry is `scripts/kubectl.sh`.
- Kubernetes desired state lives in `manifests/`, with Helm source for service/app layer workloads living in `charts/`.
- Helm-managed rendered manifests are generated locally with `scripts/render-helm.sh` and in CI temp workspaces; they are no longer committed to git.
- Runtime application secrets are represented by SealedSecrets in `manifests/*/secrets.yaml`; plaintext Secret manifests do not belong in git.

## Repository Structure (Refactor Map)
Use this as the baseline module map before iterative refactor.

```text
kubernetes/
├── .github/workflows/        # CI entrypoints
├── charts/                   # Helm source for service/app layer migrations
│   ├── service/
│   └── app/
├── certs/
│   └── seal.pem              # Public Sealed Secrets certificate
├── manifests/                # Kubernetes desired state
│   ├── kustomization.yaml
│   ├── system/
│   ├── core/
│   ├── argocd/
│   └── service/
│       ├── namespace.yaml
│       └── secrets.yaml      # SealedSecret resources
├── scripts/                  # Operational entrypoints and local tooling
│   ├── kubectl.sh            # Single kubectl runtime wrapper (SSH tunnel reuse)
│   ├── render-helm.sh        # Generates Helm-managed rendered manifests locally
│   ├── seal.sh               # Sealed Secrets helper CLI
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
- `./scripts/render-helm.sh`
- `./scripts/seal.sh cert`
- `./scripts/seal.sh service`
- `./scripts/seal.sh core`
- `./scripts/seal.sh check`
- `./scripts/ssh.sh`
- `./scripts/ssh.sh uname -a`
- `./scripts/kubectl.sh`
- `./scripts/kubectl.sh get nodes -o wide`
- `./scripts/kubectl.sh apply -k manifests --dry-run=server`
- `./scripts/kubectl.sh -n service get deploy,svc,ingress,pod`
- `./scripts/kubectl.sh -n core get statefulset,svc,secret`

## Secret Management
- Bitnami Sealed Secrets is the single declarative runtime secret path.
- The controller is a cluster-level system component in `kube-system`, declared at `manifests/system/sealed.yaml`.
- The public sealing certificate is committed at `certs/seal.pem`; it is not secret.
- The controller private-key Secret backup is operator-owned and must stay outside git. Do not commit files like `sealed-secrets-key*.yaml`.
- Encrypted secret placeholders live close to the workloads:
  - `manifests/core/secrets.yaml`: `postgres`
  - `manifests/service/secrets.yaml`: `auth-api-env`, `registry-admin-env`, `packages-verdaccio-env`, `packages-verdaccio-auth`, `packages-ghcr-pull`
- Use `scripts/seal.sh` as the only sealing entrypoint:
  - `./scripts/seal.sh cert`: refresh `certs/seal.pem` from the live controller key Secret.
  - `./scripts/seal.sh backup-key [dir]`: export the controller key Secret as raw YAML for operator backup.
  - `./scripts/seal.sh core`: reseal current live `core` Secrets into `manifests/core/secrets.yaml`.
  - `./scripts/seal.sh service`: reseal current live `service` Secrets into `manifests/service/secrets.yaml`.
  - `./scripts/seal.sh all`: reseal both groups.
  - `./scripts/seal.sh check`: verify the cert and SealedSecret manifests are renderable.
- When rotating a secret, update the live Kubernetes Secret through an explicit operator action, run the relevant `seal.sh` command, review the encrypted diff, and merge it through PR.
- Secret changes do not automatically restart all consumers. If a workload reads a Secret through env vars, restart the affected Deployment or make a pod-template change after the SealedSecret lands.
- Never print, log, paste, or commit secret values. Command output should show Secret names or key names only.

## Kubectl Tunnel Workflow
- `scripts/kubectl.sh` uses SSH `ControlMaster/ControlPersist` tunnel reuse with fixed local port.
- Tunnel start is lazy and lock-protected to avoid concurrent bootstrap races.
- Each invocation still copies remote kubeconfig from `INFRA_KUBECONFIG_PATH` to a temporary local file before running kubectl with `--server` + `--kubeconfig`.

## Minimal Baseline Regression Checklist
- `./scripts/kubectl.sh tunnel status`
- `./scripts/kubectl.sh get nodes --request-timeout=15s`
- `./scripts/render-helm.sh`
- `./scripts/seal.sh check`
- `./scripts/kubectl.sh apply -k manifests --dry-run=server`
- `./scripts/kubectl.sh -n core get statefulset,svc,secret`
- `./scripts/kubectl.sh -n service get deploy,svc,ingress,pod`

## CI Deploy Strategy
- `service.auth` workflows open image-promotion PRs into this repository.
- `service.auth` image promotion updates Helm values under `charts/service/auth/`.
- `app.smoke` image promotion updates Helm values under `charts/app/smoke/`.
- `app.registry` image promotion updates Helm values under `charts/app/registry/`.
- `packages` registry manifests live under `charts/service/packages/`; runtime secrets are represented as SealedSecrets in `manifests/service/secrets.yaml`.
- `kubernetes` owns merge policy and ArgoCD owns reconciliation.
- `.github/workflows/ci.verify.yml` renders Helm-managed manifests in CI, validates them, refreshes ArgoCD applications, waits for `Synced Healthy`, and runs public smoke checks.
- `system` owns cluster-level controllers such as Sealed Secrets in `kube-system`.
- `service` is expected to become `Synced Healthy`; `core` is required to stay `Healthy`.
- Avoid coupling CI to local helper scripts unless the workflow itself needs script-specific behavior.
- Use `REMOTE_TMPDIR=/tmp/liberte-k8s-${GITHUB_SHA}` as release workspace and always clean it via shell `trap`.
- Require `INFRA_SSH_KNOWN_HOSTS` in CI and fail fast if host identity is missing.
- Do not create application runtime secrets from CI; update SealedSecrets through `scripts/seal.sh`.
- Keep `auth-api` / `auth-web` image SHAs explicit in git.
- `ci.verify` does not set images or perform imperative deploys.
- Run a public smoke check against `https://auth.liberte.top` after rollout completes.

## Change Policy
- Keep `scripts/kubectl.sh` as the single operational entrypoint.
- Keep service layer deployable at all times, even during refactor.
- If service modules are reintroduced, keep kustomization composition explicit and reviewable.
- Keep `manifests/argocd` as prepared GitOps resources until ArgoCD becomes the active reconciler.
- For the current experiment, runtime data may be reset or discarded freely when needed for auth flow validation or recovery.
- Even in that experimental mode, release integrity still matters: do not bypass the normal CI/image-promotion path with manual one-off image publishing or cluster-only hotfixes unless explicitly directed.

## Troubleshooting
- Missing `.env`: copy from `.env.example` and fill in SSH settings before running helper scripts.
- SSH works in CI but not locally: confirm local `.env` uses `INFRA_SSH_PRIVATE_KEY_B64`, not raw private key text.
- Tunnel is stopped: rerun `./scripts/kubectl.sh tunnel restart` and then retry the kubectl command.
- CI host key verification failure: refresh `INFRA_SSH_KNOWN_HOSTS` from a trusted local `known_hosts` entry for `INFRA_SSH_HOST`.
