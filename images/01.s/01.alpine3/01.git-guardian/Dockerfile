ARG __alpine_version=latest
FROM alpine:${__alpine_version}

ARG __trivy_ver=v0.68.2

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      curl \
      git \
      lazygit \
      mandoc \
      neovim-doc \
      neovim \
      openssh-client \
      shellcheck \
      shunit2 \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh \
    && apk --no-cache upgrade
