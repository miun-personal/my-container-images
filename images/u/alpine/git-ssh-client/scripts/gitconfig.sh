#!/bin/sh
# gitconfig.sh - Configure git global settings for the user

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

printf "${GREEN}=== Git Global Configuration ===${NC}\n"
printf "\n"

# Get user name and email from environment variables
git_user_name="${GIT_USER_NAME}"
git_user_email="${GIT_USER_EMAIL}"

# Validate inputs
if [ -z "$git_user_name" ] || [ -z "$git_user_email" ]; then
    printf "${RED}Error: GIT_USER_NAME and GIT_USER_EMAIL environment variables must be set${NC}\n"
    printf "${YELLOW}Please set them in your docker-compose.yml or .env file${NC}\n"
    exit 1
fi

printf "${YELLOW}Configuring git with:${NC}\n"
printf "  User name: %s\n" "$git_user_name"
printf "  Email: %s\n" "$git_user_email"
printf "\n"

# Configure user name and email
git config --global user.name "$git_user_name"
git config --global user.email "$git_user_email"

# Configure commit signing (if key exists)
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    git config --global user.signingkey ~/.ssh/id_ed25519.pub
    
    # Create allowed_signers file if it doesn't exist
    if [ ! -f "$HOME/.ssh/allowed_signers" ]; then
        printf "${YELLOW}Creating allowed_signers file...${NC}\n"
        echo "$git_user_email $(cat ~/.ssh/id_ed25519.pub)" > ~/.ssh/allowed_signers
    fi
    
    git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
    printf "${GREEN}[+] SSH signing configured${NC}\n"
else
    printf "${YELLOW}! No SSH key found at ~/.ssh/id_ed25519.pub - skipping signing config${NC}\n"
fi

printf "\n"
printf "${GREEN}Git global configuration completed successfully!${NC}\n"
printf "\n"
printf "${GREEN}=== Configuration Summary ===${NC}\n"
printf "\n"
git config --global --list | grep -E "user\.|commit\.|gpg\.|format\." || true
printf "\n"
