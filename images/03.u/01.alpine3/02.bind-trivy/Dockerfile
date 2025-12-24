### BEGIN Layer alpine 3.22
ARG __alpine_tag=3.22
FROM alpine:${__alpine_tag}
### END Layer alpine 3.22

### BEGIN Layer __images/s/alpine/bind-trivy/Dockerfile/packs__
ARG __buildah_version=1.41.6-r0
ARG __curl_version=8.17.0-r1
ARG __trivy_ver=v0.68.1
ARG __fuse_overlayfs_version=1.15-r0
ARG __netavark_version=1.16.1-r0

RUN apk add --no-cache --update \
      buildah=${__buildah_version}  \
      curl=${__curl_version} \
      fuse-overlayfs=${__fuse_overlayfs_version} \
      netavark=${__netavark_version} \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh
### END Layer __images/s/alpine/bind-trivy/Dockerfile/#1__

### BEGIN Layer __images/u/alpine/bind-trivy/Dockerfile/user__
ARG __uid=851
ARG __uname=bind
ARG __trivy_cache_dir=/mnt/trivy-cache

RUN echo ${__uname}:100000:65536 >> /etc/subuid \
    && echo ${__uname}:100000:65536 >> /etc/subgid \
    && adduser -D -u ${__uid} ${__uname} \
    && mkdir -p ${__trivy_cache_dir} \
    && chown ${__uname}:0 ${__trivy_cache_dir}
### END Layer __images/u/alpine/bind-trivy/Dockerfile/user__
