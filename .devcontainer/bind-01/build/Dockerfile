FROM alpine:3.23

## Layer 1 - software
ARG __buildah_version=1.42.1-r1
ARG __curl_version=8.17.0-r1
ARG __fuse_overlayfs_version=1.16-r0
ARG __gettext_envsubst_version=0.24.1-r1
ARG __git_version=2.52.0-r0
ARG __jq_version=1.8.1-r0
ARG __mandoc_version=1.14.6-r13
ARG __netavark_version=1.16.1-r0
ARG __openssh_version=10.2_p1-r0
ARG __shadow_version=4.18.0-r0
ARG __shellcheck_version=0.11.0-r0
ARG __shunit2_version=2.1.8-r1
ARG __trivy_ver=v0.68.1
ARG __util_linux_version=2.41.2-r0
ARG __yamlfmt_version=0.20.0-r1
ARG __yamllint_version=1.37.1-r0

RUN apk add --no-cache --update \
        buildah=${__buildah_version} \
        curl=${__curl_version} \
        gettext-envsubst=${__gettext_envsubst_version} \
        fuse-overlayfs=${__fuse_overlayfs_version} \
        git=${__git_version} \
        jq=${__jq_version} \
        netavark=${__netavark_version} \
        openssh=${__openssh_version} \
        shadow=${__shadow_version} \
        shellcheck=${__shellcheck_version} \
        util-linux=${__util_linux_version} \
        yamlfmt=${__yamlfmt_version} \
        yamllint=${__yamllint_version} \
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
