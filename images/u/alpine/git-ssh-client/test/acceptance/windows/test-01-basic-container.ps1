# test-01-basic-container.ps1 - Basic container functionality tests

param(
  [string]$ImageName = "local/u/alpine/git-ssh-client:latest"
)

# Import test helpers
. "$PSScriptRoot\test-helpers.ps1"

Write-TestHeader "Test 01: Basic Container Functionality"

# Check if image exists
if (-not (Test-ImageExists -Image $ImageName)) {
  Write-TestSkip "All tests" "Image $ImageName not found. Please build the image first."
  Write-TestSummary
  exit 0
}

# Test 1: Container starts successfully
Write-TestInfo "Starting container..."
$containerName = "git-ssh-test-basic-$(Get-Random)"
$output = Start-TestContainer -Name $containerName -Image $ImageName -Detach -Command "sleep 30"

if (Test-ContainerRunning -Name $containerName) {
  Write-TestPass "Container starts successfully"
    
  # Test 2: Container runs as non-root user
  $userId = Invoke-ContainerCommand -Container $containerName -Command "id -u"
  Assert-Equal -Actual $userId.Trim() -Expected "888" -Message "Container runs as non-root user (UID 888)"
    
  # Test 3: User name is 'dev'
  $userName = Invoke-ContainerCommand -Container $containerName -Command "whoami"
  Assert-Equal -Actual $userName.Trim() -Expected "dev" -Message "Container runs as user 'dev'"
    
  # Test 4: Git is installed
  Assert-CommandExists -Container $containerName -CommandName "git" -Message "Git is installed"
    
  # Test 5: SSH client is installed
  Assert-CommandExists -Container $containerName -CommandName "ssh" -Message "SSH client is installed"
    
  # Test 6: curl is installed
  Assert-CommandExists -Container $containerName -CommandName "curl" -Message "curl is installed"
    
  # Test 7: shellcheck is installed
  Assert-CommandExists -Container $containerName -CommandName "shellcheck" -Message "shellcheck is installed"
    
  # Test 8: Check workspace directories exist
  $workspaceHome = Invoke-ContainerCommand -Container $containerName -Command "test -d /workspace && echo 'exists'"
  Assert-Contains -Haystack $workspaceHome -Needle "exists" -Message "Workspace home directory exists"
    
  # Test 9: Check util scripts directory exists
  $utilDir = Invoke-ContainerCommand -Container $containerName -Command "test -d /workspace/util && echo 'exists'"
  Assert-Contains -Haystack $utilDir -Needle "exists" -Message "Utility scripts directory exists"
    
  # Test 10: Check agent-init.sh exists
  $agentScript = Invoke-ContainerCommand -Container $containerName -Command "test -f /workspace/util/agent-init.sh && echo 'exists'"
  Assert-Contains -Haystack $agentScript -Needle "exists" -Message "agent-init.sh script exists"
    
  # Test 11: Check gitconfig.sh exists
  $gitconfigScript = Invoke-ContainerCommand -Container $containerName -Command "test -f /workspace/util/gitconfig.sh && echo 'exists'"
  Assert-Contains -Haystack $gitconfigScript -Needle "exists" -Message "gitconfig.sh script exists"
    
  # Test 12: Check setup-ssh-key.sh exists
  $sshKeyScript = Invoke-ContainerCommand -Container $containerName -Command "test -f /workspace/util/setup-ssh-key.sh && echo 'exists'"
  Assert-Contains -Haystack $sshKeyScript -Needle "exists" -Message "setup-ssh-key.sh script exists"
    
  # Test 13: Check repo-utils.sh exists
  $repoUtilsScript = Invoke-ContainerCommand -Container $containerName -Command "test -f /workspace/util/repo-utils.sh && echo 'exists'"
  Assert-Contains -Haystack $repoUtilsScript -Needle "exists" -Message "repo-utils.sh script exists"
    
  # Test 14: Check scripts are executable
  $executableCheck = Invoke-ContainerCommand -Container $containerName -Command "test -x /workspace/util/agent-init.sh && echo 'executable'"
  Assert-Contains -Haystack $executableCheck -Needle "executable" -Message "Scripts are executable"
    
  # Test 15: Check environment variable WORKSPACE_HOME
  $envVar = Invoke-ContainerCommand -Container $containerName -Command "echo `$WORKSPACE_HOME"
  Assert-Equal -Actual $envVar.Trim() -Expected "/workspace" -Message "WORKSPACE_HOME environment variable is set"
    
  # Test 16: Check environment variable WORKSPACE_USER_HOME
  $userHome = Invoke-ContainerCommand -Container $containerName -Command "echo `$WORKSPACE_USER_HOME"
  Assert-Equal -Actual $userHome.Trim() -Expected "/workspace/home/dev" -Message "WORKSPACE_USER_HOME environment variable is set"
    
  # Test 17: Check .ashrc file exists
  $ashrc = Invoke-ContainerCommand -Container $containerName -Command "test -f /workspace/.ashrc && echo 'exists'"
  Assert-Contains -Haystack $ashrc -Needle "exists" -Message ".ashrc configuration file exists"
    
  # Test 18: Check aliases are defined in .ashrc
  $aliases = Invoke-ContainerCommand -Container $containerName -Command "grep -c 'alias' /workspace/.ashrc"
  if ([int]$aliases -gt 0) {
    Write-TestPass "Aliases are defined in .ashrc"
  }
  else {
    Write-TestFail "Aliases are defined in .ashrc" "No aliases found"
  }
    
  # Cleanup
  Stop-TestContainer -Name $containerName
    
}
else {
  Write-TestFail "Container starts successfully" "Container failed to start"
}

# Test 19: Container with volume mounts
Write-TestInfo "Testing volume mounts..."
$testDir = New-TestDirectory -Name "basic"
$containerName2 = "git-ssh-test-volumes-$(Get-Random)"

$volumes = @{
  "/workspace/home/dev" = $testDir
}

$output = Start-TestContainer -Name $containerName2 -Image $ImageName -Volumes $volumes -Detach -Command "sleep 10"

if (Test-ContainerRunning -Name $containerName2) {
  # Test that we can write to mounted volume
  $writeTest = Invoke-ContainerCommand -Container $containerName2 -Command "echo 'test' > /workspace/home/dev/test.txt && cat /workspace/home/dev/test.txt"
  Assert-Contains -Haystack $writeTest -Needle "test" -Message "Can write to mounted volume"
    
  # Verify file exists on host
  $hostFile = Join-Path $testDir "test.txt"
  if (Test-Path $hostFile) {
    Write-TestPass "File persists on host filesystem"
  }
  else {
    Write-TestFail "File persists on host filesystem" "File not found at $hostFile"
  }
    
  Stop-TestContainer -Name $containerName2
}
else {
  Write-TestFail "Container with volume mounts starts" "Container failed to start"
}

Remove-TestDirectory -Path $testDir

Write-TestSummary
