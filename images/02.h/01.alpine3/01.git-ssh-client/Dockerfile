ARG __build_image_tag=latest
FROM miunpersonal/sa3-git-ssh-client:${__build_image_tag}

ARG __workspace_home=/work

ENV WORKSPACE_HOME=${__workspace_home} \
    ENV=${__workspace_home}/.ashrc \
    WORKSPACE_IMAGE_PROVIDED_SCRIPTS_HOME=${__workspace_home}/util

RUN mkdir -p "${__workspace_home}/util"

COPY ./.ashrc ${__workspace_home}/.ashrc
COPY ./scripts/ "${__workspace_home}/util"/

RUN chmod -R a+r ${__workspace_home} \
    && chmod a+x "${__workspace_home}/util"/*.sh
