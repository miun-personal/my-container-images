ARG __alpine_version=3.23
FROM alpine:${__alpine_version}

# Alpine packages versions: https://pkgs.alpinelinux.org/
ARG __curl_version=8.17.0-r1
ARG __git_version=2.52.0-r0
ARG __lazygit_version=0.48.0-r7
ARG __mandoc_version=1.14.6-r13
ARG __neovim_doc_version=0.11.5-r0
ARG __neovim_version=0.11.5-r0
ARG __openssh_version=10.2_p1-r0
ARG __shellcheck_version=0.11.0-r0
ARG __shunit2_version=2.1.8-r1

ARG __trivy_ver=v0.68.1

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      curl=${__curl_version} \
      git=${__git_version} \
      lazygit=${__lazygit_version} \
      mandoc=${__mandoc_version} \
      neovim-doc=${__neovim_doc_version} \
      neovim=${__neovim_version} \
      openssh-client=${__openssh_version} \
      shellcheck=${__shellcheck_version} \
      shunit2=${__shunit2_version} \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh \
    && apk --no-cache upgrade
