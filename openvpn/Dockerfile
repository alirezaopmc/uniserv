FROM debian:bookworm-slim

ARG TARGETARCH
ARG YQ_VERSION=4.45.1

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    openvpn \
    iproute2 \
    iptables \
    socat \
    ca-certificates \
    curl \
  && case "$TARGETARCH" in \
    amd64) YQ_ARCH=amd64 ;; \
    arm64) YQ_ARCH=arm64 ;; \
    *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
  esac \
  && curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${YQ_ARCH}" -o /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq \
  && rm -rf /var/lib/apt/lists/*

COPY scripts/parse_config.sh /usr/local/lib/uniserv/parse_config.sh
COPY openvpn/killswitch-up.sh /usr/local/lib/uniserv/killswitch-up.sh
COPY openvpn/killswitch-down.sh /usr/local/lib/uniserv/killswitch-down.sh
COPY openvpn/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /usr/local/lib/uniserv/parse_config.sh \
  /usr/local/lib/uniserv/killswitch-up.sh /usr/local/lib/uniserv/killswitch-down.sh

ENTRYPOINT ["/entrypoint.sh"]
