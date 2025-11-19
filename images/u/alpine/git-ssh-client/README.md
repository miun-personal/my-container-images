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

- **Core Tools**: `git`, `curl`, `openssh-client`, `mandoc`, `shellcheck`, `shunit2`
- **SSH Agent Management**: Automatic SSH agent initialization and key management
- **Git Signing**: SSH-based commit and tag signing support
- **Multi-Repository Management**: Manage multiple repositories with unified commands
- **Read-Only Filesystem**: Compatible with read-only root filesystem for enhanced security
- **DCO Compliance**: Built-in aliases for sign-off workflows

## Usage
### 6. Multi-Repository Management

The container includes powerful multi-repository management functions:

#### Available Commands

- **`fetch-all`**: Clone and fetch all repositories
  - Processes repositories from CSV file (if `MANAGED_REPOS_CSV` is set)
  - Updates all existing repositories under `/workspace/mnt/repos`
  - Updates the main repository at `/workspace/mnt/this-repo`

- **`show-all-local-changes`**: Display all repositories with local changes
  - Shows uncommitted changes (staged, unstaged, untracked)
  - Shows commits ahead/behind upstream
  - Displays merge conflicts
  - Tabular format for easy scanning

- **`list-all-repos`**: List all known repositories
  - Shows repository name and path
  - Includes main repo and all managed repos

- **`repo-status <name>`**: Show detailed Git status for a specific repository
  - Full `git status` output
  - Useful for drilling down into specific repos

#### Setting Up Managed Repositories

1. Create a CSV file with your repositories (see `scripts/managed-repos-example.csv`):
   ```csv
   url,path,name
   git@github.com:user/my-repo.git,/workspace/mnt/repos,my-repo
   git@github.com:org/work-repo.git,/workspace/mnt/repos/work,work-repo
   ```

   The CSV format is:
   - `url`: Git repository URL (SSH or HTTPS)
   - `path`: Absolute parent directory where the repo will be cloned
   - `name`: Repository directory name (repo will be at `path/name`)

2. Set the environment variable:
   ```yaml
   environment:
     - MANAGED_REPOS_CSV=/workspace/mnt/scripts/my-repos.csv
   ```

3. Mount the CSV file and repos directory:
   ```yaml
   volumes:
     - ./my-repos.csv:/workspace/mnt/scripts/my-repos.csv
     - ./repos:/workspace/mnt/repos
   ```

4. Inside the container, run:
   ```sh
   fetch-all
   ```

All repositories in the CSV will be processed and cloned/updated.

### 7. Aliases and Environment

The following aliases are available to simplify common Git and SSH workflows:

**Git Signing Aliases:**
- `scommit`: `git commit -s` — Commit with sign-off
- `scommitg`: `git commit -S -s` — Commit with both GPG/SSH signing and sign-off
- `smerge`: `git merge --signoff` — Merge with sign-off
- `samend`: `git commit --amend -S -s` — Amend last commit with sign-off and signing
- `spush`: `git push --signed` — Push with signed refs
- `slog`: `git log --show-signature` — Show commit signatures in log
- `srebase`: `git rebase --signoff` — Rebase with sign-off
- `sclone`: `git clone --config commit.gpgsign=true` — Clone and enforce signed commits

**General Aliases:**
- `ll`: `ls -lah` — List files in long format

**Environment:**
- Customizations in `/workspace/.ashrc`
- Auto-loaded SSH agent
- Auto-loaded repository utilities

### 2. Run the Container
Mount your code, scripts, and a **dedicated directory or Docker volume** as the user home:
```sh
docker run -it --rm \
  -v "$PWD:/workspace/mnt/this-repo" \
  -v "$PWD/../repos:/workspace/mnt/repos" \
  -v "$PWD/dev-home:/workspace/home/dev" \
  -v "$PWD/scripts:/workspace/mnt/scripts" \
  --read-only \
  my-git-ssh-client:latest
```

**Key Mount Points:**
- `/workspace/mnt/this-repo`: Your main repo (typically the one opening the devcontainer)
- `/workspace/mnt/repos`: Base directory for additional managed repositories
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
- `/workspace/util/repo-utils.sh`: Multi-repository management library (auto-loaded)

## Volumes
- `/workspace/home/dev`: User home (persistent, mount a dedicated directory or Docker volume)
- `/workspace/mnt/this-repo`: Main repository mount (typically the devcontainer repo)
- `/workspace/mnt/repos`: Managed repositories base directory
- `/workspace/mnt/scripts`: Custom scripts mount point

## Example: Docker Compose

### Basic Setup
```yaml
services:
  git-ssh-client:
    image: my-git-ssh-client:latest
    volumes:
      - .:/workspace/mnt/this-repo
      - ./dev-home:/workspace/home/dev  # Use a dedicated directory or Docker volume
      - ./scripts:/workspace/mnt/scripts
      - ./repos:/workspace/mnt/repos
    environment:
      - GIT_USER_NAME=Your Name
      - GIT_USER_EMAIL=your.email@example.com
    working_dir: /workspace
    user: dev
    read_only: true
```

### With Managed Repositories
```yaml
services:
  git-ssh-client:
    image: my-git-ssh-client:latest
    volumes:
      - .:/workspace/mnt/this-repo
      - ./dev-home:/workspace/home/dev
      - ./scripts:/workspace/mnt/scripts
      - ./repos:/workspace/mnt/repos
      - ./my-repos.csv:/workspace/mnt/scripts/my-repos.csv:ro
    environment:
      - GIT_USER_NAME=Your Name
      - GIT_USER_EMAIL=your.email@example.com
      - MANAGED_REPOS_CSV=/workspace/mnt/scripts/my-repos.csv
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
