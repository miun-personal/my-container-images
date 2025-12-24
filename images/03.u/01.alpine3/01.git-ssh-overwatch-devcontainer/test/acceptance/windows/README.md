# Acceptance Tests - Windows

Acceptance tests for the `git-ssh-overwatch-devcontainer` container image on Windows using WSL2 and Rancher Desktop.

## Prerequisites

- Windows 10/11 with WSL2 enabled
- Rancher Desktop installed and running
- PowerShell 5.1 or later
- Container image built and tagged as `local/u/alpine/git-ssh-overwatch-devcontainer:latest`

## Test Structure

- `run-all-tests.ps1` - Main test runner that executes all test scripts
- `test-helpers.ps1` - Common helper functions for all tests
- `test-*.ps1` - Individual test scripts for specific functionality

## Running Tests

### Run All Tests
```powershell
cd test\acceptance\windows
.\run-all-tests.ps1
```

### Run Individual Test
```powershell
.\test-01-basic-container.ps1
```

### Run with Custom Image
```powershell
.\run-all-tests.ps1 -ImageName "myregistry/my-devcontainer:v1.0"
```

## Test Coverage

1. **test-01-basic-container.ps1** - Basic container functionality
   - Container starts successfully
   - Non-root user (dev)
   - Core tools available (git, ssh, curl)
   - Volume mounts work correctly
   - User home directory is writable

2. **test-02-ssh-agent.ps1** - SSH agent management
   - SSH agent initializes
   - Agent script loads correctly
   - Environment variables set properly
   - SSH key generation script works

3. **test-03-git-operations.ps1** - Git operations
   - Git configuration works
   - Git commands execute successfully
   - Safe directories configured
   - Commit signing configuration

4. **test-04-repo-management.ps1** - Multi-repository management
   - CSV parsing works
   - Repository cloning functions
   - Status reporting works
   - fetch-all and show-all-local-changes commands

## Test Output

Tests output results in a standardized format:
- `[PASS]` - Test passed (green)
- `[FAIL]` - Test failed (red)
- `[SKIP]` - Test skipped (yellow)
- `[INFO]` - Informational message (gray)

## Cleanup

Tests automatically clean up containers and temporary directories after execution. If manual cleanup is needed:

```powershell
# Remove test containers
docker ps -a | Select-String "git-ssh-test" | ForEach-Object { docker rm -f ($_ -split '\s+')[0] }

# Clean up temp directories (optional - they're in $env:TEMP)
Get-ChildItem $env:TEMP | Where-Object { $_.Name -like "git-ssh-test-*" } | Remove-Item -Recurse -Force
```

## Notes

- Tests use temporary directories under `$env:TEMP`
- Each test runs in isolation with its own container
- Tests are designed to be idempotent and can be run multiple times
- This variant does **not** test read-only filesystem functionality (removed from devcontainer version)
- User home directory remains writable in the container filesystem

## Differences from git-ssh-client Tests

This devcontainer variant has the following test differences:
- Removed `test-05-read-only-filesystem.ps1` (not applicable)
- No `--read-only` flag used in container tests
- User home directory is not mounted as a volume in tests

## Troubleshooting

### Tests fail to find image
Build the image first:
```powershell
cd ..\..\..\  # Navigate to Dockerfile directory
docker build -t local/u/alpine/git-ssh-overwatch-devcontainer:latest .
```

### Docker not running
Ensure Rancher Desktop or Docker Desktop is running and WSL2 integration is enabled.

### Permission errors
Run PowerShell as Administrator if you encounter permission issues with Docker.
