# `app-smoke`

Helm source for the `app.smoke` business-layer sample application.

## Stable Values Interface

- `namespace`
- `commonLabels`
- `podAnnotations`
- `app.name`
- `api.enabled`
- `api.replicaCount`
- `api.image.{repository,tag,pullPolicy}`
- `api.port`
- `api.service.port`
- `api.env`
- `api.readinessProbe`
- `api.livenessProbe`
- `api.resources`
- `web.enabled`
- `web.replicaCount`
- `web.image.{repository,tag,pullPolicy}`
- `web.port`
- `web.service.port`
- `web.readinessProbe`
- `web.livenessProbe`
- `web.resources`
- `middleware.enabled`
- `middleware.name`
- `middleware.address`
- `middleware.authResponseHeaders`
- `ingress.className`
- `ingress.host`
- `ingress.annotations`
- `ingress.tls.{enabled,secretName}`
- `ingress.protected.{enabled,middlewareRef}`
- `ingress.public.{enabled,path,pathType}`

These fields should remain backward-compatible unless the chart version is intentionally advanced with a migration.

## Evolving Areas

- component helper internals in `templates/_helpers.tpl`
- middleware and ingress composition if the app-layer shape broadens beyond `smoke`
- future rollout strategy knobs
- future public route expansion beyond health endpoints

These are still expected to evolve as the app-layer chart conventions settle.
