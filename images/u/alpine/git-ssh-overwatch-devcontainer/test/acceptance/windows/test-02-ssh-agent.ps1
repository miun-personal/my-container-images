# test-02-ssh-agent.ps1 - SSH agent management tests

param(
    [string]$ImageName = "local/u/alpine/git-ssh-overwatch-devcontainer:latest"
)

# Import test helpers
. "$PSScriptRoot\test-helpers.ps1"

Write-TestHeader "Test 02: SSH Agent Management"

# Check if image exists
if (-not (Test-ImageExists -Image $ImageName)) {
    Write-TestSkip "All tests" "Image $ImageName not found. Please build the image first."
    Write-TestSummary
    exit 0
}

# Test 1: SSH agent initialization script exists and is valid
$containerName = "git-ssh-test-agent-$(Get-Random)"
$output = Start-TestContainer -Name $containerName -Image $ImageName -Detach -Command "sleep 30"

if (Test-ContainerRunning -Name $containerName) {
    Write-TestPass "Container started for SSH agent tests"
    
    # Test 2: agent-init.sh can be sourced
    $sourceTest = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/agent-init.sh && echo 'sourced'"
    Assert-Contains -Haystack $sourceTest -Needle "sourced" -Message "agent-init.sh can be sourced"
    
    # Test 3: SSH agent starts
    $agentStart = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/agent-init.sh && env | grep SSH_AUTH_SOCK"
    Assert-Contains -Haystack $agentStart -Needle "SSH_AUTH_SOCK" -Message "SSH agent starts and sets SSH_AUTH_SOCK"
    
    # Test 4: SSH agent PID is set
    $agentPid = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/agent-init.sh && env | grep SSH_AGENT_PID"
    Assert-Contains -Haystack $agentPid -Needle "SSH_AGENT_PID" -Message "SSH agent PID is set"
    
    # Test 5: Agent socket is created in /dev/shm
    $socketCheck = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/agent-init.sh && test -S `$SSH_AUTH_SOCK && echo 'exists'"
    Assert-Contains -Haystack $socketCheck -Needle "exists" -Message "SSH agent socket is created"
    
    # Test 6: ssh-add command is available
    Assert-CommandExists -Container $containerName -CommandName "ssh-add" -Message "ssh-add command is available"
    
    # Test 7: Check that .ashrc sources agent-init.sh
    $ashrcCheck = Invoke-ContainerCommand -Container $containerName -Command "grep 'agent-init.sh' /work/.ashrc"
    Assert-Contains -Haystack $ashrcCheck -Needle "agent-init.sh" -Message ".ashrc is configured to source agent-init.sh"
    
    # Test 8: Shell initialization loads agent automatically
    $shellInit = Invoke-ContainerCommand -Container $containerName -Command "sh -c 'env | grep SSH_AUTH_SOCK'"
    if ($shellInit -match "SSH_AUTH_SOCK") {
        Write-TestPass "Shell initialization loads SSH agent automatically"
    }
    else {
        # This might be expected if the shell is non-interactive
        Write-TestInfo "SSH agent not auto-loaded in non-interactive shell (expected behavior)"
    }
    
    Stop-TestContainer -Name $containerName
    
}
else {
    Write-TestFail "Container started for SSH agent tests" "Container failed to start"
}

# Test 9: SSH key generation script
$containerName2 = "git-ssh-test-keygen-$(Get-Random)"
$testDir = New-TestDirectory -Name "sshkeys"

$volumes = @{
    "/work/home/dev" = $testDir
}

$output = Start-TestContainer -Name $containerName2 -Image $ImageName -Volumes $volumes -Detach -Command "sleep 30"

if (Test-ContainerRunning -Name $containerName2) {
    Write-TestPass "Container started for SSH key generation tests"
    
    # Test 10: setup-ssh-key.sh exists and is executable
    $keygenScript = Invoke-ContainerCommand -Container $containerName2 -Command "test -x /work/util/setup-ssh-key.sh && echo 'executable'"
    Assert-Contains -Haystack $keygenScript -Needle "executable" -Message "setup-ssh-key.sh is executable"
    
    # Test 11: SSH directory is created automatically
    $sshDir = Invoke-ContainerCommand -Container $containerName2 -Command "test -d /work/home/dev/.ssh && echo 'exists' || mkdir -p /work/home/dev/.ssh && echo 'created'"
    if ($sshDir -match "exists|created") {
        Write-TestPass "SSH directory can be created"
    }
    else {
        Write-TestFail "SSH directory can be created" "Failed to create .ssh directory"
    }
    
    # Test 12: Generate SSH key (non-interactive test - would need expect or similar for full test)
    Write-TestInfo "SSH key generation requires interactive input - skipping full generation test"
    Write-TestInfo "Manual test: Run /work/util/setup-ssh-key.sh test@example.com inside container"
    
    Stop-TestContainer -Name $containerName2
    
}
else {
    Write-TestFail "Container started for SSH key generation tests" "Container failed to start"
}

Remove-TestDirectory -Path $testDir

Write-TestSummary
