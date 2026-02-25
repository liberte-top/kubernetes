#!/usr/bin/env bash
set -euo pipefail

# Usage: run from kubernetes/ directory so relative paths resolve (./scripts, ./.env).
# shellcheck source=./scripts/utils.sh
source "./scripts/utils.sh" && __kubernetes_utils_guard__

load_env_file
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
