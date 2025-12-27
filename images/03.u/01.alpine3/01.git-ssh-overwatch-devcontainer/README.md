# Git + SSH Devcontainer (Alpine-based)

**Purpose:** This image is designed specifically for use as a VS Code devcontainer or similar development environment. Unlike the standard `git-ssh-client`, this variant does **not** require a read-only root filesystem and keeps the user home directory writable within the container's root filesystem. This aligns with typical devcontainer workflows where the container filesystem is treated as ephemeral and development state is managed through the primary repository mount.

## Features

- **Core Tools**: `git`, `curl`, `openssh-client`, `mandoc`, `shellcheck`, `shunit2`
- **SSH Agent Management**: Automatic SSH agent initialization and key management
- **Git Signing**: SSH-based commit and tag signing support
- **Multi-Repository Management**: Manage multiple repositories with unified commands
- **Devcontainer Optimized**: User home directory is writable in the container filesystem
- **DCO Compliance**: Built-in aliases for sign-off workflows

## Devcontainer-Specific Design

This variant is optimized for VS Code devcontainer workflows:
- **User home directory is writable** in the container filesystem (not mounted as a volume)
- **No read-only filesystem requirement** - the container filesystem is writable
- SSH keys and Git configuration persist in the container's `/workspace/home/dev`
- Focus is on the main repository mount at `/workspace/mnt/this-repo`
- Ideal for development workflows where container state is ephemeral

## Usage

### 1. Build the Image
```sh
docker build -t my-git-ssh-devcontainer:latest .
```

### 2. Run the Container
Mount your code and optional scripts:
```sh
docker run -it --rm \
  -v "$PWD:/workspace/mnt/this-repo" \
  -v "$PWD/../repos:/workspace/mnt/repos" \
  -v "$PWD/scripts:/workspace/mnt/scripts" \
  my-git-ssh-devcontainer:latest
```

**Key Mount Points:**
- `/workspace/mnt/this-repo`: Your main repo (typically the one opening the devcontainer)
- `/workspace/mnt/repos`: Base directory for additional managed repositories
- `/workspace/mnt/scripts`: Optional custom scripts mount point
- `/workspace/home/dev`: User home (writable in container, **not** mounted)

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

## Automatic Safe Git Directory

The main repository path `/workspace/mnt/this-repo` is automatically added as a safe Git directory at shell start. You do not need to configure this manually.

> **Tip:** If you mount additional repositories and need to use them with Git, you may need to add them as safe directories in your own startup scripts or manually:
> ```sh
> git config --global --add safe.directory "/path/to/your/other-repo"
> ```

## Multi-Repository Management

The container includes powerful multi-repository management functions:

### Available Commands

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

### Setting Up Managed Repositories

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

## Aliases and Environment

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

## Utility Scripts

- `/workspace/util/agent-init.sh`: SSH agent loader/initializer
- `/workspace/util/gitconfig.sh`: Git global config and signing setup
- `/workspace/util/setup-ssh-key.sh`: Generate new SSH key
- `/workspace/util/repo-utils.sh`: Multi-repository management library (auto-loaded)

## Volumes

- `/workspace/home/dev`: User home (writable in container, **not** declared as VOLUME)
- `/workspace/mnt/this-repo`: Main repository mount (typically the devcontainer repo)
- `/workspace/mnt/repos`: Managed repositories base directory
- `/workspace/mnt/scripts`: Custom scripts mount point

## Example: Docker Compose

### Basic Setup
```yaml
services:
  git-ssh-devcontainer:
    image: my-git-ssh-devcontainer:latest
    volumes:
      - .:/workspace/mnt/this-repo
      - ./scripts:/workspace/mnt/scripts
      - ./repos:/workspace/mnt/repos
    environment:
      - GIT_USER_NAME=Your Name
      - GIT_USER_EMAIL=your.email@example.com
    working_dir: /workspace
    user: dev
```

### With Managed Repositories
```yaml
services:
  git-ssh-devcontainer:
    image: my-git-ssh-devcontainer:latest
    volumes:
      - .:/workspace/mnt/this-repo
      - ./scripts:/workspace/mnt/scripts
      - ./repos:/workspace/mnt/repos
      - ./my-repos.csv:/workspace/mnt/scripts/my-repos.csv:ro
    environment:
      - GIT_USER_NAME=Your Name
      - GIT_USER_EMAIL=your.email@example.com
      - MANAGED_REPOS_CSV=/workspace/mnt/scripts/my-repos.csv
    working_dir: /workspace
    user: dev
```

## Notes

- The container runs as user `dev` by default.
- User home directory (`/workspace/home/dev`) is **writable in the container** and not mounted as a volume by default.
- This variant is optimized for devcontainer workflows and does **not** support read-only root filesystem.
- For production use with read-only filesystem, use the standard `git-ssh-client` image instead.
- SSH agent and Git signing are optional but recommended for secure workflows.
- See scripts in `/workspace/util/` for more details and customization.

---
