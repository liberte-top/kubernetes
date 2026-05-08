# packages

Deploys the scoped npm registry surface at `packages.liberte.top`.

The registry is backed by `mini-packages-api`. It supports scoped packages, bearer tokens, npm/pnpm publish/install, and dist-tags. It intentionally does not proxy npmjs.org.

Runtime secrets are intentionally not rendered by this chart. `packages-api-env` must provide:

- `DATABASE_URL`
- `BOOTSTRAP_ADMIN_TOKEN`
- `TOKEN_PEPPER`
- `S3_ENDPOINT`
- `S3_REGION`
- `S3_BUCKET`
- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`
