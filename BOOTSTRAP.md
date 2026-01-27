# BOOTSTRAP.md

This document captures the cold-start steps for provisioning the server environment
required by this repository.

## Assumptions
- Target host is Debian 12 (bookworm) with root access.
- Ports 80/443 are open.
- Domain `*.liberte.top` points to the server public IP.
- TLS is handled by cert-manager via ingress-nginx.
- Redis is used for token storage (infra namespace).

## Base Packages
```sh
apt-get update
apt-get install -y git curl ca-certificates gnupg iptables ufw
```

## Install k3s (single node)
```sh
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable metrics-server" sh -
```

Verify:
```sh
systemctl is-active k3s
kubectl get nodes -o wide
```

Note: ServiceLB must be enabled for single-IP LoadBalancer usage.

## Firewall (ufw)
UFW is optional. If you enable it, keep forwarding enabled for k3s and allow only required public ports.

Enable forwarding for k3s:
```sh
sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
```

Baseline rules (lock down inbound, keep SSH/HTTP/HTTPS):
```sh
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
```

Optional: mosh (use a tight UDP range; replace <CIDR> to restrict by source):
```sh
ufw allow proto udp from <CIDR> to any port 60000:60020
```

Enable and verify:
```sh
ufw enable
ufw status verbose
```

Note: mosh requires an interactive TTY and working bidirectional UDP. In CI or other non-interactive shells, mosh may fail even if the server is configured correctly.

## Ingress (ingress-nginx + cert-manager)
Apply ingress-nginx, cert-manager, and app ingress:
```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
kubectl -n cert-manager rollout status deploy/cert-manager --timeout=180s
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=180s

kubectl apply -k kubernetes/ingress
```

Ensure the ingress controller Service is a LoadBalancer (ServiceLB will bind to the node IP):
```sh
kubectl -n ingress-nginx patch svc ingress-nginx-controller -p '{"spec":{"type":"LoadBalancer"}}'
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
```

## Kubernetes Namespace + RBAC
```sh
kubectl get ns app >/dev/null 2>&1 || kubectl create ns app
kubectl get ns infra >/dev/null 2>&1 || kubectl create ns infra

cat <<"EOF" | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gha-deployer
  namespace: app
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gha-deployer
  namespace: app
rules:
  - apiGroups: ["", "apps", "networking.k8s.io"]
    resources:
      - deployments
      - services
      - configmaps
      - secrets
      - pods
      - ingresses
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gha-deployer
  namespace: app
subjects:
  - kind: ServiceAccount
    name: gha-deployer
    namespace: app
roleRef:
  kind: Role
  name: gha-deployer
  apiGroup: rbac.authorization.k8s.io
EOF
```

## Redis (infra)
Create Redis auth secret (used by Redis deployment and clash app):
```sh
REDIS_PASSWORD="<set-strong-password>"
kubectl -n infra create secret generic redis-auth \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n app create secret generic clash-redis \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Kubeconfig for Deploy User (namespaced)
```sh
TOKEN=$(kubectl -n app create token gha-deployer --duration=8760h 2>/dev/null || kubectl -n app create token gha-deployer)
CA=$(grep "certificate-authority-data:" /etc/rancher/k3s/k3s.yaml | awk "{print \\$2}")
cat > /root/gha-kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: k3s
  cluster:
    certificate-authority-data: ${CA}
    server: https://127.0.0.1:6443
users:
- name: gha-deployer
  user:
    token: ${TOKEN}
contexts:
- name: app
  context:
    cluster: k3s
    user: gha-deployer
    namespace: app
current-context: app
EOF
chmod 600 /root/gha-kubeconfig
```

## Create Deploy User
```sh
id -u deployer >/dev/null 2>&1 || useradd -m -s /bin/bash deployer
install -d -m 700 -o deployer -g deployer /home/deployer/.ssh
install -d -m 700 -o deployer -g deployer /home/deployer/.kube
cp /root/gha-kubeconfig /home/deployer/.kube/config
chown deployer:deployer /home/deployer/.kube/config
chmod 600 /home/deployer/.kube/config
```

## Admin kubeconfig for CI (required for Namespace/RBAC apply)
```sh
install -m 600 -o deployer -g deployer /etc/rancher/k3s/k3s.yaml /home/deployer/.kube/admin.config
```

## SSH Key for GitHub Actions
- Generate a keypair locally and add public key to `/home/deployer/.ssh/authorized_keys`.
- Example key path used in this repo:
  - private: `/home/fire/.ssh/liberte_gha_deploy`
  - public: `/home/fire/.ssh/liberte_gha_deploy.pub`
### SSH Hardening (Recommended)
- Restrict the deploy key to `deployer` only; keep it separate from personal keys.
- Consider `from="<allowed-ip>"` restrictions in `authorized_keys` if runner IP is stable.
- Rotate the deploy key periodically and revoke old keys.
- Keep `AllowUsers deployer` and disable password auth on SSH daemon.

## GHCR Pull Secret
Create a PAT with `read:packages` and `write:packages` (for pushing), then:
```sh
cat > /root/ghcr_token
chmod 600 /root/ghcr_token

kubectl -n app delete secret ghcr-pull >/dev/null 2>&1 || true
kubectl -n app create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=PerishCode \
  --docker-password="$(cat /root/ghcr_token)" \
  --docker-email=PerishCode@users.noreply.github.com
```

## Deploy Manifest Sync
```sh
scp -i /path/to/private_key -o StrictHostKeyChecking=no -r kubernetes \
  deployer@<server>:/home/deployer/
```

## GitHub Actions Secrets (Repo)
- `SSH_HOST` = server public IP
- `SSH_USER` = `deployer`
- `SSH_PRIVATE_KEY` = private key content
- `GHCR_TOKEN` = PAT with `write:packages`

## Run Workflow
- `apply` (manual) to sync manifests + RBAC + registry secret
- `service` (manual) to build/push image and set deployment image

## Smoke Test
```sh
curl -k https://clash.liberte.top/healthz
```

## Clash Data Files
- Store rule providers at `services/clash-api/data/rule-providers/*.yml`.
- Store subscriptions at `services/clash-api/data/subscription/*.yml`.
- `TOKEN_TTL_SECONDS` controls token lifetime (default 600).
- `DATA_DIR` overrides data directory path (default `services/clash-api/data`).

## Encrypted Config (SOPS)
- `services/clash-api/data/proxies/*.yml` are encrypted with SOPS (age).
- Decrypt: `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops -d <file>`

## Notes
- Deployment uses `hostNetwork: true`, so set Deployment strategy to `Recreate` to avoid port conflicts.
- Ensure `/home/deployer/kubernetes` is owned by `deployer`, otherwise scp will fail:
  - `sudo chown -R deployer:deployer /home/deployer/kubernetes`
- Maintenance playbook lives in `MAINTENANCE.md` (manual or systemd-based cleanup).
