#!/usr/bin/env bash

__kubernetes_utils_guard__() {
  return 0
}

error() {
  echo "$*" >&2
  exit 1
}

require_file() {
  local file_path="$1"
  local hint="${2:-}"
  if [[ -f "${file_path}" ]]; then
    return 0
  fi
  if [[ -n "${hint}" ]]; then
    error "Missing ${file_path}. ${hint}"
  fi
  error "Missing ${file_path}."
}

require_env() {
  local name="$1"
  local scope="${2:-environment}"
  [[ -n "${!name:-}" ]] || error "${name} is required in ${scope}"
}

require_command() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || error "Missing required command: ${cmd}"
}

load_env_file() {
  local file_path="${1:-./.env}"
  require_file "${file_path}" "Create it from ./.env.example."
  set -a
  # shellcheck source=/dev/null
  source "${file_path}"
  set +a
}

generate_tmpdir() {
  GENERATED_TMPDIR="$(mktemp -d)"
  trap "rm -rf '${GENERATED_TMPDIR}'" EXIT
}

generate_base64_file() {
  local file_path="$1"
  local b64_payload="$2"
  umask 077
  printf '%s' "${b64_payload}" | base64 -d > "${file_path}"
}

generate_tmp_ssh_key_file() {
  local b64_payload="$1"
  generate_tmpdir
  local temp_dir="${GENERATED_TMPDIR}"
  local ssh_key_file="${temp_dir}/kubernetes_ssh_key"
  generate_base64_file "${ssh_key_file}" "${b64_payload}"
  GENERATED_SSH_KEY_FILE="${ssh_key_file}"
}

normalize_args() {
  local -a defaults=()
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--" ]]; then
      shift
      break
    fi
    defaults+=("$1")
    shift
  done

  local -a provided=("$@")
  if [[ ${#provided[@]} -eq 0 ]]; then
    NORMALIZED_ARGS=("${defaults[@]}")
    return 0
  fi

  NORMALIZED_ARGS=("${provided[@]}")
}

build_ssh_args() {
  local ssh_key_file="$1"
  local profile="${2:-default}"

  local -a args=(
    -o BatchMode=yes
    -o LogLevel=ERROR
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o ConnectTimeout=8
    -i "${ssh_key_file}"
  )

  if [[ "${profile}" == "tunnel" ]]; then
    args+=(
      -o ServerAliveInterval=15
      -o ServerAliveCountMax=3
      -o ExitOnForwardFailure=yes
    )
  fi

  SSH_ARGS=("${args[@]}")
}

ssh_build_dest() {
  local ssh_user="$1"
  local ssh_host="$2"
  SSH_DEST="${ssh_user}@${ssh_host}"
}

ssh_build_tunnel_spec() {
  local local_port="$1"
  local remote_port="$2"
  SSH_TUNNEL_SPEC="127.0.0.1:${local_port}:127.0.0.1:${remote_port}"
}

ssh_copy_remote_file() {
  local dest="$1"
  local remote_path="$2"
  local local_path="$3"
  scp "${SSH_ARGS[@]}" "${dest}:${remote_path}" "${local_path}" >/dev/null
}

ssh_tunnel_start() {
  local dest="$1"
  local socket_path="$2"
  local tunnel_spec="$3"
  ssh "${SSH_ARGS[@]}" -M -S "${socket_path}" -f -N -L "${tunnel_spec}" "${dest}"
}

ssh_tunnel_stop() {
  local dest="$1"
  local socket_path="$2"
  ssh "${SSH_ARGS[@]}" -S "${socket_path}" -O exit "${dest}" >/dev/null 2>&1 || true
}

kubectl_session_open() {
  local local_port="$1"
  local remote_kubeconfig_path="$2"

  KUBECTL_SESSION_TMPDIR="${GENERATED_TMPDIR}"
  KUBECTL_SESSION_SOCKET="${KUBECTL_SESSION_TMPDIR}/ssh_tunnel.sock"
  KUBECTL_SESSION_KUBECONFIG="${KUBECTL_SESSION_TMPDIR}/kubeconfig.yaml"
  KUBECTL_SESSION_SERVER="https://127.0.0.1:${local_port}"
  KUBECTL_SESSION_OPEN=false

  ssh_copy_remote_file "${SSH_DEST}" "${remote_kubeconfig_path}" "${KUBECTL_SESSION_KUBECONFIG}"
  ssh_build_tunnel_spec "${local_port}" "6443"
  ssh_tunnel_start "${SSH_DEST}" "${KUBECTL_SESSION_SOCKET}" "${SSH_TUNNEL_SPEC}"

  KUBECTL_SESSION_OPEN=true
}

kubectl_session_close() {
  if [[ "${KUBECTL_SESSION_OPEN:-false}" == "true" ]]; then
    ssh_tunnel_stop "${SSH_DEST}" "${KUBECTL_SESSION_SOCKET}"
  fi
}

kubectl_session_exec() {
  kubectl --server "${KUBECTL_SESSION_SERVER}" --kubeconfig "${KUBECTL_SESSION_KUBECONFIG}" "$@"
}
