#!/bin/sh
set -eu

. /usr/local/lib/uniserv/parse_config.sh

RUNTIME_DIR="/run/uniserv"
AUTH_FILE="${RUNTIME_DIR}/openvpn.auth"
PROFILE_DIR="/etc/openvpn/profiles"
RETRY_DELAY="${OPENVPN_RETRY_DELAY:-5}"
STALE_INTERVAL="${OPENVPN_STALE_INTERVAL:-5}"
STALE_THRESHOLD="${OPENVPN_STALE_THRESHOLD:-12}"
PUBLIC_SOCKS_PORT="${PUBLIC_SOCKS_PORT:-1090}"
INTERNAL_SOCKS_PORT="${INTERNAL_SOCKS_PORT:-1091}"

mkdir -p "$RUNTIME_DIR"

profile_name="$(get_openvpn_profile_path)"
profile_path="${PROFILE_DIR}/${profile_name}"

if [ ! -f "$profile_path" ]; then
  echo "OpenVPN profile not found: $profile_path" >&2
  exit 1
fi

write_openvpn_auth_file "$AUTH_FILE"

start_socks_relay() {
  socat "TCP-LISTEN:${PUBLIC_SOCKS_PORT},fork,reuseaddr,bind=0.0.0.0" "TCP:127.0.0.1:${INTERNAL_SOCKS_PORT}" &
  echo "SOCKS relay listening on 0.0.0.0:${PUBLIC_SOCKS_PORT} -> 127.0.0.1:${INTERNAL_SOCKS_PORT}"
}

vpn_is_healthy() {
  ip link show tun0 >/dev/null 2>&1 && ip route | grep -q 'dev tun0'
}

reset_killswitch() {
  /usr/local/lib/uniserv/killswitch-down.sh || true
}

start_openvpn_process() {
  openvpn \
    --config "$profile_path" \
    --auth-user-pass "$AUTH_FILE" \
    --auth-nocache \
    --auth-retry nointeract \
    --persist-tun \
    --persist-key \
    --resolv-retry infinite \
    --keepalive 10 60 \
    --connect-retry 5 10 \
    --connect-retry-max 0 \
    --script-security 2 \
    --up /usr/local/lib/uniserv/killswitch-up.sh \
    --down /usr/local/lib/uniserv/killswitch-down.sh
}

supervise_openvpn() {
  start_openvpn_process &
  openvpn_pid=$!
  stale_checks=0

  while kill -0 "$openvpn_pid" 2>/dev/null; do
    if vpn_is_healthy; then
      stale_checks=0
    else
      stale_checks=$((stale_checks + 1))
      if [ "$stale_checks" -ge "$STALE_THRESHOLD" ]; then
        echo "VPN tunnel unhealthy for $((STALE_INTERVAL * STALE_THRESHOLD))s, forcing reconnect..." >&2
        kill -TERM "$openvpn_pid" 2>/dev/null || true
        wait "$openvpn_pid" 2>/dev/null || true
        reset_killswitch
        return 1
      fi
    fi
    sleep "$STALE_INTERVAL"
  done

  wait "$openvpn_pid"
  exit_code=$?
  reset_killswitch
  return "$exit_code"
}

start_socks_relay

echo "Starting OpenVPN with profile: $profile_name"

while true; do
  if supervise_openvpn; then
    echo "OpenVPN exited cleanly."
    exit 0
  fi

  echo "OpenVPN disconnected. Retrying in ${RETRY_DELAY}s..." >&2
  sleep "$RETRY_DELAY"
done
