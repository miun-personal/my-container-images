ARG __alpine_tag=3.22
FROM alpine:${__alpine_tag}

ARG __curl_version=8.14.1-r2
ARG __docker_cli_version=28.3.3-r3
ARG __jq_version=1.8.1-r0
ARG __trivy_ver=v0.67.2

ARG __uid=851
ARG __uname=trivy
ARG __trivy_cache_dir=/mnt/trivy-cache

RUN apk add --no-cache --update \
    curl=${__curl_version} \
    docker-cli=${__docker_cli_version} \
    jq=${__jq_version} \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin ${__trivy_ver} \
    && adduser -D -u ${__uid} ${__uname} \
    && mkdir -p ${__trivy_cache_dir} \
    && chown ${__uname}:0 ${__trivy_cache_dir}

COPY scan-and-classify.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/scan-and-classify.sh

USER ${__uname}

VOLUME ${__trivy_cache_dir}
