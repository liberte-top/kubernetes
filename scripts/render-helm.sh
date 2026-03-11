#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! command -v helm >/dev/null 2>&1; then
  echo "Missing required command: helm" >&2
  exit 1
fi

mkdir -p "${ROOT_DIR}/manifests/service/auth"
mkdir -p "${ROOT_DIR}/manifests/service/smoke"

helm template service-auth "${ROOT_DIR}/charts/service/auth" --namespace service > "${ROOT_DIR}/manifests/service/auth/rendered.yaml"
helm template app-smoke "${ROOT_DIR}/charts/app/smoke" --namespace service > "${ROOT_DIR}/manifests/service/smoke/rendered.yaml"

echo "Rendered Helm manifests into manifests/service/{auth,smoke}/rendered.yaml"
