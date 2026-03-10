FROM hashicorp/vault:1.15

USER root

RUN apk add --no-cache curl bash openssl

RUN curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

USER vault