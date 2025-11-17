## Quick Start: SSH Agent & Utilities

### Using the SSH Agent
1. Ensure your SSH keys are present in your mounted home directory (e.g., `/workspace/home/dev/.ssh`).
2. On container start, if `/workspace/mnt/scripts/agent-init.sh` exists, it will be sourced automatically to start or load the SSH agent.
**Key concept:**
- The container is designed to work with a **read-only root filesystem**. All writable data (user home, repo, scripts) must be mounted as volumes.
- A dedicated directory or volume from the host should be mounted as the user's home directory inside the container (not just `.ssh`). This enables persistent user configuration, SSH keys, and other files. You do **not** need to mount your actual host home directory—use a dedicated directory or Docker volume for isolation and security.
  ```sh
  . /workspace/util/agent-init.sh
  ```sh
### Generating a New SSH Key
## Read-Only Root Filesystem Support

This image is built to support running with a read-only root filesystem. All writable paths (user home, main repo, scripts) should be mounted as Docker volumes or bind mounts. This improves security and makes the container stateless.

## Automatic Safe Git Directory

The main repository path `/workspace/mnt/this-repo` is automatically added as a safe Git directory at shell start. You do not need to configure this manually.

> **Tip:** If you mount additional repositories and need to use them with Git, you may need to add them as safe directories in your own startup scripts or manually:
> ```sh
> git config --global --add safe.directory "/path/to/your/other-repo"
> ```

## Writable Volume Requirements

Any directory where you expect to perform Git operations or write files (such as the user home, main repo, or scripts) **must** be mounted as a writable volume. The root filesystem is read-only by design.
Run inside the container:
```sh
/workspace/util/setup-ssh-key.sh "your.email@example.com"
```
This will create a new ed25519 SSH key in your home directory. Follow the prompts to set a passphrase and add the public key to your Git provider.

### Configuring Git User and Signing
Set the following environment variables (in your compose file or `.env`):
- `GIT_USER_NAME` (required)
- `GIT_USER_EMAIL` (required)

Then, inside the container, run:
```sh
/workspace/util/gitconfig.sh
```
This will configure your Git user, email, and enable SSH commit signing if a key is present.

---
# Git + SSH Client (Alpine-based)

**Key concept:** The container is intended to mount a dedicated directory or volume from the host as the user's home directory inside the container (not just `.ssh`). This enables persistent user configuration, SSH keys, and other files, and is especially useful for running with a read-only root filesystem. You do **not** need to mount your actual host home directory—use a dedicated directory or Docker volume for isolation and security.

## Features
  - `git`, `curl`, `openssh-client`, `mandoc`, `shellcheck`, `shunit2`

## Usage
### 6. Aliases and Environment

The following aliases are available to simplify common Git and SSH workflows, especially when sign-off and commit signing are required:

- `ll`: `ls -lah` — List files in long format
- `scommit`: `git commit -s` — Commit with sign-off
- `scommitg`: `git commit -S -s` — Commit with both GPG/SSH signing and sign-off
- `smerge`: `git merge --signoff` — Merge with sign-off
- `samend`: `git commit --amend -S -s` — Amend last commit with sign-off and signing
- `spush`: `git push --signed` — Push with signed refs (if supported)
- `slog`: `git log --show-signature` — Show commit signatures in log
- `srebase`: `git rebase --signoff` — Rebase with sign-off
- `sclone`: `git clone --config commit.gpgsign=true` — Clone and enforce signed commits
- Customizations in `/workspace/.ashrc`

### 2. Run the Container
Mount your code, scripts, and a **dedicated directory or Docker volume** as the user home:
```sh
  -v "$PWD/scripts:/workspace/mnt/scripts" \
  --read-only \
- `/workspace/mnt/this-repo`: Your main repo (host)
- `/workspace/home/dev`: Dedicated directory or Docker volume for user home (persistent)

### 3. SSH Agent Setup
The container auto-sources `/workspace/mnt/scripts/agent-init.sh` (if present) to start or load an SSH agent for Git operations.

### 4. Generate SSH Key (if needed)
Inside the container:
```sh
/workspace/util/setup-ssh-key.sh "your.email@example.com"
```

### 5. Configure Git User and Signing
Set environment variables (e.g., in `.env` or `docker-compose.yml`):
- `GIT_USER_NAME` (required)
- `GIT_USER_EMAIL` (required)

Then, inside the container:
```sh
/workspace/util/gitconfig.sh
```

- `/workspace/util/agent-init.sh`: SSH agent loader/initializer
- `/workspace/util/gitconfig.sh`: Git global config and signing setup
- `/workspace/util/setup-ssh-key.sh`: Generate new SSH key

## Volumes
- `/workspace/home/dev`: User home (persistent, mount a dedicated directory or Docker volume)
- `/workspace/mnt/this-repo`: Main repo mount
- `/workspace/mnt/scripts`: Custom scripts

## Example: Docker Compose
```yaml
services:
  git-ssh-client:
    image: my-git-ssh-client:latest
    volumes:
      - .:/workspace/mnt/this-repo
      - ./dev-home:/workspace/home/dev  # Use a dedicated directory or Docker volume
      - ./scripts:/workspace/mnt/scripts
    environment:
      - GIT_USER_NAME=Your Name
      - GIT_USER_EMAIL=your.email@example.com
    working_dir: /workspace
    user: dev
    read_only: true
```



## Notes
- The container runs as user `dev` by default.
- **Mount a dedicated directory or Docker volume** to `/workspace/home/dev` for persistent config, SSH keys, and compatibility with a read-only root filesystem. Do not mount your actual host home directory unless you explicitly want to.
- SSH agent and Git signing are optional but recommended for secure workflows.
- See scripts in `/workspace/util/` for more details and customization.

---

*Generated by GitHub Copilot synthesis.*
