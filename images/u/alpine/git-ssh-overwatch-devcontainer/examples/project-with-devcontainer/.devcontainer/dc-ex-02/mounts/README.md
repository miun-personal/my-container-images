# Mounts Directory Structure

This directory contains persistent data for the devcontainer, organized by lifecycle:

## Directory Layout

```
mounts/
├── ssh/              # Long-lived: SSH keys and config
├── repos/            # Long-lived: Cloned repositories  
├── scripts/          # Long-lived: Custom scripts and CSV configs
└── user.home/        # DEPRECATED: No longer used (kept for migration)
```

## Lifecycle Separation

### Ephemeral (Docker Volume)
- **Location**: Docker volume `dc-ex-01_vscode-home`
- **Mounted to**: `/work/home/dev`
- **Contains**: VS Code Server, cache, temporary files (excluding .ssh)
- **Cleanup**: `docker volume rm dc-ex-01_vscode-home`
- **Backup**: Not needed (regenerated automatically)

### Persistent (Bind Mounts)
- **Location**: `./mounts/ssh/`
- **Mounted to**: `/work/home/dev/.ssh` (overlays the volume)
- **Contains**: SSH keys, known_hosts, config
- **Cleanup**: Manual only (your responsibility)
- **Backup**: Should be backed up or source-controlled (except private keys)

**How it works**: The home directory uses a Docker volume for VS Code cache, but SSH keys are bind-mounted directly over `~/.ssh`, giving you the best of both worlds.

## SSH Directory

The `ssh/` directory should contain:
- `id_ed25519` - Your private SSH key (NEVER commit this)
- `id_ed25519.pub` - Your public SSH key (safe to commit)
- `config` - SSH client configuration (safe to commit)
- `known_hosts` - Known host keys (auto-generated, safe to commit)
- `authorized_keys` - If needed for SSH server (safe to commit)

### Setting Up SSH Keys

**Option 1: Generate new keys inside container**
```bash
/work/util/setup-ssh-key.sh "your.email@example.com"
```

**Option 2: Copy existing keys**
```bash
# On host (Windows PowerShell):
cp ~/.ssh/id_ed25519* ./mounts/ssh/

# On host (Linux/Mac):
cp ~/.ssh/id_ed25519* ./mounts/ssh/
chmod 600 ./mounts/ssh/id_ed25519
chmod 644 ./mounts/ssh/id_ed25519.pub
```

**Option 3: Use ssh-agent forwarding** (advanced)
- See VS Code documentation for forwarding host SSH agent

## Repos Directory

Contains cloned repositories managed by `fetch-all` and related commands.

## Scripts Directory

Contains:
- `my-repos.csv` - Repository management configuration
- Custom shell scripts
- Other utilities

## Migration from user.home

If you have data in `user.home/`, move SSH keys:

```powershell
# Windows PowerShell
if (Test-Path ./mounts/user.home/.ssh) {
    Copy-Item -Recurse ./mounts/user.home/.ssh/* ./mounts/ssh/
}
```

Then you can safely delete `user.home/` directory - it's no longer used.

## Why This Structure?

**Problem**: VS Code stores cache/server in user home, but we also want persistent SSH keys. Windows bind mounts don't preserve Linux UIDs correctly.

**Solution**: 
- Docker named volume for `/work/home/dev` (VS Code cache with correct permissions)
- Bind mount overlays `~/.ssh` (SSH keys persist separately, backed up with project)

**Benefits**:
- ✅ Correct permissions - Docker volumes handle UID mapping automatically
- ✅ VS Code cache persists - Faster container restarts
- ✅ SSH keys separated - Won't be lost if volume is deleted
- ✅ Easy cleanup - `docker volume rm dc-ex-01_vscode-home` doesn't delete SSH keys
- ✅ Project backup - SSH keys (minus private keys) can be version-controlled
