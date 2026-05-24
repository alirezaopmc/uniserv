#!/bin/sh
set -eu

. /usr/local/lib/uniserv/parse_config.sh

RUNTIME_DIR="/run/uniserv"
CONFIG_OUTPUT="${RUNTIME_DIR}/config.json"
RETRY_DELAY="${XRAY_RETRY_DELAY:-5}"
WAIT_TIMEOUT="${XRAY_WAIT_TIMEOUT:-90}"

mkdir -p "$RUNTIME_DIR"

wait_for_vpn() {
  elapsed=0
  while [ "$elapsed" -lt "$WAIT_TIMEOUT" ]; do
    if ip link show tun0 >/dev/null 2>&1 && ip route | grep -q 'dev tun0'; then
      echo "VPN tunnel is ready."
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "Timed out waiting for VPN tunnel after ${WAIT_TIMEOUT}s." >&2
  return 1
}

wait_for_vpn
generate_xray_config "$CONFIG_OUTPUT"

echo "Starting Xray with SOCKS5 on port 1091"

while true; do
  if xray run -c "$CONFIG_OUTPUT"; then
    echo "Xray exited cleanly."
    exit 0
  fi

  echo "Xray crashed. Restarting in ${RETRY_DELAY}s..." >&2
  sleep "$RETRY_DELAY"
done
