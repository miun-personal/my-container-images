ARG __alpine_version=latest
FROM alpine:${__alpine_version}

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      curl \
      git \
      mandoc \
      openssh-client \
      shellcheck \
      shunit2
