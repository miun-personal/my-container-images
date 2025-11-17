#!/bin/sh
# setup-ssh-key.sh - Generate new ed25519 SSH key with passphrase
#
# Usage: ./setup-ssh-key.sh [email]
#
# This script generates a new ed25519 SSH key pair in the current directory's
# .ssh folder (or ~/.ssh if run from container) with a passphrase.

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default email
DEFAULT_EMAIL="dev@example.com"
EMAIL="${1:-$DEFAULT_EMAIL}"

printf "\n"
printf "${BLUE}=== SSH Key Generation for Run Configuration ===${NC}\n"
printf "\n"

# Determine SSH directory
if [ -d "$HOME/.ssh" ]; then
    SSH_DIR="$HOME/.ssh"
else
    SSH_DIR="$(pwd)/.ssh"
fi

KEY_FILE="${SSH_DIR}/id_ed25519"

printf "${YELLOW}SSH Directory: ${SSH_DIR}${NC}\n"
printf "${YELLOW}Email: ${EMAIL}${NC}\n"
printf "\n"

# Check if key already exists
if [ -f "$KEY_FILE" ]; then
    printf "${YELLOW}WARNING: Key already exists at ${KEY_FILE}${NC}\n"
    printf "${YELLOW}Do you want to:\n"
    printf "  1) Backup and replace\n"
    printf "  2) Cancel${NC}\n"
    read -r choice
    
    case $choice in
        1)
            BACKUP_DIR="${SSH_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            mv "${KEY_FILE}" "${BACKUP_DIR}/"
            mv "${KEY_FILE}.pub" "${BACKUP_DIR}/" 2>/dev/null || true
            printf "${GREEN}[+] Backed up old key to ${BACKUP_DIR}${NC}\n"
            ;;
        *)
            printf "${RED}Cancelled${NC}\n"
            exit 0
            ;;
    esac
fi

printf "\n"
printf "${GREEN}Generating new ed25519 SSH key...${NC}\n"
printf "${YELLOW}You will be prompted for a passphrase - use a strong one!${NC}\n"
printf "\n"

# Generate the key
ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_FILE"

if [ $? -eq 0 ]; then
    printf "\n"
    printf "${GREEN}[+] SSH key generated successfully!${NC}\n"
    printf "\n"
    printf "${BLUE}=== Next Steps ===${NC}\n"
    printf "\n"
    printf "1. ${YELLOW}Add your public key to GitHub/GitLab:${NC}\n"
    printf "   cat ${KEY_FILE}.pub\n"
    printf "\n"
    printf "2. ${YELLOW}Configure git user settings:${NC}\n"
    printf "   Create a .env file from .env.example and set:\n"
    printf "   GIT_USER_NAME=\"Your Name\"\n"
    printf "   GIT_USER_EMAIL=\"$EMAIL\"\n"
    printf "\n"
    printf "3. ${YELLOW}After starting the container, add your key to the agent:${NC}\n"
    printf "   ssh-add ~/.ssh/id_ed25519\n"
    printf "\n"
    printf "4. ${YELLOW}Configure git signing (run from container):${NC}\n"
    printf "   ~/s/gitconfig.sh\n"
    printf "\n"
    printf "${GREEN}Your public key:${NC}\n"
    cat "${KEY_FILE}.pub"
    printf "\n"
else
    printf "${RED}[-] Failed to generate SSH key${NC}\n"
    exit 1
fi
