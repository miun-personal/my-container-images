# Acceptance Tests - Windows

Acceptance tests for the `git-ssh-client` container image on Windows using WSL2 and Rancher Desktop.

## Prerequisites

- Windows 10/11 with WSL2 enabled
- Rancher Desktop installed and running
- PowerShell 5.1 or later
- Container image built and tagged as `local/u/alpine/git-ssh-client:latest`

## Test Structure

- `run-all-tests.ps1` - Main test runner that executes all test scripts
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

## Test Coverage

1. **test-01-basic-container.ps1** - Basic container functionality
   - Container starts successfully
   - Non-root user (dev)
   - Core tools available (git, ssh, curl)
   - Volume mounts work correctly

2. **test-02-ssh-agent.ps1** - SSH agent management
   - SSH agent initializes
   - Agent script loads correctly
   - Environment variables set properly

3. **test-03-git-operations.ps1** - Git operations
   - Git configuration works
   - Git commands execute successfully
   - Safe directories configured

4. **test-04-repo-management.ps1** - Multi-repository management
   - CSV parsing works
   - Repository cloning functions
   - Status reporting works
   - fetch-all and show-all-local-changes commands

5. **test-05-read-only-filesystem.ps1** - Read-only filesystem compatibility
   - Container runs with --read-only flag
   - Writable volumes function correctly
   - No errors with read-only root

## Test Output

Tests output results in a standardized format:
- ✓ PASS - Test passed
- ✗ FAIL - Test failed
- ⚠ SKIP - Test skipped (prerequisite not met)

## Cleanup

Tests automatically clean up containers and volumes after execution. If manual cleanup is needed:

```powershell
# Remove test containers
docker ps -a | Select-String "git-ssh-test" | ForEach-Object { docker rm -f ($_ -split '\s+')[0] }

# Remove test volumes
docker volume ls | Select-String "git-ssh-test" | ForEach-Object { docker volume rm ($_ -split '\s+')[1] }
```

## Notes

- Tests use temporary directories under `$env:TEMP`
- Each test runs in isolation with its own container
- Tests are designed to be idempotent and can be run multiple times
