#!/bin/sh
set -eu

CONFIG_FILE="${CONFIG_FILE:-/etc/uniserv/config.yaml}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

get_openvpn_field() {
  field="$1"
  value="$(yq -r ".openvpn_configs[] | select(.active == true) | .$field" "$CONFIG_FILE" | head -n1)"
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    value="$(yq -r ".openvpn_configs[0].$field" "$CONFIG_FILE")"
  fi
  printf '%s' "$value"
}

get_openvpn_profile_path() {
  profile="$(get_openvpn_field profile)"
  basename "$profile"
}

get_openvpn_username() {
  get_openvpn_field username
}

get_openvpn_password() {
  get_openvpn_field password
}

get_ssh_field() {
  field="$1"
  value="$(yq -r ".ssh_configs[] | select(.active == true) | .$field" "$CONFIG_FILE" | head -n1)"
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    value="$(yq -r ".ssh_configs[0].$field" "$CONFIG_FILE")"
  fi
  printf '%s' "$value"
}

get_ssh_user() {
  get_ssh_field user
}

get_ssh_host() {
  get_ssh_field host
}

get_ssh_port() {
  port="$(get_ssh_field port)"
  if [ -z "$port" ] || [ "$port" = "null" ]; then
    port="22"
  fi
  printf '%s' "$port"
}

get_ssh_password() {
  get_ssh_field password
}

get_ssh_socks_port() {
  port="$(get_ssh_field socks_port)"
  if [ -z "$port" ] || [ "$port" = "null" ]; then
    port="1081"
  fi
  printf '%s' "$port"
}

