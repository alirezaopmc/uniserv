#!/bin/sh
set -eu

. /usr/local/lib/uniserv/parse_config.sh

RETRY_DELAY="${SSH_RETRY_DELAY:-5}"
WAIT_TIMEOUT="${SSH_WAIT_TIMEOUT:-90}"

SSH_USER="$(get_ssh_user)"
SSH_HOST="$(get_ssh_host)"
SSH_PORT="$(get_ssh_port)"
SOCKS_PORT="$(get_ssh_socks_port)"
SSH_TARGET="${SSH_USER}@${SSH_HOST}"

SSH_COMMON_OPTS="-p ${SSH_PORT} -D 127.0.0.1:${SOCKS_PORT} -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

wait_for_tun() {
  elapsed=0
  while [ "$elapsed" -lt "$WAIT_TIMEOUT" ]; do
    if ip link show tun0 >/dev/null 2>&1; then
      echo "VPN interface tun0 is ready."
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "Timed out waiting for tun0 after ${WAIT_TIMEOUT}s." >&2
  return 1
}

wait_for_socks() {
  elapsed=0
  while [ "$elapsed" -lt 30 ]; do
    if nc -z 127.0.0.1 "$SOCKS_PORT" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

wait_for_vpn_routes() {
  elapsed=0
  while [ "$elapsed" -lt "$WAIT_TIMEOUT" ]; do
    if ip route | grep -q "dev tun0"; then
      echo "VPN routes are ready."
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "Timed out waiting for VPN routes after ${WAIT_TIMEOUT}s." >&2
  return 1
}

wait_for_ssh_host() {
  elapsed=0
  while [ "$elapsed" -lt "$WAIT_TIMEOUT" ]; do
    if nc -z -w 5 "$SSH_HOST" "$SSH_PORT" >/dev/null 2>&1; then
      echo "SSH host ${SSH_HOST}:${SSH_PORT} is reachable."
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "Timed out waiting for ${SSH_HOST}:${SSH_PORT} after ${WAIT_TIMEOUT}s." >&2
  return 1
}

start_ssh_tunnel() {
  SSH_KEY="$(get_ssh_private_key_path 2>/dev/null || true)"
  SSH_PASSWORD="$(get_ssh_password 2>/dev/null || true)"

  if [ -n "$SSH_KEY" ] && [ -f "$SSH_KEY" ]; then
    chmod 600 "$SSH_KEY" 2>/dev/null || true
    echo "Using SSH key: $SSH_KEY"
    # shellcheck disable=SC2086
    ssh -N -i "$SSH_KEY" $SSH_COMMON_OPTS "$SSH_TARGET" &
    return
  fi

  if [ -n "$SSH_PASSWORD" ] && [ "$SSH_PASSWORD" != "null" ]; then
    if ! command -v sshpass >/dev/null 2>&1; then
      echo "SSH password configured but sshpass is not installed." >&2
      exit 1
    fi
    # shellcheck disable=SC2086
    sshpass -p "$SSH_PASSWORD" ssh -N $SSH_COMMON_OPTS "$SSH_TARGET" &
    return
  fi

  echo "SSH private key or password is required." >&2
  exit 1
}

wait_for_tun
wait_for_vpn_routes
wait_for_ssh_host

echo "Starting SSH SOCKS tunnel to ${SSH_TARGET} on port ${SOCKS_PORT}"

while true; do
  start_ssh_tunnel
  SSH_PID=$!

  if wait_for_socks; then
    echo "SSH SOCKS tunnel is ready on 127.0.0.1:${SOCKS_PORT}"
    wait "$SSH_PID"
    exit_code=$?
  else
    echo "SSH SOCKS tunnel failed to start." >&2
    kill "$SSH_PID" 2>/dev/null || true
    wait "$SSH_PID" 2>/dev/null || true
    exit_code=1
  fi

  if [ "$exit_code" -eq 0 ]; then
    echo "SSH exited cleanly."
    exit 0
  fi

  echo "SSH disconnected. Retrying in ${RETRY_DELAY}s..." >&2
  sleep "$RETRY_DELAY"
done
