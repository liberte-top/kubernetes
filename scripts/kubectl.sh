#!/usr/bin/env bash
set -euo pipefail

# Usage: run from kubernetes/ directory so relative paths resolve (./scripts, ./.env).
# Behavior:
#   - SSH ControlMaster/ControlPersist tunnel reuse
#   - local port from INFRA_KUBECTL_TUNNEL_LOCAL_PORT (default: 56443)
#   - "tunnel" subcommands: status|start|stop|restart
#   - fetch remote kubeconfig to a temp file via scp for each invocation
#   - no args: execute "kubectl get nodes --request-timeout=15s"
# shellcheck source=./scripts/utils.sh
source "./scripts/utils.sh" && __kubernetes_utils_guard__

load_env_file

require_command ssh

require_env INFRA_SSH_HOST
require_env INFRA_SSH_USER
require_env INFRA_SSH_PRIVATE_KEY_B64

local_port="${INFRA_KUBECTL_TUNNEL_LOCAL_PORT:-56443}"
control_persist="${INFRA_SSH_CONTROL_PERSIST_SECONDS:-600}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
control_socket="${INFRA_SSH_CONTROL_SOCKET:-${runtime_dir%/}/liberte-kube-ssh-${USER}.sock}"
lock_file="${INFRA_SSH_TUNNEL_LOCK_FILE:-/tmp/liberte-kube-tunnel.lock}"
control_server="https://127.0.0.1:${local_port}"

generate_tmp_ssh_key_file "${INFRA_SSH_PRIVATE_KEY_B64}"
ssh_key_file="${GENERATED_SSH_KEY_FILE}"
cleanup() {
  rm -rf "${GENERATED_TMPDIR}"
}
trap cleanup EXIT

build_ssh_args "${ssh_key_file}" tunnel
ssh_build_dest "${INFRA_SSH_USER}" "${INFRA_SSH_HOST}"
mkdir -p "$(dirname "${control_socket}")"

ssh_control_check() {
  ssh "${SSH_ARGS[@]}" \
    -o ControlMaster=auto \
    -o ControlPath="${control_socket}" \
    -o ControlPersist="${control_persist}" \
    -S "${control_socket}" \
    -O check \
    "${SSH_DEST}" >/dev/null 2>&1
}

tunnel_start_inner() {
  if ssh_control_check; then
    return 0
  fi

  if [[ -S "${control_socket}" ]]; then
    rm -f "${control_socket}"
  fi

  ssh_build_tunnel_spec "${local_port}" "6443"
  ssh "${SSH_ARGS[@]}" \
    -o ControlMaster=auto \
    -o ControlPath="${control_socket}" \
    -o ControlPersist="${control_persist}" \
    -f -N \
    -L "${SSH_TUNNEL_SPEC}" \
    "${SSH_DEST}"

  ssh_control_check || error "Failed to establish SSH control tunnel."
}

tunnel_start() {
  if command -v flock >/dev/null 2>&1; then
    exec 9>"${lock_file}"
    flock -w 10 9 || error "Failed to acquire tunnel lock: ${lock_file}"
    tunnel_start_inner
  else
    tunnel_start_inner
  fi
}

tunnel_stop() {
  if ssh_control_check; then
    ssh "${SSH_ARGS[@]}" \
      -o ControlMaster=auto \
      -o ControlPath="${control_socket}" \
      -o ControlPersist="${control_persist}" \
      -S "${control_socket}" \
      -O exit \
      "${SSH_DEST}" >/dev/null 2>&1 || true
  fi
  [[ -S "${control_socket}" ]] && rm -f "${control_socket}"
  return 0
}

tunnel_status() {
  if ssh_control_check; then
    echo "running"
    echo "socket=${control_socket}"
    echo "server=${control_server}"
    return 0
  fi
  echo "stopped"
  echo "socket=${control_socket}"
  echo "server=${control_server}"
  return 1
}

if [[ "${1:-}" == "tunnel" ]]; then
  action="${2:-status}"
  case "${action}" in
    status)
      tunnel_status
      ;;
    start)
      tunnel_start
      tunnel_status
      ;;
    stop)
      tunnel_stop
      tunnel_status || true
      ;;
    restart)
      tunnel_stop
      tunnel_start
      tunnel_status
      ;;
    *)
      error "Unsupported tunnel action: ${action} (use status|start|stop|restart)"
      ;;
  esac
  exit 0
fi

require_command kubectl
require_command scp
require_env INFRA_KUBECONFIG_PATH

tunnel_start

default_args=("get" "nodes" "--request-timeout=15s")
normalize_args "${default_args[@]}" -- "$@"

kubeconfig_file="${GENERATED_TMPDIR}/kubeconfig.yaml"
scp "${SSH_ARGS[@]}" \
  -o ControlMaster=auto \
  -o ControlPath="${control_socket}" \
  -o ControlPersist="${control_persist}" \
  "${SSH_DEST}:${INFRA_KUBECONFIG_PATH}" \
  "${kubeconfig_file}" >/dev/null

kubectl --server "${control_server}" --kubeconfig "${kubeconfig_file}" "${NORMALIZED_ARGS[@]}"
