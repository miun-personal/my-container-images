# test-03-git-operations.ps1 - Git operations tests

param(
  [string]$ImageName = "local/u/alpine/git-ssh-overwatch-devcontainer:latest"
)

# Import test helpers
. "$PSScriptRoot\test-helpers.ps1"

Write-TestHeader "Test 03: Git Operations"

# Check if image exists
if (-not (Test-ImageExists -Image $ImageName)) {
  Write-TestSkip "All tests" "Image $ImageName not found. Please build the image first."
  Write-TestSummary
  exit 0
}

$containerName = "git-ssh-test-git-$(Get-Random)"
$testDir = New-TestDirectory -Name "git"

$volumes = @{
  "/work/home/dev"      = $testDir
  "/work/mnt/this-repo" = $testDir
}

$env = @{
  "GIT_USER_NAME"  = "Test User"
  "GIT_USER_EMAIL" = "test@example.com"
}

$output = Start-TestContainer -Name $containerName -Image $ImageName -Volumes $volumes -Environment $env -Detach -Command "sleep 60"

if (Test-ContainerRunning -Name $containerName) {
  Write-TestPass "Container started for Git tests"
    
  # Test 1: Git is properly installed
  $gitVersion = Invoke-ContainerCommand -Container $containerName -Command "git --version"
  Assert-Contains -Haystack $gitVersion -Needle "git version" -Message "Git is installed and reports version"
    
  # Test 2: gitconfig.sh exists and is executable
  $gitconfigScript = Invoke-ContainerCommand -Container $containerName -Command "test -x /work/util/gitconfig.sh && echo 'executable'"
  Assert-Contains -Haystack $gitconfigScript -Needle "executable" -Message "gitconfig.sh is executable"
    
  # Create .ssh directory before running gitconfig.sh (required for allowed_signers file)
  $sshDirCreate = Invoke-ContainerCommand -Container $containerName -Command "mkdir -p /work/home/dev/.ssh && echo 'created'"
  Assert-Contains -Haystack $sshDirCreate -Needle "created" -Message ".ssh directory is created"
    
  # Test 3: Git can be configured with environment variables
  $gitConfig = Invoke-ContainerCommand -Container $containerName -Command "/work/util/gitconfig.sh 2>&1"
  Write-TestInfo "Git config script output: $gitConfig"
  if ($gitConfig -match "successfully") {
    Write-TestPass "Git configuration script runs successfully"
  }
  else {
    Write-TestFail "Git configuration script runs successfully" "Script did not complete successfully"
  }
    
  # Test 4: Git user name is set
  $gitUserName = Invoke-ContainerCommand -Container $containerName -Command "git config --global user.name"
  Assert-Equal -Actual $gitUserName.Trim() -Expected "Test User" -Message "Git user.name is configured"
    
  # Test 5: Git user email is set
  $gitUserEmail = Invoke-ContainerCommand -Container $containerName -Command "git config --global user.email"
  Assert-Equal -Actual $gitUserEmail.Trim() -Expected "test@example.com" -Message "Git user.email is configured"
    
  # Test 6: Git commit signing is enabled
  $commitSign = Invoke-ContainerCommand -Container $containerName -Command "git config --global commit.gpgsign"
  if ($commitSign) {
    Assert-Equal -Actual $commitSign.Trim() -Expected "true" -Message "Git commit signing is enabled"
  }
  else {
    Write-TestFail "Git commit signing is enabled" "Config value is empty or not set"
  }
    
  # Test 7: GPG format is set to SSH
  $gpgFormat = Invoke-ContainerCommand -Container $containerName -Command "git config --global gpg.format"
  if ($gpgFormat) {
    Assert-Equal -Actual $gpgFormat.Trim() -Expected "ssh" -Message "GPG format is set to SSH"
  }
  else {
    Write-TestFail "GPG format is set to SSH" "Config value is empty or not set"
  }
    
  # Test 8: Git safe directory for main repo (need to source .ashrc first)
  $safeDir = Invoke-ContainerCommand -Container $containerName -Command ". /work/.ashrc && git config --global --get-all safe.directory"
  Assert-Contains -Haystack $safeDir -Needle "/work/mnt/this-repo" -Message "Main repo is configured as safe directory"
    
  # Test 9: Create a test git repository
  $initRepo = Invoke-ContainerCommand -Container $containerName -Command "cd /work/mnt/this-repo && git init && echo 'test' > README.md && git add README.md 2>&1"
    
  # Test 10: Git add works (check that README.md was staged)
  $gitStatus = Invoke-ContainerCommand -Container $containerName -Command "cd /work/mnt/this-repo && git status --short 2>&1"
  if ($gitStatus -match "A.*README.md" -or $gitStatus -match "new file.*README.md") {
    Write-TestPass "Git add command works"
  }
  else {
    Write-TestFail "Git add command works" "Expected to find 'README.md' in output`nActual output: $gitStatus"
  }
    
  # Test 11: Git commit works (without signing key)
  $gitCommit = Invoke-ContainerCommand -Container $containerName -Command "cd /work/mnt/this-repo && git -c commit.gpgsign=false commit -m 'Initial commit' 2>&1"
  $gitLog = Invoke-ContainerCommand -Container $containerName -Command "cd /work/mnt/this-repo && git log --oneline 2>&1"
  if ($gitLog -match "Initial commit") {
    Write-TestPass "Git commit command works"
  }
  else {
    Write-TestFail "Git commit command works" "Expected to find 'Initial commit' in output`nCommit output: $gitCommit`nLog output: $gitLog"
  }
    
  # Test 12: Check Git aliases are available in shell
  $aliasCheck = Invoke-ContainerCommand -Container $containerName -Command "grep 'scommit' /work/.ashrc"
  Assert-Contains -Haystack $aliasCheck -Needle "scommit" -Message "Git signing aliases are defined"
    
  # Test 13: Verify all signing aliases exist
  $aliases = @("scommit", "scommitg", "smerge", "samend", "spush", "slog", "srebase", "sclone")
  foreach ($alias in $aliases) {
    $check = Invoke-ContainerCommand -Container $containerName -Command "grep '$alias' /work/.ashrc"
    if ($check -match $alias) {
      Write-TestPass "Alias '$alias' is defined"
    }
    else {
      Write-TestFail "Alias '$alias' is defined" "Alias not found in .ashrc"
    }
  }
    
  # Test 14: Git core settings
  $autocrlf = Invoke-ContainerCommand -Container $containerName -Command "git config --global core.autocrlf"
  if ($autocrlf) {
    Assert-Equal -Actual $autocrlf.Trim() -Expected "input" -Message "core.autocrlf is set to input"
  }
  else {
    Write-TestFail "core.autocrlf is set to input" "Config value is empty or not set"
  }
    
  $eol = Invoke-ContainerCommand -Container $containerName -Command "git config --global core.eol"
  if ($eol) {
    Assert-Equal -Actual $eol.Trim() -Expected "lf" -Message "core.eol is set to lf"
  }
  else {
    Write-TestFail "core.eol is set to lf" "Config value is empty or not set"
  }
    
  Stop-TestContainer -Name $containerName
    
}
else {
  Write-TestFail "Container started for Git tests" "Container failed to start"
}

Remove-TestDirectory -Path $testDir

Write-TestSummary
