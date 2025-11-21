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
DEFAULT_EMAIL="${GIT_USER_EMAIL:-dev@example.com}"
EMAIL="${1:-$DEFAULT_EMAIL}"

printf "\n"
printf "%b=== SSH Key Generation for Run Configuration ===%b\n" "${BLUE}" "${NC}"
printf "\n"

SSH_DIR="$HOME/.ssh"

mkdir -p "${SSH_DIR}"

KEY_FILE="${SSH_DIR}/id_ed25519"

printf "%bSSH Directory: %s%b\n" "${YELLOW}" "${SSH_DIR}" "${NC}"
printf "%bEmail: %s%b\n" "${YELLOW}" "${EMAIL}" "${NC}"
printf "\n"

# Check if key already exists
if [ -f "$KEY_FILE" ]; then
    printf "%bWARNING: Key already exists at %s%b\n" "${YELLOW}" "${KEY_FILE}" "${NC}"
    printf "%bDo you want to:\n%b" "${YELLOW}" "${NC}"
    printf "  1) Backup and replace\n"
    printf "  2) Cancel\n"
    read -r choice
    
    case $choice in
        1)
            BACKUP_DIR="${SSH_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            mv "${KEY_FILE}" "${BACKUP_DIR}/"
            mv "${KEY_FILE}.pub" "${BACKUP_DIR}/" 2>/dev/null || true
            printf "%b[+] Backed up old key to %s%b\n" "${GREEN}" "${BACKUP_DIR}" "${NC}"
            ;;
        *)
            printf "%bCancelled%b\n" "${RED}" "${NC}"
            exit 0
            ;;
    esac
fi

printf "\n"
printf "%bGenerating new ed25519 SSH key...%b\n" "${GREEN}" "${NC}"
printf "%bYou will be prompted for a passphrase - use a strong one!%b\n" "${YELLOW}" "${NC}"
printf "\n"

# Generate the key
ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_FILE"

if [ $? -eq 0 ]; then
    printf "\n"
    printf "%b[+] SSH key generated successfully!%b\n" "${GREEN}" "${NC}"
    printf "\n"
    printf "%b=== Next Steps ===%b\n" "${BLUE}" "${NC}"
    printf "\n"
    printf "1. %bAdd your public key to GitHub/GitLab:%b\n" "${YELLOW}" "${NC}"
    printf "   cat %s.pub\n" "${KEY_FILE}"
    printf "\n"
    printf "2. %bConfigure git user settings:%b\n" "${YELLOW}" "${NC}"
    printf "   Create a .env file from .env.example and set:\n"
    printf "   GIT_USER_NAME=\"Your Name\"\n"
    printf "   GIT_USER_EMAIL=\"%s\"\n" "${EMAIL}"
    printf "\n"
    printf "3. %bAfter starting the container, add your key to the agent:%b\n" "${YELLOW}" "${NC}"
    printf "   ssh-add ~/.ssh/id_ed25519\n"
    printf "\n"
    printf "4. %bConfigure git signing (run from container):%b\n" "${YELLOW}" "${NC}"
    printf "   ~/s/gitconfig.sh\n"
    printf "\n"
    printf "%bYour public key:%b\n" "${GREEN}" "${NC}"
    cat "${KEY_FILE}.pub"
    printf "\n"
else
    printf "%b[-] Failed to generate SSH key%b\n" "${RED}" "${NC}"
    exit 1
fi
