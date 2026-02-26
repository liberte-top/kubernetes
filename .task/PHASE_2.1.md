# Phase: 2.1 - service/auth api+web 占位落地

## Objective
先在 kubernetes 仓库实现 service/auth api+web 的目录与部署配置拆分，使用基础镜像占位，并增加 ingress 规则，为后续 service.auth CI 镜像更新做准备。

## Exit Criteria
- [x] manifests/service/auth/{api,web} 自包含目录结构建立完成（每个服务包含 deployment/service/ingress/kustomization）。
- [x] api/web deployment 使用基础镜像占位并可 rollout；ingress 规则可路由到对应 service。

## Work Log
- [2026-02-26 22:34:49 CST] STARTED: Phase initialized for placeholder and ingress refactor.
- [2026-02-26 22:46:58 CST] IMPLEMENTED: created auth/api and auth/web resources with stable deployment/container names for CI contract.
- [2026-02-26 22:47:10 CST] INTEGRATED: updated manifests/service/kustomization.yaml to include auth module.
- [2026-02-26 22:47:16 CST] VERIFIED: kubectl kustomize manifests renders successfully.
- [2026-02-26 22:47:30 CST] VERIFIED: ./scripts/kubectl.sh apply -k manifests created auth-api/auth-web deployments, services, ingresses.
- [2026-02-26 22:47:50 CST] VERIFIED: rollout status succeeded for deployment/auth-web and deployment/auth-api.
- [2026-02-26 22:47:50 CST] NOTE: parallel rollout checks caused one transient tunnel lock conflict; sequential retry succeeded.
- [2026-02-26 22:52:45 CST] ADJUSTED: switched to same-host ingress path split and updated auth-api placeholder for /api path.
- [2026-02-26 22:53:20 CST] VERIFIED: auth.liberte.top/ -> auth-web (nginx) and auth.liberte.top/api -> auth-api (http-echo).
- [2026-02-26 22:57:58 CST] DIAGNOSED: HTTPS trust failure traced to missing ClusterIssuer apply path and missing TLS wiring in auth ingresses.
- [2026-02-26 22:58:07 CST] IMPLEMENTED: added manifests/service/auth/certificate.yaml + TLS sections in auth-api/auth-web ingress + root kustomization include for core/cluster-issuer.yaml.
- [2026-02-26 22:58:59 CST] VERIFIED: cert-manager issuance completed (certificate/auth-liberte-top Ready=True) and public HTTPS curl verification succeeds without -k.
- [2026-02-26 23:01:20 CST] REFACTORED: moved ingress ownership to manifests/service/auth/ingress.yaml and removed per-service ingress files/references.
- [2026-02-26 23:01:55 CST] CLEANED: deleted stale in-cluster ingress/auth-api and ingress/auth-web to avoid overlapping route match.
- [2026-02-26 23:02:00 CST] VERIFIED: only ingress/auth remains; HTTPS checks for auth.liberte.top/ and /api still return 200 with trusted cert chain.

## Technical Notes
- **Files Touched:** manifests/kustomization.yaml, manifests/service/auth/**, manifests/service/kustomization.yaml, .task/MAIN.md, .task/PHASE_2.1.md
- **New Dependencies:** none
- **Blockers:** none

---
*This phase will be popped/archived upon meeting exit criteria.*
