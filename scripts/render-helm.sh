#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if ! command -v helm >/dev/null 2>&1; then
  echo "Missing required command: helm" >&2
  exit 1
fi

mkdir -p "${ROOT_DIR}/manifests/service"

helm lint "${ROOT_DIR}/charts/service/auth"
helm lint "${ROOT_DIR}/charts/app/smoke"
helm lint "${ROOT_DIR}/charts/service/packages"

helm template service-auth "${ROOT_DIR}/charts/service/auth" --namespace service > "${TMP_DIR}/auth.yaml"
helm template app-smoke "${ROOT_DIR}/charts/app/smoke" --namespace service > "${TMP_DIR}/smoke.yaml"
helm template service-packages "${ROOT_DIR}/charts/service/packages" --namespace service > "${TMP_DIR}/packages.yaml"
mv "${TMP_DIR}/auth.yaml" "${ROOT_DIR}/manifests/service/auth.yaml"
mv "${TMP_DIR}/smoke.yaml" "${ROOT_DIR}/manifests/service/smoke.yaml"
mv "${TMP_DIR}/packages.yaml" "${ROOT_DIR}/manifests/service/packages.yaml"

echo "Rendered Helm manifests into manifests/service/{auth,smoke,packages}.yaml"
