#!/bin/sh
# gitconfig.sh - Configure git global settings for the user

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

printf "%b=== Git Global Configuration ===%b\n" "${GREEN}" "${NC}"
printf "\n"

# Validate inputs
if [ -z "${GIT_USER_NAME+x}" ] || [ -z "${GIT_USER_EMAIL+x}" ]; then
    printf "%bError: GIT_USER_NAME and GIT_USER_EMAIL environment variables must be set%b\n" "${RED}" "${NC}"
    printf "%bPlease set them in your docker-compose.yml or .env file%b\n" "${YELLOW}" "${NC}"
    exit 1
fi

printf "%bConfiguring git with:%b\n" "${YELLOW}" "${NC}"
printf "  User name: %s\n" "${GIT_USER_NAME}"
printf "  Email: %s\n" "${GIT_USER_EMAIL}"
printf "\n"

# Configure user name and email
git config --global user.name "${GIT_USER_NAME}"
git config --global user.email "${GIT_USER_EMAIL}"

# Configure commit signing (if key exists)
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    git config --global user.signingkey ~/.ssh/id_ed25519.pub
    
    # Create allowed_signers file if it doesn't exist
    if [ ! -f "$HOME/.ssh/allowed_signers" ]; then
        printf "%bCreating allowed_signers file...%b\n" "${YELLOW}" "${NC}"
        cp ~/.ssh/allowed_signers /tmp/ssh_allowed_signers
        echo "${GIT_USER_EMAIL} $(cat ~/.ssh/id_ed25519.pub)" > /tmp/ssh_allowed_signers
        cat /tmp/ssh_allowed_signers | sort | uniq  > ~/.ssh/allowed_signers
        rm /tmp/ssh_allowed_signers
    fi
    
    git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
    printf "%b[+] SSH signing configured%b\n" "${GREEN}" "${NC}"
else
    printf "%b! No SSH key found at %s - skipping signing config%b\n" "${YELLOW}" "$HOME/.ssh/id_ed25519.pub" "${NC}"
fi

git config --global commit.gpgsign true
git config --global core.autocrlf input
git config --global core.eol lf
git config --global core.filemode true
git config --global core.safecrlf warn
git config --global gpg.format=ssh

printf "\n"
printf "%bGit global configuration completed successfully!%b\n" "${GREEN}" "${NC}"
printf "\n"
printf "%b=== Configuration Summary ===%b\n" "${GREEN}" "${NC}"
printf "\n"
git config --global --list | grep -E "user\.|commit\.|gpg\.|format\." || true
printf "\n"
