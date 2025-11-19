FROM alpine:3.22

ARG __buildah_version=1.41.6-r0
ARG __curl_version=8.14.1-r2
ARG __fuse_overlayfs_version=1.15-r0
ARG __git_version=2.49.1-r0
ARG __mandoc_version=1.14.6-r13
ARG __netavark_version=1.16.1-r0
ARG __openssh_version=10.0_p1-r9
ARG __shadow_version=4.17.3-r0
ARG __shellcheck_version=0.10.0-r2
ARG __shunit2_version=2.1.8-r1
ARG __util_linux_version=2.41-r9
ARG __yamlfmt_version=0.17.0-r3
ARG __yamllint_version=1.37.0-r0


ARG __trivy_ver=v0.67.2
ARG __uid=851
ARG __uname=bind
ARG __trivy_cache_dir=/mnt/trivy-cache

RUN apk add --no-cache --update \
        buildah=${__buildah_version} \
        curl=${__curl_version} \
        fuse-overlayfs=${__fuse_overlayfs_version} \
        git=${__git_version} \
        netavark=${__netavark_version} \
        openssh=${__openssh_version} \
        shadow=${__shadow_version} \
        shellcheck=${__shellcheck_version} \
        util-linux=${__util_linux_version} \
        yamlfmt=${__yamlfmt_version} \
        yamllint=${__yamllint_version} \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh \
    && echo ${__uname}:100000:65536 >> /etc/subuid \
    && echo ${__uname}:100000:65536 >> /etc/subgid \
    && adduser -D -u ${__uid} ${__uname} \
    && mkdir -p ${__trivy_cache_dir} \
    && chown ${__uname}:0 ${__trivy_cache_dir}

USER ${__uname}

VOLUME ${__trivy_cache_dir}