get_ssh_private_key_path() {
  ssh_dir="${SSH_DIR:-/root/.ssh}"
  key="$(get_ssh_field private_key 2>/dev/null || true)"

  if [ -n "$key" ] && [ "$key" != "null" ]; then
    case "$key" in
      /*)
        resolved_key="$key"
        ;;
      ~/.ssh/*)
        resolved_key="${ssh_dir}/$(basename "$key")"
        ;;
      ssh/keys/*)
        resolved_key="/etc/ssh/keys/$(basename "$key")"
        ;;
      *)
        resolved_key="${ssh_dir}/$(basename "$key")"
        ;;
    esac

    if [ -f "$resolved_key" ]; then
      printf '%s' "$resolved_key"
      return 0
    fi
  fi

  for candidate in id_ed25519 id_rsa id_ecdsa; do
    if [ -f "${ssh_dir}/${candidate}" ]; then
      printf '%s' "${ssh_dir}/${candidate}"
      return 0
    fi
  done

  return 1
}

get_xray_vless_url() {
  url="$(yq -r '.xray_configs[] | select(.active == true) | .url' "$CONFIG_FILE" | head -n1)"
  if [ -z "$url" ] || [ "$url" = "null" ]; then
    url="$(yq -r '.xray_configs[0].url' "$CONFIG_FILE")"
  fi
  printf '%s' "$url"
}

get_query_param() {
  query="$1"
  key="$2"
  param="${query#*${key}=}"
  if [ "$param" = "$query" ]; then
    return 1
  fi
  param="${param%%&*}"
  printf '%s' "$param"
}

parse_vless_url() {
  url="$1"

  case "$url" in
    vless://*) ;;
    *)
      echo "Invalid VLESS URL: $url" >&2
      return 1
      ;;
  esac

  rest="${url#vless://}"
  uuid="${rest%%@*}"
  after_at="${rest#*@}"
  host_port="${after_at%%\?*}"
  host="${host_port%%:*}"
  port="${host_port##*:}"

  query="${after_at#*\?}"
  fragment=""
  if [ "$query" != "$after_at" ]; then
    fragment="${query#*#}"
    query="${query%%#*}"
  elif [ "${after_at#*#}" != "$after_at" ]; then
    fragment="${after_at#*#}"
  fi

  security="$(get_query_param "$query" security || true)"
  encryption="$(get_query_param "$query" encryption || true)"
  network="$(get_query_param "$query" type || true)"

  security="${security:-none}"
  encryption="${encryption:-none}"
  network="${network:-tcp}"

  VLESS_UUID="$uuid"
  VLESS_HOST="$host"
  VLESS_PORT="$port"
  VLESS_SECURITY="$security"
  VLESS_ENCRYPTION="$encryption"
  VLESS_NETWORK="$network"
  VLESS_REMARKS="${fragment:-vless-${port}}"

  export VLESS_UUID VLESS_HOST VLESS_PORT VLESS_SECURITY VLESS_ENCRYPTION VLESS_NETWORK VLESS_REMARKS
}

write_openvpn_auth_file() {
  auth_file="$1"
  umask 077
  {
    get_openvpn_username
    printf '\n'
    get_openvpn_password
    printf '\n'
  } >"$auth_file"
}

generate_xray_config() {
  output="$1"
  url="$(get_xray_vless_url)"
  parse_vless_url "$url"
  ssh_socks_port="$(get_ssh_socks_port)"
  xray_socks_port="${XRAY_SOCKS_PORT:-1091}"

  cat >"$output" <<EOF
{
  "dns": {
    "hosts": {
      "domain:googleapis.cn": "googleapis.com"
    },
    "queryStrategy": "UseIPv4",
    "servers": [
      "1.1.1.1",
      {
        "address": "1.1.1.1",
        "domains": [],
        "port": 53
      },
      {
        "address": "8.8.8.8",
        "domains": [],
        "port": 53
      }
    ]
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": ${xray_socks_port},
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true,
        "userLevel": 8
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls",
          "quic"
        ],
        "enabled": true
      },
      "tag": "socks"
    },
    {
      "listen": "127.0.0.1",
      "port": 11111,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "metrics_in"
    }
  ],
  "log": {
    "loglevel": "warning"
  },
  "metrics": {
    "tag": "metrics_out"
  },
  "outbounds": [
    {
      "protocol": "socks",
      "tag": "ssh-tunnel",
      "settings": {
        "servers": [
          {
            "address": "127.0.0.1",
            "port": ${ssh_socks_port}
          }
        ]
      }
    },
    {
      "mux": {
        "concurrency": -1,
        "enabled": false,
        "xudpConcurrency": 8,
        "xudpProxyUDP443": ""
      },
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "${VLESS_HOST}",
            "port": ${VLESS_PORT},
            "users": [
              {
                "encryption": "${VLESS_ENCRYPTION}",
                "id": "${VLESS_UUID}",
                "level": 8,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "${VLESS_NETWORK}",
        "security": "${VLESS_SECURITY}",
        "tcpSettings": {
          "header": {
            "type": "none"
          }
        },
        "sockopt": {
          "dialerProxy": "ssh-tunnel"
        }
      },
      "tag": "proxy"
    },
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      },
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "http"
        }
      },
      "tag": "block"
    }
  ],
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      },
      "8": {
        "connIdle": 300,
        "downlinkOnly": 1,
        "handshake": 4,
        "uplinkOnly": 1
      }
    },
    "system": {
      "statsInboundDownlink": true,
      "statsInboundUplink": true,
      "statsOutboundDownlink": true,
      "statsOutboundUplink": true
    }
  },
  "remarks": "${VLESS_REMARKS}",
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "inboundTag": [
          "metrics_in"
        ],
        "outboundTag": "metrics_out"
      },
      {
        "inboundTag": [
          "socks"
        ],
        "outboundTag": "proxy",
        "port": "53"
      },
      {
        "ip": [
          "1.1.1.1"
        ],
        "outboundTag": "proxy",
        "port": "53"
      },
      {
        "ip": [
          "8.8.8.8"
        ],
        "outboundTag": "direct",
        "port": "53"
      },
      {
        "inboundTag": [
          "socks"
        ],
        "network": "tcp,udp",
        "outboundTag": "proxy"
      }
    ]
  },
  "stats": {}
}
EOF
}
