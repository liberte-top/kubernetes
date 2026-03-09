#!/usr/bin/env bash
set -euo pipefail

# Usage: can run from any directory.
# shellcheck source=./scripts/utils.sh
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/utils.sh" && __kubernetes_utils_guard__

load_env_file "${REPO_ROOT}/.env"
require_command ssh

require_env INFRA_SSH_HOST
require_env INFRA_SSH_USER
require_env INFRA_SSH_PRIVATE_KEY_B64

generate_tmp_ssh_key_file "${INFRA_SSH_PRIVATE_KEY_B64}"
ssh_key_file="${GENERATED_SSH_KEY_FILE}"
build_ssh_args "${ssh_key_file}" default
ssh_build_dest "${INFRA_SSH_USER}" "${INFRA_SSH_HOST}"

default_args=("echo" "connection-ok")
normalize_args "${default_args[@]}" -- "$@"
exec ssh "${SSH_ARGS[@]}" "${SSH_DEST}" "${NORMALIZED_ARGS[@]}"
