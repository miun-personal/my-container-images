#!/bin/sh
# Initialize ssh-agent, ensure it does not write into the rootfs
# shellcheck disable=SC1090,SC1091
SSH_ENV_DIR="/dev/shm/ssh-agent-dir-$(id -u)-$$"
SSH_ENV="${SSH_ENV_DIR}/.env"

agent_load_env() {
    [ -f "${SSH_ENV}" ] && . "${SSH_ENV}" >/dev/null 2>&1
}

agent_start() {
    mkdir -p "${SSH_ENV_DIR}"
    (umask 077; TMPDIR="${SSH_ENV_DIR}" ssh-agent 2>/dev/null | sed 's/^echo/#echo/' > "${SSH_ENV}")
    [ -f "${SSH_ENV}" ] && . "${SSH_ENV}" >/dev/null 2>&1
}

# Load existing agent environment
agent_load_env

# Check if agent is running and accessible
if ! ssh-add -l >/dev/null 2>&1; then
    # Agent not running or not accessible, start a new one
    agent_start
fi
