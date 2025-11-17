ARG __image_version=3.22
FROM alpine:${__image_version}

# Alpine packages versions: https://pkgs.alpinelinux.org/
ARG __curl_version=8.14.1-r2
ARG __git_version=2.49.1-r0
ARG __lazygit_version=0.48.0-r5
ARG __mandoc_version=1.14.6-r13
ARG __neovim_doc_version=0.11.1-r1
ARG __neovim_version=0.11.1-r1
ARG __shellcheck_version=0.10.0-r2
ARG __shfmt_version=3.11.0-r3
ARG __shunit2_version=2.1.8-r1

ARG __gid=1000
ARG __gname=dev
ARG __uid=1000
ARG __uname=dev
ARG __user_home=/home/${__uname}

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      curl=${__curl_version} \
      git=${__git_version} \
      lazygit=${__lazygit_version} \
      mandoc=${__mandoc_version} \
      neovim-doc=${__neovim_doc_version} \
      neovim=${__neovim_version} \
      shellcheck=${__shellcheck_version} \
      shfmt=${__shfmt_version} \
      shunit2=${__shunit2_version} \
    && addgroup -g ${__gid} ${__gname} \
    && adduser -u ${__uid} -G ${__gname} -D -h ${__user_home} ${__uname}

# minimal healthcheck, we do not really need it here
HEALTHCHECK CMD exit 0

USER ${__uname}
