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
- `api.envSecretRefs`
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
`api.envSecretRefs` maps single existing Secret keys into explicit environment variables. The Cargo adapter uses it to read `KELLNR_SETUP__ADMIN_PWD` from `crates-kellnr-env` as `KELLNR_ADMIN_PASSWORD` without importing unrelated registry storage or database secrets into `app.registry`.
