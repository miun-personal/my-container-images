ARG __alpine_version=latest
FROM alpine:${__alpine_version}

ARG __trivy_ver=v0.68.2

## Layer 1 - software
RUN apk add --no-cache --update \
        buildah\
        curl \
        gettext-envsubst \
        fuse-overlayfs \
        git \
        jq \
        netavark \
        openssh \
        shadow \
        shellcheck \
        util-linux \
        yamlfmt \
        yamllint \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh

## Layer 2 - user & config 
ARG __uid=1001
ARG __uname=bind
ARG __trivy_cache_dir=/mnt/trivy-cache
ARG __workspace_home=/workspace/my-container-images

ENV TRIVY_CACHE_DIR="${__trivy_cache_dir}" \
    PS1='\u@\h:\w$'
RUN    echo ${__uname}:100000:65536 >> /etc/subuid \
    && echo ${__uname}:100000:65536 >> /etc/subgid \
    && adduser -D -u ${__uid} ${__uname} \
    && mkdir -p "${__trivy_cache_dir}" "${__workspace_home}"\
    && chown ${__uname}:0 "${__trivy_cache_dir}" "${__workspace_home}"

USER ${__uname}

VOLUME "${__trivy_cache_dir}" "${__workspace_home}"
