# `service-auth`

Helm source for the `service.auth` middleware layer.

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
- `api.secretEnv`
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
- `ingress.className`
- `ingress.host`
- `ingress.annotations`
- `ingress.tls.{enabled,secretName}`

These fields should remain backward-compatible unless the chart version is intentionally advanced with a migration.

## Evolving Areas

- component helper internals in `templates/_helpers.tpl`
- future `resources` defaults
- future rollout strategy knobs
- optional split between public and internal auth ingress behavior

These are still expected to evolve as the service-layer chart conventions settle.
