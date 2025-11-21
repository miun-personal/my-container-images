ARG __build_image_tag=latest
FROM miunpersonal/ha3-git-guardian:${__build_image_tag}

ARG __gid=1001
ARG __gname=guardian
ARG __uid=1001
ARG __uname=guardian

ENV WORKSPACE_USER_HOME=${WORKSPACE_HOME}/mnt/home/ \
    WORKSPACE_MAIN_REPO_HOME=${WORKSPACE_HOME}/mnt/this-repo \
    WORKSPACE_MOUNTED_SCRIPTS_HOME=${WORKSPACE_HOME}/mnt/scripts \
    WORKSPACE_MANAGED_REPOS_HOME=${WORKSPACE_HOME}/mnt/repos \
    WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME=${WORKSPACE_HOME}/util

RUN addgroup -g ${__gid} ${__gname} \
    && adduser -u ${__uid} -G ${__gname} -D -h ${WORKSPACE_USER_HOME} ${__uname} \
    && mkdir -p \
      "${WORKSPACE_MAIN_REPO_HOME}" \
      "${WORKSPACE_MANAGED_REPOS_HOME}" \
      "${WORKSPACE_MOUNTED_SCRIPTS_HOME}" \
      "${WORKSPACE_USER_HOME}" \
    && chown -R ${__uid}:${__gid} "${WORKSPACE_HOME}" \
    && git config --global --add safe.directory "${WORKSPACE_MAIN_REPO_HOME}"

USER ${__uname}

WORKDIR "${WORKSPACE_HOME}"

VOLUME \
  "${WORKSPACE_MAIN_REPO_HOME}" \
  "${WORKSPACE_MANAGED_REPOS_HOME}" \
  "${WORKSPACE_MOUNTED_SCRIPTS_HOME}" \
  "${WORKSPACE_USER_HOME}"
