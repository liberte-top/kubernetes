# BOOTSTRAP.md

This document captures cold-start steps and ongoing deploy mechanics for the
liberte.top Kubernetes stack (now fully Helm-based).

## Assumptions
- Target host is Debian 12 (bookworm) with root access.
- Ports 80/443 are open.
- Domain `*.liberte.top` points to the server public IP.
- TLS is handled by cert-manager via ingress-nginx.
- The deploy user is `deployer` with SSH access.

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

## Firewall (ufw)
UFW is optional. If enabled, allow only required public ports.

Enable forwarding for k3s:
```sh
sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
```

Baseline rules:
```sh
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
```

Enable:
```sh
ufw enable
ufw status verbose
```

## Ingress + TLS
Install ingress-nginx and cert-manager:
```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
kubectl -n cert-manager rollout status deploy/cert-manager --timeout=180s
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=180s
```

Ensure the ingress controller Service is a LoadBalancer (ServiceLB binds to node IP):
```sh
kubectl -n ingress-nginx patch svc ingress-nginx-controller -p '{"spec":{"type":"LoadBalancer"}}'
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
```

## Create Deploy User
```sh
id -u deployer >/dev/null 2>&1 || useradd -m -s /bin/bash deployer
install -d -m 700 -o deployer -g deployer /home/deployer/.ssh
install -d -m 700 -o deployer -g deployer /home/deployer/.kube
```

## Kubeconfig for Deploy User (admin)
The `apply` workflow needs admin kubeconfig at:
- `/home/deployer/.kube/admin.config`

On k3s, copy the admin config:
```sh
install -m 600 -o deployer -g deployer /etc/rancher/k3s/k3s.yaml /home/deployer/.kube/admin.config
```

## SSH Key for GitHub Actions
- Generate a keypair locally and add public key to `/home/deployer/.ssh/authorized_keys`.
- Example key path used in this repo:
  - private: `/home/fire/.ssh/liberte_gha_deploy`
  - public: `/home/fire/.ssh/liberte_gha_deploy.pub`

## GitHub Actions Secrets (Org)
These are required by `kubernetes/.github/workflows/ci.apply.yml`:
- `PROD_SSH_HOST` = server public IP
- `PROD_SSH_USER` = `deployer`
- `PROD_SSH_PRIVATE_KEY` = private key content
- `PROD_REDIS_PASSWORD` = Redis password

## Helm + Apply Flow
`ci.apply` performs all deployment steps and is the single entry point for cluster sync:
1) Upload manifests (`kubernetes/`)
2) Install Helm (if missing)
3) Helm releases (order matters):
   - `bootstrap` (namespaces)
   - create secrets (`redis-auth`, `clash-redis`)
   - `core` (cluster-issuer + RBAC + default SA)
   - `auth`, `middleware`, `clash`
4) Rollout checks for auth/clash and redis

## Manual Helm (Server)
If you need to run manually on the server:
```sh
cd /home/deployer/kubernetes
/home/deployer/.local/bin/helm upgrade --install bootstrap ./charts/bootstrap -n default -f ./charts/bootstrap/values.yaml --atomic --timeout 120s
/home/deployer/.local/bin/helm upgrade --install core ./charts/core -n services -f ./charts/core/values.yaml --atomic --timeout 120s
/home/deployer/.local/bin/helm upgrade --install auth ./charts/auth -n services -f ./charts/auth/values.yaml -f ./charts/auth/values-prod.yaml --atomic --timeout 120s
/home/deployer/.local/bin/helm upgrade --install middleware ./charts/middleware -n middleware -f ./charts/middleware/values.yaml -f ./charts/middleware/values-prod.yaml --atomic --timeout 120s
/home/deployer/.local/bin/helm upgrade --install clash ./charts/clash -n services -f ./charts/clash/values.yaml -f ./charts/clash/values-prod.yaml --atomic --timeout 120s
```

## Redis Secrets
`ci.apply` auto-creates:
- `middleware/redis-auth` (REDIS_PASSWORD)
- `services/clash-redis` (REDIS_PASSWORD)

## Smoke Tests
```sh
curl -k https://auth.liberte.top
curl -k https://clash.liberte.top
```

## Notes
- `ClusterIssuer` is managed by Helm `core` release.
- Namespaces are managed by Helm `bootstrap` release.
- If `ci.apply` fails before Helm, verify SSH + kubeconfig on server.
