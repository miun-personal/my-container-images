# test-05-read-only-filesystem.ps1 - Read-only filesystem compatibility tests

param(
    [string]$ImageName = "local/u/alpine/git-ssh-client:latest"
)

# Import test helpers
. "$PSScriptRoot\test-helpers.ps1"

Write-TestHeader "Test 05: Read-Only Filesystem Compatibility"

# Check if image exists
if (-not (Test-ImageExists -Image $ImageName)) {
    Write-TestSkip "All tests" "Image $ImageName not found. Please build the image first."
    Write-TestSummary
    exit 0
}

$containerName = "git-ssh-test-readonly-$(Get-Random)"
$testDirHome = New-TestDirectory -Name "readonly-home"
$testDirRepo = New-TestDirectory -Name "readonly-repo"
$testDirScripts = New-TestDirectory -Name "readonly-scripts"

$volumes = @{
    "/workspace/home/dev" = $testDirHome
    "/workspace/mnt/this-repo" = $testDirRepo
    "/workspace/mnt/scripts" = $testDirScripts
    "/tmp" = "$(New-TestDirectory -Name 'tmp')"
}

$env = @{
    "GIT_USER_NAME" = "Test User"
    "GIT_USER_EMAIL" = "test@example.com"
}

# Test 1: Container starts with read-only flag
Write-TestInfo "Starting container with --read-only flag..."
$output = Start-TestContainer -Name $containerName -Image $ImageName -Volumes $volumes -Environment $env -ReadOnly -Detach -Command "sleep 60"

if (Test-ContainerRunning -Name $containerName) {
    Write-TestPass "Container starts with read-only filesystem"
    
    # Test 2: Root filesystem is read-only
    $writeTest = Invoke-ContainerCommand -Container $containerName -Command "touch /test.txt 2>&1"
    if ($writeTest -match "Read-only file system") {
        Write-TestPass "Root filesystem is read-only"
    } else {
        Write-TestFail "Root filesystem is read-only" "Expected read-only error, got: $writeTest"
    }
    
    # Test 3: User home is writable
    $homeWrite = Invoke-ContainerCommand -Container $containerName -Command "touch /workspace/home/dev/test.txt && echo 'success'"
    Assert-Contains -Haystack $homeWrite -Needle "success" -Message "User home directory is writable"
    
    # Test 4: This-repo directory is writable
    $repoWrite = Invoke-ContainerCommand -Container $containerName -Command "touch /workspace/mnt/this-repo/test.txt && echo 'success'"
    Assert-Contains -Haystack $repoWrite -Needle "success" -Message "This-repo directory is writable"
    
    # Test 5: Scripts directory is writable
    $scriptsWrite = Invoke-ContainerCommand -Container $containerName -Command "touch /workspace/mnt/scripts/test.txt && echo 'success'"
    Assert-Contains -Haystack $scriptsWrite -Needle "success" -Message "Scripts directory is writable"
    
    # Test 6: /tmp is writable
    $tmpWrite = Invoke-ContainerCommand -Container $containerName -Command "touch /tmp/test.txt && echo 'success'"
    Assert-Contains -Haystack $tmpWrite -Needle "success" -Message "/tmp directory is writable"
    
    # Test 7: Git operations work with read-only root
    $gitInit = Invoke-ContainerCommand -Container $containerName -Command "cd /workspace/mnt/this-repo && git init && echo 'initialized'"
    Assert-Contains -Haystack $gitInit -Needle "initialized" -Message "Git init works with read-only filesystem"
    
    # Test 8: Git config works
    $gitConfig = Invoke-ContainerCommand -Container $containerName -Command "/workspace/util/gitconfig.sh 2>&1"
    $gitUserCheck = Invoke-ContainerCommand -Container $containerName -Command "git config --global user.name"
    Assert-Equal -Actual $gitUserCheck.Trim() -Expected "Test User" -Message "Git configuration works with read-only filesystem"
    
    # Test 9: SSH agent can start with read-only filesystem
    $agentStart = Invoke-ContainerCommand -Container $containerName -Command ". /workspace/util/agent-init.sh && env | grep SSH_AUTH_SOCK"
    Assert-Contains -Haystack $agentStart -Needle "SSH_AUTH_SOCK" -Message "SSH agent starts with read-only filesystem"
    
    # Test 10: Shell can be started interactively
    $shellTest = Invoke-ContainerCommand -Container $containerName -Command "sh -c 'echo test'"
    Assert-Equal -Actual $shellTest.Trim() -Expected "test" -Message "Shell works with read-only filesystem"
    
    # Test 11: Environment file is accessible
    $envFileTest = Invoke-ContainerCommand -Container $containerName -Command "test -f /workspace/.ashrc && echo 'exists'"
    Assert-Contains -Haystack $envFileTest -Needle "exists" -Message "Environment file is accessible"
    
    # Test 12: Utility scripts are accessible and executable
    $scriptsTest = Invoke-ContainerCommand -Container $containerName -Command "test -x /workspace/util/gitconfig.sh && echo 'executable'"
    Assert-Contains -Haystack $scriptsTest -Needle "executable" -Message "Utility scripts are executable with read-only filesystem"
    
    # Test 13: repo-utils functions work
    $repoUtilsTest = Invoke-ContainerCommand -Container $containerName -Command ". /workspace/util/repo-utils.sh && echo 'loaded'"
    Assert-Contains -Haystack $repoUtilsTest -Needle "loaded" -Message "repo-utils.sh loads with read-only filesystem"
    
    # Test 14: /dev/shm is writable (for SSH agent)
    $shmWrite = Invoke-ContainerCommand -Container $containerName -Command "echo 'test' > /dev/shm/test.txt && cat /dev/shm/test.txt"
    Assert-Contains -Haystack $shmWrite -Needle "test" -Message "/dev/shm is writable for SSH agent"
    
    # Test 15: Container can handle common operations
    $opsTest = Invoke-ContainerCommand -Container $containerName -Command "cd /workspace/mnt/this-repo && git status 2>&1"
    if ($opsTest -notmatch "Read-only file system") {
        Write-TestPass "Git operations don't trigger read-only errors"
    } else {
        Write-TestFail "Git operations don't trigger read-only errors" "Got read-only error: $opsTest"
    }
    
    Stop-TestContainer -Name $containerName
    
} else {
    Write-TestFail "Container starts with read-only filesystem" "Container failed to start"
}

# Cleanup
Remove-TestDirectory -Path $testDirHome
Remove-TestDirectory -Path $testDirRepo
Remove-TestDirectory -Path $testDirScripts
Remove-TestDirectory -Path $volumes["/tmp"]

Write-TestSummary
