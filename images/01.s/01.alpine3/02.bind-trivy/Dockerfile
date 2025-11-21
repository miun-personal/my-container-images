### BEGIN Layer alpine 3.22
ARG __alpine_tag=3.22
FROM alpine:${__alpine_tag}
### END Layer alpine 3.22

### BEGIN Layer __images/s/alpine/bind-trivy/Dockerfile/#1__
ARG __buildah_version=1.41.6-r0
ARG __curl_version=8.14.1-r2
ARG __trivy_ver=v0.67.2
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
