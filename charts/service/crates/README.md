# crates service chart

Deploys `mini-crates-api` as the private Cargo registry behind `crates.liberte.top`.

The chart intentionally keeps the first deployment narrow:

- S3-compatible object storage is required.
- PostgreSQL is required.
- crates.io proxying is disabled.
- runtime secrets are injected from SealedSecrets and mapped to the mini-crates API environment.

The current deployment reuses the existing `crates-kellnr-env` encrypted material for database, bootstrap token, token pepper, and S3 credentials. The chart maps those keys into the mini-crates API contract:

- `KELLNR_POSTGRESQL__USER`
- `KELLNR_POSTGRESQL__PWD`
- `KELLNR_SETUP__ADMIN_TOKEN`
- `KELLNR_REGISTRY__COOKIE_SIGNING_KEY`
- `KELLNR_S3__ENDPOINT`
- `KELLNR_S3__CRATES_BUCKET`
- `KELLNR_S3__ACCESS_KEY`
- `KELLNR_S3__SECRET_KEY`

Cargo clients should use an explicit registry entry:

```toml
[registries.liberte]
index = "sparse+https://crates.liberte.top/api/v1/crates/"
```

Release workflows should follow the `packages` model: `release-beta` and
`release-stable` remain strategy-compatible and only differ in channel/version
semantics.
