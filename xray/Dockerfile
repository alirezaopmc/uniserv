FROM debian:bookworm-slim

ARG TARGETARCH
ARG XRAY_VERSION=25.3.6
ARG YQ_VERSION=4.45.1

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    iproute2 \
    netcat-openbsd \
  && case "$TARGETARCH" in \
    amd64) XRAY_ARCH=64; YQ_ARCH=amd64 ;; \
    arm64) XRAY_ARCH=arm64-v8a; YQ_ARCH=arm64 ;; \
    *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
  esac \
  && curl -fsSL "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip" -o /tmp/xray.zip \
  && unzip /tmp/xray.zip -d /usr/local/bin \
  && chmod +x /usr/local/bin/xray \
  && curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${YQ_ARCH}" -o /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq \
  && rm -rf /var/lib/apt/lists/* /tmp/xray.zip

COPY scripts/parse_config.sh /usr/local/lib/uniserv/parse_config.sh
COPY xray/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /usr/local/lib/uniserv/parse_config.sh

ENTRYPOINT ["/entrypoint.sh"]
