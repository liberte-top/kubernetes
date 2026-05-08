# `app-registry`

Helm source for the `app.registry` registry credential admin surface.

## Stable Values Interface

- `namespace`
- `commonLabels`
- `podAnnotations`
- `imagePullSecrets`
- `app.name`
- `api.enabled`
- `api.replicaCount`
- `api.image.{repository,tag,pullPolicy}`
- `api.port`
- `api.service.port`
- `api.env`
- `api.envFromSecrets`
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

`registry-admin-env` may provide `VERDACCIO_USERNAME` and `VERDACCIO_PASSWORD`; the Secret is optional so the UI can deploy before the npm issuer is bootstrapped.
