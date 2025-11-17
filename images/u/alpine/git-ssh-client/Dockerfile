ARG __alpine_version=3.22
FROM alpine:${__alpine_version}

# Alpine packages versions: https://pkgs.alpinelinux.org/
ARG __curl_version=8.14.1-r2
ARG __git_version=2.49.1-r0
ARG __mandoc_version=1.14.6-r13
ARG __openssh_version=10.0_p1-r9
ARG __shellcheck_version=0.10.0-r2
ARG __shunit2_version=2.1.8-r1

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      curl=${__curl_version} \
      git=${__git_version} \
      mandoc=${__mandoc_version} \
      openssh-client=${__openssh_version} \
      shellcheck=${__shellcheck_version} \
      shunit2=${__shunit2_version}

## Begin Layer Git Client User
ARG __gid=888
ARG __gname=dev
ARG __uid=888
ARG __uname=dev
ARG __user_home=/home/${__uname}

RUN addgroup -g ${__gid} ${__gname} \
    && adduser -u ${__uid} -G ${__gname} -D -h ${__user_home} ${__uname} \
    && mkdir -p \
      "${__user_home}/o" \
      "${__user_home}/.ssh" \
      "${__user_home}/scripts/mounted" \
    && chown ${__uid}:${__gid} \
      "${__user_home}/o" \
      "${__user_home}/.ssh" \
      "${__user_home}/scripts/mounted"

    # Copy scripts into the image
COPY --chown=${__uid}:${__gid} scripts/ ${__user_home}/scripts/image/

RUN chmod u+x ${__user_home}/scripts/image/*.sh

USER ${__uname}

WORKDIR "${__user_home}"

# Configure shell environment
# Create .ashrc for interactive non-login shells
RUN echo '# User aliases and environment' > ${__user_home}/.ashrc \
    && echo 'alias ll="ls -lah"' >> ${__user_home}/.ashrc \
    && echo 'alias scommit="git commit -s"' >> ${__user_home}/.ashrc \
    && echo '' >> ${__user_home}/.ashrc \
    && echo '# Source ssh-agent if available' >> ${__user_home}/.ashrc \
    && echo '[ -f "$HOME/s/agent-init.sh" ] && . "$HOME/s/agent-init.sh"' >> ${__user_home}/.ashrc

# Set ENV to point to .ashrc so it's loaded for all interactive shells
ENV ENV=${__user_home}/.ashrc

RUN git config --global commit.gpgsign true \
  && git config --global gpg.format ssh \
  && git config --global core.eol lf \
  && git config --global core.autocrlf input \
  && git config --global format.signoff true

VOLUME "${__user_home}/o" "${__user_home}/.ssh" "${__user_home}/scripts/mounted"
## Convention:
# - ~/o overwatch / this repo / workspace
# - ~/.ssh user to mount to keep the keys across multiple runs
# - ~/scripts/mounted - user to mount for their own scripts
# - ~/scripts/image - scripts already provided to the user in the image

## End Layer
