#!/usr/bin/env bash
set -euo pipefail

# Usage: can run from any directory.
# Behavior:
#   - SSH ControlMaster/ControlPersist tunnel reuse through a stamped ssh master
#   - local port from INFRA_KUBECTL_TUNNEL_LOCAL_PORT (default: 56443)
#   - "tunnel" subcommands: status|start|stop|restart
#   - fetch remote kubeconfig to a temp file via scp for each invocation
#   - no args: execute "kubectl get nodes --request-timeout=15s"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/utils.sh
source "${SCRIPT_DIR}/utils.sh" && __kubernetes_utils_guard__

load_env_file "${REPO_ROOT}/.env"

require_command ssh
require_command shasum

require_env INFRA_SSH_HOST
require_env INFRA_SSH_USER
require_env INFRA_SSH_PRIVATE_KEY_B64

local_port="${INFRA_KUBECTL_TUNNEL_LOCAL_PORT:-56443}"
remote_port="6443"
control_persist="${INFRA_SSH_CONTROL_PERSIST_SECONDS:-600}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
tunnel_seed="${INFRA_SSH_USER}@${INFRA_SSH_HOST}:${local_port}:${remote_port}"
tunnel_hash="$(printf '%s' "${tunnel_seed}" | shasum -a 256)"
tunnel_namespace="${INFRA_KUBECTL_TUNNEL_NAMESPACE:-${tunnel_hash:0:12}}"
control_socket="${INFRA_SSH_CONTROL_SOCKET:-${runtime_dir%/}/liberte-kube-ssh-${USER}-${tunnel_namespace}.sock}"
control_server="https://127.0.0.1:${local_port}"
tunnel_stamp="liberte-kube-tunnel port=${local_port} ns=${tunnel_namespace}"

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

trim_leading_space() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  printf '%s' "${value}"
}

stamped_tunnel_pids() {
  local line pid command
  while IFS= read -r line; do
    line="$(trim_leading_space "${line}")"
    [[ -n "${line}" ]] || continue

    pid="${line%%[[:space:]]*}"
    command="${line#"${pid}"}"
    command="$(trim_leading_space "${command}")"

    [[ "${pid}" == "$$" ]] && continue
    [[ "${command}" == *"${tunnel_stamp}"* ]] || continue
    printf '%s\n' "${pid}"
  done < <(ps -axww -o pid=,command=)
}

first_stamped_tunnel_pid() {
  local pid
  while IFS= read -r pid; do
    [[ -n "${pid}" ]] || continue
    printf '%s' "${pid}"
    return 0
  done < <(stamped_tunnel_pids)
  return 1
}

wait_for_stamped_tunnel() {
  local timeout_seconds="${1:-8}"
  local deadline=$((SECONDS + timeout_seconds))
  while (( SECONDS <= deadline )); do
    if first_stamped_tunnel_pid >/dev/null && ssh_control_check; then
      return 0
    fi
    sleep 0.2
  done
  return 1
}

start_stamped_ssh_tunnel() {
  if [[ -S "${control_socket}" ]] && ! ssh_control_check; then
    rm -f "${control_socket}"
  fi

  ssh_build_tunnel_spec "${local_port}" "${remote_port}"
  # shellcheck disable=SC2016
  "${BASH:-bash}" -c 'exec -a "$0" "$@"' \
    "${tunnel_stamp}" \
    ssh "${SSH_ARGS[@]}" \
    -o ControlMaster=auto \
    -o ControlPath="${control_socket}" \
    -o ControlPersist="${control_persist}" \
    -f -N \
    -L "${SSH_TUNNEL_SPEC}" \
    "${SSH_DEST}"
}

tunnel_start() {
  local existing_pid start_log

  if wait_for_stamped_tunnel 1; then
    return 0
  fi

  existing_pid="$(first_stamped_tunnel_pid || true)"
  if [[ -n "${existing_pid}" ]]; then
    wait_for_stamped_tunnel 8 || error "Stamped SSH tunnel exists but is not ready: pid=${existing_pid} stamp=${tunnel_stamp}"
    return 0
  fi

  if ssh_control_check; then
    error "Existing SSH control master is not stamped: socket=${control_socket}. Run './scripts/kubectl.sh tunnel restart' once to replace it."
  fi

  start_log="${GENERATED_TMPDIR}/ssh-tunnel-start.log"
  if ! start_stamped_ssh_tunnel >"${start_log}" 2>&1; then
    if wait_for_stamped_tunnel 5; then
      return 0
    fi
    error "Failed to establish stamped SSH tunnel (${tunnel_stamp}). $(<"${start_log}")"
  fi

  wait_for_stamped_tunnel 8 || error "Failed to verify stamped SSH tunnel: ${tunnel_stamp}"
}

tunnel_stop() {
  local pid
  pid="$(first_stamped_tunnel_pid || true)"

  if ssh_control_check; then
    ssh "${SSH_ARGS[@]}" \
      -o ControlMaster=auto \
      -o ControlPath="${control_socket}" \
      -o ControlPersist="${control_persist}" \
      -S "${control_socket}" \
      -O exit \
      "${SSH_DEST}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${pid}" ]]; then
    local deadline=$((SECONDS + 5))
    while (( SECONDS <= deadline )); do
      first_stamped_tunnel_pid >/dev/null || break
      sleep 0.2
    done
  fi

  [[ -S "${control_socket}" ]] && rm -f "${control_socket}"
  return 0
}

tunnel_status() {
  local pid
  pid="$(first_stamped_tunnel_pid || true)"

  if [[ -n "${pid}" ]] && ssh_control_check; then
    echo "running"
    echo "pid=${pid}"
    echo "stamp=${tunnel_stamp}"
    echo "socket=${control_socket}"
    echo "server=${control_server}"
    return 0
  fi

  if [[ -n "${pid}" ]]; then
    echo "unhealthy"
    echo "pid=${pid}"
    echo "stamp=${tunnel_stamp}"
    echo "socket=${control_socket}"
    echo "server=${control_server}"
    return 1
  fi

  if ssh_control_check; then
    echo "legacy"
    echo "socket=${control_socket}"
    echo "server=${control_server}"
    return 1
  fi

  echo "stopped"
  echo "stamp=${tunnel_stamp}"
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
