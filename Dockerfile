# PasarGuard Node wrapper for Runsite/Render with an outbound Rathole tunnel.
ARG RATHOLE_VERSION=v0.5.0
ARG PASARGUARD_NODE_IMAGE=pasarguard/node:v0.5.4

FROM ${PASARGUARD_NODE_IMAGE}
USER root

# Use the upstream prebuilt, statically linked Rathole binary instead of
# compiling Rust during every deployment.
RUN apk add --no-cache openssl busybox curl unzip \
    && curl -fsSL -o /tmp/rathole.zip \
       "https://github.com/rathole-org/rathole/releases/download/${RATHOLE_VERSION}/rathole-x86_64-unknown-linux-gnu.zip" \
    && unzip -j /tmp/rathole.zip rathole -d /usr/local/bin \
    && chmod 0755 /usr/local/bin/rathole \
    && rm -f /tmp/rathole.zip

COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh

# Runsite/Render HTTP health listener. The PasarGuard node itself remains on
# SERVICE_PORT and is carried through the outbound Rathole tunnel.
ENV PORT=8080 \
    SERVICE_PORT=62050 \
    NODE_HOST=0.0.0.0 \
    SSL_CERT_FILE=/var/lib/pg-node/certs/ssl_cert.pem \
    SSL_KEY_FILE=/var/lib/pg-node/certs/ssl_key.pem \
    GENERATED_CONFIG_PATH=/var/lib/pg-node/generated \
    SERVICE_PROTOCOL=grpc

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
