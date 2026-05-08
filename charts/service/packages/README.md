# packages

Deploys the public npm registry surface at `packages.liberte.top`.

The first storage backend is self-hosted MinIO so the full public delivery path can be validated before switching the same S3-compatible configuration to Cloudflare R2.

Runtime secrets are intentionally not rendered by this chart:

- `packages-minio-env`: `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`
- `packages-verdaccio-env`: `VERDACCIO_S3_BUCKET`, `VERDACCIO_S3_KEY_PREFIX`, `VERDACCIO_S3_REGION`, `VERDACCIO_S3_ENDPOINT`, `VERDACCIO_S3_ACCESS_KEY_ID`, `VERDACCIO_S3_SECRET_ACCESS_KEY`
- `packages-verdaccio-auth`: `htpasswd`

The Verdaccio image intentionally pins `verdaccio@5.33.0` with `verdaccio-aws-s3-storage@10.4.0`; newer plugin lines have changed storage semantics and may require DynamoDB.

For external S3-compatible storage such as Cloudflare R2, set `minio.enabled=false`,
`verdaccio.s3.envFromSecret=true`, and `verdaccio.s3.ensureBucket=false`. The bucket,
endpoint, region, key prefix, and credentials then come from `packages-verdaccio-env`
instead of rendered manifests.
