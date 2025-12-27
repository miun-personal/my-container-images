# Git SSH Client DevContainer - Project Example

This example demonstrates a production-ready devcontainer setup with persistent SSH keys and optimized VS Code cache.

## Key Features

✅ **Named volume for home** - VS Code cache persists with correct permissions  
✅ **Bind-mounted SSH keys** - Long-lived SSH keys separate from ephemeral cache  
✅ **Windows-compatible** - Handles Windows UID mapping issues correctly  
✅ **Auto-cleanup** - Containers removed on close, volumes preserved  
✅ **Multi-repo support** - Manage multiple repositories with CSV configuration

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
            ├── ssh/                 # SSH keys (long-lived)
            ├── repos/               # Cloned repositories
            ├── scripts/             # Custom scripts
            └── README.md            # Mounts documentation
```

## Prerequisites

1. **VS Code** with **Dev Containers** extension
2. **Docker** (Docker Desktop, Rancher Desktop, or Podman Desktop)
3. **Built image**: `local/u/alpine/git-ssh-client:latest`

## Quick Start

### 1. Build the Image

```powershell
# From the git-ssh-client directory
cd m:\r\o\r\c\me\my-container-images\images\u\alpine\git-ssh-client
docker build -t local/u/alpine/git-ssh-client:latest .
```

### 2. Configure Environment

```powershell
cd examples\project-with-devcontainer\.devcontainer\dc-ex-01
cp .env.example .env
# Edit .env and set your Git name and email
```

### 3. Set Up SSH Keys

**Option A: Copy existing keys**
```powershell
mkdir -p mounts\ssh
cp ~\.ssh\id_ed25519* mounts\ssh\
```

**Option B: Generate keys in container** (after opening devcontainer)
```sh
/workspace/util/setup-ssh-key.sh "your.email@example.com"
cat ~/.ssh/id_ed25519.pub  # Copy this to GitHub/GitLab
```

### 4. Open in VS Code

1. Open folder: `examples\project-with-devcontainer`
2. Press `F1` → **Dev Containers: Reopen in Container**
3. Wait for container to start and VS Code Server to install

### 5. Configure Git (First Time)

```sh
/workspace/util/gitconfig.sh
```

## How It Works

### Volume Architecture

```
Docker Volume (dc-ex-01_vscode-home)
    └─> /workspace/home/dev/          # VS Code cache, history, config
         └─> .ssh/                     # Overlayed by bind mount ↓
              
Bind Mount (./mounts/ssh)
    └─> /workspace/home/dev/.ssh      # Your SSH keys (persistent)
```

**Key insight**: The home directory uses a Docker volume for performance and correct permissions, but SSH keys are bind-mounted over `~/.ssh` so they persist separately.

### Storage Lifecycle

| Location | Type | Lifecycle | Contains |
|----------|------|-----------|----------|
| `dc-ex-01_vscode-home` | Docker Volume | Ephemeral* | VS Code Server cache |
| `./mounts/ssh/` | Bind Mount | Persistent | SSH keys, config |
| `./mounts/repos/` | Bind Mount | Persistent | Cloned repositories |
| `./mounts/scripts/` | Bind Mount | Persistent | Custom scripts, CSV |

*Ephemeral means it can be deleted and recreated, not that it's automatically cleaned up.

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
git@github.com:user/repo1.git,/workspace/mnt/repos,repo1
git@github.com:user/repo2.git,/workspace/mnt/repos,repo2
```

2. Uncomment in `docker-compose.yml`:
```yaml
- ./mounts/scripts/my-repos.csv:/workspace/mnt/scripts/my-repos.csv:ro
```

3. Uncomment in `docker-compose.yml`:
```yaml
- MANAGED_REPOS_CSV=/workspace/mnt/scripts/my-repos.csv
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
# List keys
ls -la ~/.ssh/

# Test SSH connection
ssh -T git@github.com

# Start SSH agent and add key
. /workspace/util/agent-init.sh
ssh-add ~/.ssh/id_ed25519
```

### Git Operations

```sh
# Configure Git (first time)
/workspace/util/gitconfig.sh

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
# Remove containers (volumes preserved)
docker compose down

# Remove containers AND volumes
docker compose down -v

# Remove just the VS Code cache volume
docker volume rm dc-ex-01_vscode-home

# Keep SSH keys safe - they're in ./mounts/ssh/
```

### Rebuilding

```powershell
# Rebuild image
cd ..\..\..\..
docker build -t local/u/alpine/git-ssh-client:latest .

# Rebuild devcontainer
# In VS Code: F1 → Dev Containers: Rebuild Container
```

### Backup

**Critical data to backup:**
- `./mounts/ssh/id_ed25519` (private key) - **Keep secure!**
- `./mounts/ssh/config` (if customized)
- `./mounts/scripts/*.csv` (repo configurations)

**Optional to backup:**
- `./mounts/repos/` (cloned repos - can re-clone)
- `./mounts/ssh/id_ed25519.pub` (public key - can regenerate)

**Don't need to backup:**
- Docker volume `dc-ex-01_vscode-home` (VS Code cache)

## Troubleshooting

### Permission Denied Errors

```powershell
# Ensure image is rebuilt with latest Dockerfile
docker build -t local/u/alpine/git-ssh-client:latest .

# Remove old volumes
docker compose down -v
```

### SSH Keys Not Found

```sh
# Check if SSH mount is correct
ls -la ~/.ssh/
# Should show files from ./mounts/ssh/

# If empty, check docker-compose.yml mount:
# - ./mounts/ssh:/workspace/home/dev/.ssh:cached
```

### Git Config Missing

```sh
# Reconfigure
/workspace/util/gitconfig.sh

# Verify
git config --list --global
```

### Container Won't Start

```powershell
# Check logs
docker compose logs

# Try without VS Code
docker compose up -d
docker exec -it dc-ex-01-git-ssh-client-01-1 sh
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
✅ `mounts/ssh/config.example` - SSH config template  
✅ `mounts/ssh/id_ed25519.pub` - Public keys (if you want)  
✅ `mounts/scripts/*.csv` - Repo configurations  

### What to NEVER Commit

❌ `.env` - Contains your personal Git info  
❌ `mounts/ssh/id_ed25519` - Private SSH key  
❌ `mounts/ssh/known_hosts` - Host fingerprints (generated)  

### gitignore Setup

Already configured in `mounts/.gitignore`:
```gitignore
ssh/*
!ssh/.gitkeep
!ssh/config.example
```

## Performance Tips

1. **Use `:cached` mount option** - Already configured in docker-compose.yml
2. **Keep volume alive** - Don't use `docker compose down -v` unless needed
3. **SSH keys on SSD** - Store mounts/ on fast storage
4. **Limit repo clones** - Only clone repos you actively work on

## Differences from devcontainer-01

This example (`project-with-devcontainer`) differs from `devcontainer-01` in:

- ✅ More production-ready structure
- ✅ Named volume with explicit name
- ✅ SSH keys directly mounted (not symlinked)
- ✅ Better documentation
- ✅ Cleaner .gitignore setup
- ✅ More comprehensive examples

## References

- [Main README](../../../README.md)
- [Requirements Documentation](../../../REQUIREMENTS.md)
- [Mounts Documentation](./mounts/README.md)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review mounts/README.md for storage details
3. Check main project README.md
4. Review test results in `test/acceptance/windows/`
