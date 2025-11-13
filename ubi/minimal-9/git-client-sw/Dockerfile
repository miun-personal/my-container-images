ARG __ubi9_image_tag=9.7-1762956380

FROM redhat/ubi9-minimal:${__ubi9_image_tag}

RUN microdnf -y update \
  && microdnf install -y \
    git \
  && microdnf clean all \
  && rm -rf /var/cache/yum
