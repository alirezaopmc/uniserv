FROM debian:bookworm-slim

ARG TARGETARCH
ARG YQ_VERSION=4.45.1

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    openssh-client \
    sshpass \
    iproute2 \
    netcat-openbsd \
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
COPY ssh/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /usr/local/lib/uniserv/parse_config.sh

ENTRYPOINT ["/entrypoint.sh"]
