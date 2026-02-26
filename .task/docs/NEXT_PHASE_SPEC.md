# kubernetes Next Phase Spec

## Goal
Prepare k8s manifests for auth api/web as independent deploy targets.

## Required Structure
- manifests/service/auth/api/
- manifests/service/auth/web/
- manifests/service/auth/kustomization.yaml

Each service directory is self-contained:
- api/{deployment.yaml,service.yaml,ingress.yaml,kustomization.yaml}
- web/{deployment.yaml,service.yaml,ingress.yaml,kustomization.yaml}

## Placeholder Workloads
- auth-api deployment/service:
  - deployment name: auth-api
  - container name: auth-api
  - placeholder image: nginx:1.27-alpine (or hashicorp/http-echo)
- auth-web deployment/service:
  - deployment name: auth-web
  - container name: auth-web
  - placeholder image: nginx:1.27-alpine

Namespace: service.

## Ingress
- Keep ingress yaml inside each service directory.
- Suggested host pattern:
  - auth-api.liberte.top -> service/auth-api
  - auth.liberte.top -> service/auth-web

## Coupling Contract with service.auth CI
- Deployment and container names are stable API:
  - deployment/auth-api container auth-api
  - deployment/auth-web container auth-web
- service.auth workflows will use kubectl set image against these names.

## Acceptance
- kubectl kustomize manifests renders successfully.
- apply -k manifests creates/updates auth-api/auth-web resources.
- rollout status succeeds for both deployments.
