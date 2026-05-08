#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

KUBECTL="${KUBECTL:-${SCRIPT_DIR}/kubectl.sh}"
CERT_FILE="${SEAL_CERT_FILE:-${ROOT_DIR}/certs/seal.pem}"
CONTROLLER_NAMESPACE="${SEAL_CONTROLLER_NAMESPACE:-kube-system}"
KEY_PREFIX="sealed-secrets-key"

usage() {
  printf '%s\n' "Usage:"
  printf '%s\n' "  scripts/seal.sh cert"
  printf '%s\n' "  scripts/seal.sh backup-key [directory]"
  printf '%s\n' "  scripts/seal.sh core"
  printf '%s\n' "  scripts/seal.sh service"
  printf '%s\n' "  scripts/seal.sh all"
  printf '%s\n' "  scripts/seal.sh check"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

key_name() {
  "${KUBECTL}" -n "${CONTROLLER_NAMESPACE}" get secret -o json \
    | jq -r --arg prefix "${KEY_PREFIX}" '.items[] | select(.metadata.name | startswith($prefix)) | .metadata.name' \
    | sort \
    | tail -n 1
}

fetch_cert() {
  require_command jq
  require_command base64

  local name
  name="$(key_name)"
  if [[ -z "${name}" ]]; then
    printf 'No sealed-secrets key secret found in namespace %s\n' "${CONTROLLER_NAMESPACE}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${CERT_FILE}")"
  "${KUBECTL}" -n "${CONTROLLER_NAMESPACE}" get secret "${name}" -o jsonpath='{.data.tls\.crt}' \
    | base64 -d > "${CERT_FILE}"
  chmod 0644 "${CERT_FILE}"
  printf 'Wrote %s from %s/%s\n' "${CERT_FILE#${ROOT_DIR}/}" "${CONTROLLER_NAMESPACE}" "${name}"
}

backup_key() {
  require_command jq

  local target_dir
  target_dir="${1:-${HOME}/Downloads}"

  local name
  name="$(key_name)"
  if [[ -z "${name}" ]]; then
    printf 'No sealed-secrets key secret found in namespace %s\n' "${CONTROLLER_NAMESPACE}" >&2
    exit 1
  fi

  mkdir -p "${target_dir}"
  local target_file
  target_file="${target_dir%/}/${name}.yaml"
  "${KUBECTL}" -n "${CONTROLLER_NAMESPACE}" get secret "${name}" -o yaml > "${target_file}"
  chmod 0600 "${target_file}"
  printf 'Wrote %s\n' "${target_file}"
}

seal_secret() {
  require_command jq
  require_command kubeseal

  local namespace="$1"
  local name="$2"
  local output_file="$3"
  local tmp_dir="$4"

  local raw_file="${tmp_dir}/${namespace}.${name}.raw.json"
  local secret_file="${tmp_dir}/${namespace}.${name}.secret.json"

  "${KUBECTL}" -n "${namespace}" get secret "${name}" -o json > "${raw_file}"
  jq '{
    apiVersion: "v1",
    kind: "Secret",
    metadata: {
      name: .metadata.name,
      namespace: .metadata.namespace,
      annotations: {
        "sealedsecrets.bitnami.com/managed": "true"
      }
    },
    type: (.type // "Opaque"),
    data: .data
  }' "${raw_file}" > "${secret_file}"

  printf '%s\n' '---' >> "${output_file}"
  kubeseal --cert "${CERT_FILE}" --scope strict --format yaml < "${secret_file}" >> "${output_file}"
  printf 'sealed %s/%s\n' "${namespace}" "${name}"
}

seal_group() {
  local namespace="$1"
  local output_file="$2"
  shift 2

  if [[ ! -f "${CERT_FILE}" ]]; then
    printf 'Missing public cert: %s\n' "${CERT_FILE}" >&2
    printf 'Run scripts/seal.sh cert first.\n' >&2
    exit 1
  fi

  mkdir -p "$(dirname "${output_file}")"
  (
    tmp_dir="$(mktemp -d)"
    cleanup() {
      rm -rf "${tmp_dir}"
    }
    trap cleanup EXIT

    next_file="${tmp_dir}/secrets.yaml"
    : > "${next_file}"

    for name in "$@"; do
      seal_secret "${namespace}" "${name}" "${next_file}" "${tmp_dir}"
    done

    mv "${next_file}" "${output_file}"
    printf 'Wrote %s\n' "${output_file#${ROOT_DIR}/}"
  )
}

seal_core() {
  seal_group core "${ROOT_DIR}/manifests/core/secrets.yaml" \
    postgres
}

seal_service() {
  seal_group service "${ROOT_DIR}/manifests/service/secrets.yaml" \
    auth-api-env \
    packages-verdaccio-env \
    packages-verdaccio-auth \
    packages-ghcr-pull
}

check() {
  require_command kubectl
  require_command rg

  if [[ ! -f "${CERT_FILE}" ]]; then
    printf 'Missing public cert: %s\n' "${CERT_FILE}" >&2
    exit 1
  fi

  if rg -n '^kind:[[:space:]]+Secret$|^apiVersion:[[:space:]]+v1$' "${ROOT_DIR}/manifests/core/secrets.yaml" "${ROOT_DIR}/manifests/service/secrets.yaml" >/dev/null 2>&1; then
    printf 'Found plain Secret-looking content in sealed secret manifests.\n' >&2
    exit 1
  fi

  kubectl kustomize "${ROOT_DIR}/manifests" >/dev/null
  printf 'sealed secret manifests look renderable\n'
}

main() {
  local command="${1:-}"
  case "${command}" in
    cert)
      fetch_cert
      ;;
    backup-key)
      shift
      backup_key "$@"
      ;;
    core)
      seal_core
      ;;
    service)
      seal_service
      ;;
    all)
      seal_core
      seal_service
      ;;
    check)
      check
      ;;
    "" | -h | --help | help)
      usage
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
