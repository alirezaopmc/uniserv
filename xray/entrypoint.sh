#!/bin/sh
set -eu

. /usr/local/lib/uniserv/parse_config.sh

RUNTIME_DIR="/run/uniserv"
CONFIG_OUTPUT="${RUNTIME_DIR}/config.json"
RETRY_DELAY="${XRAY_RETRY_DELAY:-5}"
WAIT_TIMEOUT="${XRAY_WAIT_TIMEOUT:-90}"
SSH_SOCKS_PORT="$(get_ssh_socks_port)"

mkdir -p "$RUNTIME_DIR"

wait_for_ssh_socks() {
  elapsed=0
  while [ "$elapsed" -lt "$WAIT_TIMEOUT" ]; do
    if nc -z 127.0.0.1 "$SSH_SOCKS_PORT" >/dev/null 2>&1; then
      echo "SSH SOCKS tunnel is ready on 127.0.0.1:${SSH_SOCKS_PORT}."
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "Timed out waiting for SSH SOCKS on port ${SSH_SOCKS_PORT} after ${WAIT_TIMEOUT}s." >&2
  return 1
}

wait_for_ssh_socks
generate_xray_config "$CONFIG_OUTPUT"

echo "Starting Xray with SOCKS5 published on port 1090"

while true; do
  if xray run -c "$CONFIG_OUTPUT"; then
    echo "Xray exited cleanly."
    exit 0
  fi

  echo "Xray crashed. Restarting in ${RETRY_DELAY}s..." >&2
  sleep "$RETRY_DELAY"
done
