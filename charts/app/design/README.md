# `app-design`

Helm source for `app.design` — the public, stateless visual reference site for `@liberte/svelte-components` served at `design.liberte.top`.

The chart inherits the `app-smoke` shape (api + web + ingress) but disables the forward-auth middleware: `app.design` is intentionally public so anyone can browse the design system without an account.

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
- `middleware.enabled` (kept for shape-parity; defaults to false)
- `ingress.className`
- `ingress.host`
- `ingress.annotations`
- `ingress.tls.{enabled,secretName}`
- `ingress.protected.{enabled,middlewareRef}` (defaults to false; the entire site is public)
- `ingress.public.{enabled,path,pathType}` (the whole site is the public path)

These fields should remain backward-compatible unless the chart version is intentionally advanced with a migration.
