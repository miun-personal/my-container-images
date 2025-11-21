ARG __alpine_tag=3.22
FROM alpine:${__alpine_tag}

ARG __buildah_version=1.41.6-r0
ARG __fuse_overlayfs_version=1.15-r0
ARG __netavark_version=1.16.1-r0

RUN apk add --no-cache --update \
      buildah=${__buildah_version} \
      fuse-overlayfs=${__fuse_overlayfs_version} \
      netavark=${__netavark_version}

ARG __uname=bind
ARG __uid=1001

RUN adduser -D -u ${__uid} ${__uname}

USER ${__uname}

