ARG __alpine_version=3.23
FROM alpine:${__alpine_version}

# Alpine packages versions: https://pkgs.alpinelinux.org/
ARG __curl_version=8.17.0-r1
ARG __git_version=2.52.0-r0
ARG __mandoc_version=1.14.6-r13
ARG __openssh_version=10.2_p1-r0
ARG __shellcheck_version=0.11.0-r0
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
ARG __gid=1001
ARG __gname=dev
ARG __uid=1001
ARG __uname=dev

## By design - this is where we work
ARG __workspace_home=/workspace
## Simplify parameters into a single workspace, this image is intended to be used as devcontainer or similar

ENV WORKSPACE_HOME=${__workspace_home} \
    WORKSPACE_USER_HOME=${__workspace_home}/home/${__uname} \
    WORKSPACE_MAIN_REPO_HOME=${__workspace_home}/mnt/this-repo \
    WORKSPACE_MOUNTED_SCRIPTS_HOME=${__workspace_home}/mnt/scripts \
    WORKSPACE_MANAGED_REPOS_HOME=${__workspace_home}/mnt/repos \
    WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME=${__workspace_home}/util \
    ENV=${__workspace_home}/.ashrc \
    TMPDIR=/tmp

RUN mkdir -p "${__workspace_home}" \
    && echo '# User aliases and environment' > ${ENV} \
    && echo 'alias ll="ls -lah"' >> ${ENV} \
    && echo 'alias scommit="git commit -s"' >> ${ENV} \
    && echo 'alias scommitg="git commit -S -s"' >> ${ENV} \
    && echo 'alias smerge="git merge --signoff"' >> ${ENV} \
    && echo 'alias samend="git commit --amend -S -s"' >> ${ENV} \
    && echo 'alias spush="git push --signed"' >> ${ENV} \
    && echo 'alias slog="git log --show-signature"' >> ${ENV} \
    && echo 'alias srebase="git rebase --signoff"' >> ${ENV} \
    && echo 'alias sclone="git clone --config commit.gpgsign=true"' >> ${ENV} \
    && echo '' >> ${ENV} \
    && echo '# Source ssh-agent if available' >> ${ENV} \
    && echo '[ -f "${WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME}/agent-init.sh" ] && . "${WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME}/agent-init.sh"' >> ${ENV} \
    && echo '' >> ${ENV} \
    && echo '# Source repo management utilities' >> ${ENV} \
    && echo '[ -f "${WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME}/repo-utils.sh" ] && . "${WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME}/repo-utils.sh"' >> ${ENV} \
    && echo '' >> ${ENV} \
    && echo '# Ensure main repo is a safe git directory' >> ${ENV} \
    && echo 'if ! git config --global --get-all safe.directory | grep -qx "${WORKSPACE_MAIN_REPO_HOME}"; then git config --global --add safe.directory "${WORKSPACE_MAIN_REPO_HOME}"; fi' >> ${ENV} \
    && addgroup -g ${__gid} ${__gname} \
    && adduser -u ${__uid} -G ${__gname} -D -h ${WORKSPACE_USER_HOME} ${__uname} \
    && mkdir -p \
      "${WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME}" \
      "${WORKSPACE_MAIN_REPO_HOME}" \
      "${WORKSPACE_MANAGED_REPOS_HOME}" \
      "${WORKSPACE_MOUNTED_SCRIPTS_HOME}" \
      "${WORKSPACE_USER_HOME}" \
    && chown -R ${__uid}:${__gid} "${__workspace_home}" \
    && git config --global --add safe.directory "${WORKSPACE_MAIN_REPO_HOME}"

    # Copy scripts into the image
COPY --chown=${__uid}:${__gid} scripts/ ${WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME}/

RUN chmod u+x ${WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME}/*.sh

USER ${__uname}

WORKDIR "${__workspace_home}"

# Note: WORKSPACE_USER_HOME is NOT declared as VOLUME
# Declaring it as VOLUME would reset ownership to root, causing permission issues
# Let docker-compose or runtime decide whether to mount it
VOLUME \
  "${WORKSPACE_MAIN_REPO_HOME}" \
  "${WORKSPACE_MANAGED_REPOS_HOME}" \
  "${WORKSPACE_MOUNTED_SCRIPTS_HOME}" \
  "${WORKSPACE_USER_HOME}"

## End Layer
