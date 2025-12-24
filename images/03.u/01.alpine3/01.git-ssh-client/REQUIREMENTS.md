# Requirements for git-ssh-client

## Purpose

The `git-ssh-client` container image provides a minimal, secure, and reproducible Alpine Linux-based environment for performing Git operations with SSH authentication. This image is designed to support development workflows that require:

- Git operations with SSH key-based authentication
- Commit and tag signing using SSH keys (GPG.SSH format)
- Stateless container execution with read-only root filesystem support
- Persistent user configuration through volume mounts
- Automated SSH agent management for secure key handling

## Primary Use Cases

1. **Development Container**: Run as a devcontainer or interactive development environment for Git-based projects
2. **CI/CD Pipeline**: Execute Git operations in automated workflows with SSH authentication
3. **Secure Git Operations**: Perform Git operations in an isolated environment with signing and sign-off requirements
4. **Multi-Repository Management**: Manage and synchronize multiple Git repositories from a single container
5. **Repository Monitoring**: Track local changes across multiple repositories with unified reporting

## Target Users

- Developers requiring signed commits and secure SSH authentication
- Organizations enforcing commit signing and sign-off policies (e.g., DCO compliance)
- DevOps engineers managing Git operations in containerized environments
- Users requiring isolated Git environments with reproducible tooling

## Functional Requirements

### FR-1: Version-Pinned Base and Components

**All software components must use explicit version numbers.**

- Base image: `alpine:3.22` (or specific patch version)
- Package versions must be explicitly declared:
  - `curl`
  - `git`
  - `mandoc`
  - `openssh-client`
  - `shellcheck`
  - `shunit2`
- No `latest` tags or version wildcards permitted

### FR-2: Non-Root User Execution

**The container must run as a non-root user by default.**

- Default user: `dev` (UID: 888)
- Default group: `dev` (GID: 888)
- User home directory: `/workspace/home/dev`
- All user-owned directories must have proper permissions

### FR-3: Workspace Organization

**The container must provide a structured workspace with defined mount points.**

Directory|Purpose|Writable
-|-|-
`/workspace/home/dev`|User home directory (SSH keys, Git config)|Yes (volume)
`/workspace/mnt/this-repo`|Primary repository mount point (typically opened devcontainer)|Yes (volume)
`/workspace/mnt/repos`|Managed repositories base directory|Yes (volume)
`/workspace/mnt/scripts`|Custom user scripts mount point|Yes (volume)
`/workspace/util`|Container-provided utility scripts|No (image)
`/workspace/.ashrc`|Shell environment configuration|No (image)

### FR-4: SSH Agent Management

**The container must provide automated SSH agent initialization.**

- Auto-source `/workspace/mnt/scripts/agent-init.sh` if present during shell startup
- Provide built-in `/workspace/util/agent-init.sh` script for SSH agent management
- Support persistent SSH agent across multiple shell sessions
- Store agent environment in `/dev/shm` for security

### FR-5: Git Configuration Management

**The container must support automated Git global configuration.**

Required environment variables:
- `GIT_USER_NAME`: User's full name for Git commits
- `GIT_USER_EMAIL`: User's email address for Git commits

Configuration script (`/workspace/util/gitconfig.sh`) must:
- Set global `user.name` and `user.email`
- Configure SSH commit signing if SSH key exists
- Create and maintain `~/.ssh/allowed_signers` file
- Enable commit signing by default (`commit.gpgsign=true`)
- Configure Git for Unix line endings
- Set GPG format to SSH

### FR-6: SSH Key Management

**The container must provide tools for SSH key generation.**

Script: `/workspace/util/setup-ssh-key.sh`

Requirements:
- Generate ed25519 SSH keys
- Support passphrase-protected keys
- Accept email address as parameter
- Backup existing keys before replacement
- Display clear next-steps instructions

### FR-7: Git Workflow Aliases

**The container must provide convenience aliases for signed Git operations.**

Required aliases (defined in `/workspace/.ashrc`):
- `ll`: List files in long format
- `scommit`: Commit with DCO sign-off
- `scommitg`: Commit with signing and sign-off
- `smerge`: Merge with sign-off
- `samend`: Amend with signing and sign-off
- `spush`: Push with signed refs
- `slog`: Show commit signatures in log
- `srebase`: Rebase with sign-off
- `sclone`: Clone with signing enabled

### FR-7.1: Multi-Repository Management Functions

**The container must provide shell functions for managing multiple repositories.**

Required functions (provided by `/workspace/util/repo-utils.sh`):
- `fetch-all`: Clone/fetch all managed repositories (from CSV and existing)
- `show-all-local-changes`: Display repositories with uncommitted changes or unpushed commits
- `list-all-repos`: List all known repositories
- `repo-status <name>`: Show detailed Git status for a specific repository

Environment variables:
- `MANAGED_REPOS_CSV`: Optional path to CSV file defining repositories to manage
- `REPOS_BASE_DIR`: Base directory for managed repos (default: `/workspace/mnt/repos`)

CSV Format (url,path,name):
```csv
url,path,name
git@github.com:miun-personal/my-container-images.git,/workspace/mnt/repos,miun-containers
git@github.com:facebook/react.git,/workspace/mnt/repos/gh/facebook,react
```

The `path` column specifies the absolute parent directory where the repository will be cloned.

### FR-8: Read-Only Root Filesystem Support

**The container must be compatible with read-only root filesystems.**

