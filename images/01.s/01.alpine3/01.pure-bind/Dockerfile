ARG __alpine_tag=3.22
FROM alpine:${__alpine_tag}

ARG __buildah_version=1.41.6-r0
ARG __fuse_overlayfs_version=1.15-r0
ARG __netavark_version=1.16.1-r0

# Layer images\s\alpine\pure-bind\Dockerfile\#1
RUN apk add --no-cache --update \
      buildah=${__buildah_version} \
      fuse-overlayfs=${__fuse_overlayfs_version} \
      netavark=${__netavark_version}
