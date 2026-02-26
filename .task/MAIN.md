# Task: kubernetes service/auth 占位与 ingress 拆分阶段初始化

- **Branch:** feat/k8s-auth-placeholders-and-ingress
- **Status:** Active
- **Last-Sync:** 2026-02-26 23:02:03 CST (on Perish)

## Phase Stack
- 2.1 service/auth api+web 占位落地（Completed)

## Timeline
- [2026-02-26 22:34:49 CST] INITIALIZED on Perish.
- [2026-02-26 22:34:49 CST] CONTEXT: kubernetes should prepare service/auth api+web placeholders and ingress split before service.auth CI deploy coupling.
- [2026-02-26 22:48:09 CST] EXECUTED: added manifests/service/auth/{api,web} self-contained resources and wired service kustomization.
- [2026-02-26 22:48:09 CST] VALIDATED: kubectl kustomize manifests + apply -k manifests + rollout status(auth-api/auth-web).
- [2026-02-26 22:53:26 CST] UPDATED: ingress routing switched to auth.liberte.top path-based split (/api -> auth-api, / -> auth-web).
- [2026-02-26 22:53:26 CST] VALIDATED: external HTTP checks confirm auth.liberte.top/ and auth.liberte.top/api return 200 from respective placeholders.
- [2026-02-26 22:58:07 CST] UPDATED: wired cert-manager issuance for auth.liberte.top via Certificate(auth-liberte-top) and shared TLS secret auth-liberte-top-tls.
- [2026-02-26 22:58:59 CST] VALIDATED: letsencrypt-prod/staging ClusterIssuer ready; certificate/auth-liberte-top Ready=True; strict HTTPS checks return 200 with CA-trusted chain.
- [2026-02-26 23:01:39 CST] UPDATED: extracted auth ingress to manifests/service/auth/ingress.yaml for centralized host/path/TLS maintenance.
- [2026-02-26 23:01:55 CST] VALIDATED: removed stale auth-api/auth-web ingress resources, kept single ingress/auth, and re-verified public HTTPS routes (/ and /api => 200).

## Global References
- **Docs:** .task/docs/NEXT_PHASE_SPEC.md
- **Scripts:** .github/workflows/ci.apply.yml

---
*Managed via .task Convention*
