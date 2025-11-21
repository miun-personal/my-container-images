ARG __alpine_version=3.22
FROM alpine:${__alpine_version}

# Alpine packages versions: https://pkgs.alpinelinux.org/
ARG __buildah_version=1.41.6-r0
ARG __curl_version=8.14.1-r2
ARG __fuse_overlayfs_version=1.15-r0
ARG __git_version=2.49.1-r0
ARG __mandoc_version=1.14.6-r13
ARG __netavark_version=1.16.1-r0
ARG __openssh_version=10.0_p1-r9
ARG __shellcheck_version=0.10.0-r2
ARG __shunit2_version=2.1.8-r1
ARG __trivy_ver=v0.67.2

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      buildah=${__buildah_version}  \
      curl=${__curl_version} \
      fuse-overlayfs=${__fuse_overlayfs_version} \
      git=${__git_version} \
      mandoc=${__mandoc_version} \
      netavark=${__netavark_version} \
      openssh-client=${__openssh_version} \
      shellcheck=${__shellcheck_version} \
      shunit2=${__shunit2_version} \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh