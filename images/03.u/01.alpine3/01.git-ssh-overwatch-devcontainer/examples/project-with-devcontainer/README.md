# Git SSH Overwatch DevContainer - Project Example

This example demonstrates a production-ready devcontainer setup for the **overwatch-devcontainer** variant, which keeps the user home directory writable within the container.

## Key Differences from git-ssh-client

This devcontainer variant differs from the standard `git-ssh-client`:

- ❌ **No read-only filesystem support** - Container filesystem is writable
- ✅ **User home is writable** - SSH keys persist in container filesystem
- ✅ **Simpler volume setup** - No need to mount user home directory
- ✅ **Devcontainer optimized** - Designed for VS Code devcontainer workflows
- ✅ **Ephemeral by design** - Container state can be recreated easily

## Key Features

✅ **SSH keys in container** - Stored in writable container filesystem  
✅ **Windows-compatible** - No UID mapping issues  
✅ **Auto-cleanup** - Containers removed on close  
✅ **Multi-repo support** - Manage multiple repositories with CSV configuration  
✅ **Simple setup** - Fewer volume mounts needed

## Structure

```
project-with-devcontainer/
└── .devcontainer/
    └── dc-ex-01/
        ├── devcontainer.json        # VS Code configuration
        ├── docker-compose.yml       # Container definition
        ├── .env                     # Environment variables (create from .env.example)
        ├── .env.example             # Template for environment variables
        └── mounts/                  # Persistent data
            ├── repos/               # Cloned repositories
            ├── scripts/             # Custom scripts
            └── README.md            # Mounts documentation
```

## Prerequisites

1. **VS Code** with **Dev Containers** extension
2. **Docker** (Docker Desktop, Rancher Desktop, or Podman Desktop)
3. **Built image**: `local/u/alpine/git-ssh-overwatch-devcontainer:latest`

## Quick Start

### 1. Build the Image

```powershell
# From the git-ssh-overwatch-devcontainer directory
cd m:\r\o\r\c\me\my-container-images\images\u\alpine\git-ssh-overwatch-devcontainer
docker build -t local/u/alpine/git-ssh-overwatch-devcontainer:latest .
```

### 2. Configure Environment

```powershell
cd examples\project-with-devcontainer\.devcontainer\dc-ex-01
cp .env.example .env
# Edit .env and set your Git name and email
```

### 3. Open in VS Code

1. Open folder: `examples\project-with-devcontainer`
2. Press `F1` → **Dev Containers: Reopen in Container**
3. Wait for container to start and VS Code Server to install

### 4. Generate SSH Keys (First Time)

Inside the container:
```sh
/work/util/setup-ssh-key.sh "your.email@example.com"
cat ~/.ssh/id_ed25519.pub  # Copy this to GitHub/GitLab
```

### 5. Configure Git (First Time)

```sh
/work/util/gitconfig.sh
```

## How It Works

### Storage Architecture

```
/work/home/dev/          # Writable in container filesystem
    ├── .ssh/                 # SSH keys stored here
    ├── .gitconfig            # Git configuration
    └── .ash_history          # Shell history

/work/mnt/this-repo      # Bind mount to host
/work/mnt/repos          # Bind mount to host  
/work/mnt/scripts        # Bind mount to host
```

**Key insight**: The user home directory is writable within the container's filesystem. SSH keys and configuration persist in the container, not on the host. This is suitable for devcontainer workflows where you can regenerate the container as needed.

### Storage Lifecycle

| Location | Type | Lifecycle | Contains |
|----------|------|-----------|----------|
| `/work/home/dev/` | Container FS | Ephemeral | SSH keys, Git config, history |
| `./mounts/repos/` | Bind Mount | Persistent | Cloned repositories |
| `./mounts/scripts/` | Bind Mount | Persistent | Custom scripts, CSV |
| `/work/mnt/this-repo` | Bind Mount | Persistent | Main project repository |

**Important**: SSH keys are stored in the container filesystem and will be lost if the container is recreated. This is by design for devcontainer workflows. If you need persistent keys, use the standard `git-ssh-client` variant instead.

## Configuration

### Git User Settings

Edit `.env`:
```env
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=your.email@example.com
```

### Multi-Repository Management

1. Create `mounts/scripts/my-repos.csv`:
```csv
url,path,name
git@github.com:user/repo1.git,/work/mnt/repos,repo1
git@github.com:user/repo2.git,/work/mnt/repos,repo2
```

2. Uncomment in `docker-compose.yml`:
```yaml
- ./mounts/scripts/my-repos.csv:/work/mnt/scripts/my-repos.csv:ro
```

3. Uncomment in `docker-compose.yml`:
```yaml
- MANAGED_REPOS_CSV=/work/mnt/scripts/my-repos.csv
```

4. In container:
```sh
fetch-all  # Clone/update all repos
list-all-repos
show-all-local-changes
```

## Common Tasks

### Managing SSH Keys

```sh
# Generate new key (first time)
/work/util/setup-ssh-key.sh "your.email@example.com"

# List keys
ls -la ~/.ssh/

# Test SSH connection
ssh -T git@github.com

# Start SSH agent and add key
. /work/util/agent-init.sh
ssh-add ~/.ssh/id_ed25519
```

### Git Operations

```sh
# Configure Git (first time)
/work/util/gitconfig.sh

# Signed commits (aliases)
scommit -m "message"      # Sign-off
scommitg -m "message"     # GPG/SSH sign + sign-off
samend                    # Amend with signing
spush                     # Push with signed refs
```

### Managing Repositories

```sh
# Fetch all managed repos
fetch-all

# List all repos
list-all-repos

# Show repos with changes
show-all-local-changes

# Status of specific repo
repo-status my-repo
```

## Maintenance

### Cleanup Commands

```powershell
# Remove containers (repositories preserved)
docker compose down

# Keep in mind: SSH keys in container will be lost on recreate
# Repositories in ./mounts/repos/ are safe
```

### Rebuilding

```powershell
# Rebuild image
cd ..\..\..\..
docker build -t local/u/alpine/git-ssh-overwatch-devcontainer:latest .

# Rebuild devcontainer
# In VS Code: F1 → Dev Containers: Rebuild Container
# Note: You'll need to regenerate SSH keys after rebuild
```

### Backup

**Critical data to backup:**
- `./mounts/repos/` (cloned repositories)
- `./mounts/scripts/*.csv` (repo configurations)

**Optional to backup (if you extract from container):**
- `/work/home/dev/.ssh/id_ed25519` (private key from container)
- `/work/home/dev/.ssh/config` (SSH config from container)

**Note**: SSH keys are in the container filesystem. To back them up, you need to copy them out:
```sh
# Inside container
cat ~/.ssh/id_ed25519.pub  # Copy public key
# For private key, use secure method like docker cp
```

```powershell
# From host (container must be running)
docker cp <container-name>:/work/home/dev/.ssh ./backup/
```

## Troubleshooting

### SSH Keys Lost After Rebuild

This is expected behavior. SSH keys are stored in the container filesystem and are lost when the container is recreated. Either:
1. Regenerate keys: `/work/util/setup-ssh-key.sh "your.email@example.com"`
2. Copy keys back in from backup
3. Use the standard `git-ssh-client` variant if you need persistent keys

### Git Config Missing

```sh
# Reconfigure
/work/util/gitconfig.sh

# Verify
git config --list --global
```

### Container Won't Start

```powershell
# Check logs
docker compose logs

# Try without VS Code
docker compose up -d
docker exec -it dc-ex-01-git-ssh-devcontainer-01-1 sh
```

## VS Code Customization

### Extensions

Edit `devcontainer.json`:
```json
"customizations": {
  "vscode": {
    "extensions": [
      "eamodio.gitlens",
      "timonwong.shellcheck",
      "your-extension-id"
    ]
  }
}
```

### Settings

```json
"customizations": {
  "vscode": {
    "settings": {
      "terminal.integrated.defaultProfile.linux": "sh",
      "git.enableCommitSigning": true
    }
  }
}
```

## Security Considerations

### What's Safe to Commit

✅ `docker-compose.yml` - Container configuration  
✅ `devcontainer.json` - VS Code configuration  
✅ `.env.example` - Template for environment variables  
✅ `mounts/scripts/*.csv` - Repo configurations  

### What to NEVER Commit

❌ `.env` - Contains your personal Git info  
❌ SSH keys if you back them up to mounts/  

### gitignore Setup

Configured in `mounts/.gitignore`:
```gitignore
ssh/*
```

## Performance Tips

1. **Use `:cached` mount option** - Already configured in docker-compose.yml
2. **SSH keys in container** - No I/O overhead for key access
3. **Limit repo clones** - Only clone repos you actively work on

## When to Use This vs git-ssh-client

Use **git-ssh-overwatch-devcontainer** when:
- ✅ You're using VS Code devcontainers
- ✅ You're okay regenerating SSH keys when rebuilding
- ✅ You want simpler volume mount setup
- ✅ You don't need read-only filesystem security

Use **git-ssh-client** when:
- ✅ You need persistent SSH keys across rebuilds
- ✅ You require read-only root filesystem
- ✅ You're running in production environments
- ✅ You need maximum security

## References

- [Main README](../../../README.md)
- [Requirements Documentation](../../../REQUIREMENTS.md)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Check main project README.md
3. Review test results in `test/acceptance/windows/`
4. Compare with standard `git-ssh-client` if needed