- All runtime writes must occur in mounted volumes
- User home, repositories, and scripts must be volume-mounted
- Temporary files must use `/tmp` or `/dev/shm`
- No modifications to root filesystem during runtime

### FR-9: Safe Git Directory Configuration

**The container must automatically configure safe Git directories.**

- Automatically add `/workspace/mnt/this-repo` as safe directory
- Configure safe directories on every shell initialization
- Support additional safe directories via user scripts

### FR-10: Shell Environment

**The container must use Alpine's default shell (ash/busybox sh).**

- Environment file: `/workspace/.ashrc`
- Auto-source on shell startup
- Support custom user aliases and functions
- Load SSH agent configuration automatically
- Load repository management utilities automatically

### FR-11: Repository CSV Management

**The container must support CSV-based repository management.**

- CSV file specifies repositories to clone/manage
- CSV location provided via `MANAGED_REPOS_CSV` environment variable
- CSV format: `url,path,name` where:
  - `url`: Git repository URL (SSH or HTTPS)
  - `path`: Absolute parent directory path where repo will be cloned
  - `name`: Repository directory name
- All repositories in CSV are processed (no hostname filtering)
- Repositories cloned to `{path}/{name}`
- Example CSV provided at `/workspace/util/../scripts/managed-repos-example.csv`

### FR-12: Repository Status Reporting

**The container must provide unified status reporting across all repositories.**

Status information includes:
- Current branch
- Commits behind/ahead of upstream
- Staged files count
- Unstaged files count
- Untracked files count
- Merge conflicts presence
- Last commit date

Report display:
- Tabular format for easy reading
- Only show repositories with changes (dirty state)
- Include both `this-repo` and managed repos

## Non-Functional Requirements

### NFR-1: Security

- Run as non-root user (UID 888)
- Support read-only root filesystem
- SSH keys stored with appropriate permissions (0600)
- SSH agent socket secured in `/dev/shm`
- No secrets embedded in image
- All credentials provided via volume mounts

### NFR-2: Reproducibility

- All component versions explicitly pinned
- Dockerfile must be idempotent
- No network calls during container runtime (all dependencies in image)
- Consistent behavior across rebuilds

### NFR-3: Minimal Image Size

- Base on Alpine Linux for minimal footprint
- Include only essential packages
- No unnecessary build tools or caches
- Single-stage build

### NFR-4: Documentation

- Clear README with usage examples
- Inline script documentation
- Environment variable requirements documented
- Volume mount requirements specified

### NFR-5: Maintainability

- Scripts must pass shellcheck linting
- Clear separation of image-provided vs. user-provided scripts
- Modular script design for easy updates
- Version updates documented in TRACK.md

## Dependencies

### Base Image
- `alpine:3.22`

### Alpine Packages (Versions as of build)
- `curl` (for HTTP operations)
- `git` (version control operations)
- `mandoc` (man page viewer)
- `openssh-client` (SSH operations and key management)
- `shellcheck` (shell script linting)
- `shunit2` (shell script unit testing)

### Container-Provided Scripts
- `agent-init.sh`: SSH agent initialization
- `gitconfig.sh`: Git global configuration setup
- `setup-ssh-key.sh`: SSH key generation
- `repo-utils.sh`: Multi-repository management library
- `managed-repos-example.csv`: Example CSV for repository management

## Constraints

1. **Alpine Linux Only**: Must use Alpine Linux as base for consistency with repository standards
2. **Non-Root User**: Must not run as root user
3. **Volume Dependency**: Requires volume mounts for full functionality
4. **SSH Key Format**: SSH signing only (no GPG support)
5. **Shell Compatibility**: Scripts must be POSIX-compliant (ash/sh compatible)

## Integration Requirements

### Docker Compose Integration

The container must work seamlessly with Docker Compose:
- Support environment variables via `.env` files
- Support volume mounts for workspace directories
- Support `read_only: true` flag
- Support `user:` specification

### Host Integration

- SSH keys from host can be mounted into container
- Git repositories from host can be mounted as volumes
- Custom scripts can be provided via volume mounts
- SSH agent can forward from host or run in container
- CSV file for managed repositories can be mounted from host
- Multiple repositories can be organized under `/workspace/mnt/repos`

## Compliance Requirements

1. **Repository Standards**: Must comply with parent repository requirements (version pinning, documentation, tracking)
2. **Security Best Practices**: Follow container security best practices (non-root, read-only, minimal attack surface)
3. **DCO Compliance**: Support Developer Certificate of Origin sign-off workflows
4. **Commit Signing**: Enable and support signed commits for audit trails

## Future Considerations

- GPG key support (in addition to SSH)
- Multi-architecture builds (arm64, amd64)
- Git LFS support
- Additional Git credential helpers
- Integration with hardware security keys
- Parallel repository operations for improved performance
- Repository health scoring and alerts
- Integration with CI/CD webhooks
- Automated repository backup/archival

## Success Criteria

The container image is considered successful when:

1. It can be built reproducibly with all pinned versions
2. It runs successfully with read-only root filesystem
3. SSH agent initializes and manages keys correctly
4. Git operations complete with proper signing
5. All utility scripts execute without errors
6. Documentation is complete and accurate
7. Shellcheck passes on all scripts
8. Container runs as non-root user
9. Volume mounts work as documented
10. Git workflows with sign-off and signing function correctly
11. Multi-repository functions (fetch-all, show-all-local-changes) work correctly
12. CSV-based repository management functions properly
13. Repository status reporting displays accurate information
14. All repositories in CSV are processed without filtering

