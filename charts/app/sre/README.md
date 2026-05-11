# app-sre

Helm chart for `service.sre` — the platform SRE control surface served at `sre.liberte.top`.

Hosts a SQL admin panel and (future) operator runbooks. Stateless: no schema, no migrations. Connects to other services' databases by DSN supplied through Sealed Secrets.

## Conventions

- Container runtime parameters arrive via env (`SRE_*` prefix). Database DSNs come from `sre-api-env` SealedSecret (one key per target, e.g. `DATABASE_URL_AUTH`).
- Forward-auth: the `sre-forward-auth` Middleware delegates session checks to `service-auth/internal/auth/session/check`. The `sre:admin` scope is required (registered in `service.auth` `route_policies` seed).
- No build-time `@liberte/*` npm pull. The web image installs only public npm packages.
