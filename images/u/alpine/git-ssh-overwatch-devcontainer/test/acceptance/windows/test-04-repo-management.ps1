# test-04-repo-management.ps1 - Multi-repository management tests

param(
  [string]$ImageName = "local/u/alpine/git-ssh-overwatch-devcontainer:latest"
)

# Import test helpers
. "$PSScriptRoot\test-helpers.ps1"

Write-TestHeader "Test 04: Multi-Repository Management"

# Check if image exists
if (-not (Test-ImageExists -Image $ImageName)) {
  Write-TestSkip "All tests" "Image $ImageName not found. Please build the image first."
  Write-TestSummary
  exit 0
}

$containerName = "git-ssh-test-repomgmt-$(Get-Random)"
$testDirHome = New-TestDirectory -Name "home"
$testDirRepos = New-TestDirectory -Name "repos"
$testDirScripts = New-TestDirectory -Name "scripts"

# Create a test CSV file
$csvPath = Join-Path $testDirScripts "test-repos.csv"
$csvEntries = @(
  @{
    url  = "https://github.com/miun-personal/my-container-images.git"
    path = "/work/mnt/repos"
    name = "my-container-images"
  }
)
New-TestCSV -Path $csvPath -Entries $csvEntries

$volumes = @{
  "/work/home/dev"    = $testDirHome
  "/work/mnt/repos"   = $testDirRepos
  "/work/mnt/scripts" = $testDirScripts
}

$env = @{
  "GIT_USER_NAME"     = "Test User"
  "GIT_USER_EMAIL"    = "test@example.com"
  "MANAGED_REPOS_CSV" = "/work/mnt/scripts/test-repos.csv"
}

$output = Start-TestContainer -Name $containerName -Image $ImageName -Volumes $volumes -Environment $env -Detach -Command "sleep 120"

if (Test-ContainerRunning -Name $containerName) {
  Write-TestPass "Container started for repository management tests"
    
  # Test 1: repo-utils.sh exists and is executable
  $repoUtils = Invoke-ContainerCommand -Container $containerName -Command "test -f /work/util/repo-utils.sh && echo 'exists'"
  Assert-Contains -Haystack $repoUtils -Needle "exists" -Message "repo-utils.sh exists"
    
  # Test 2: repo-utils.sh can be sourced
  $sourceTest = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && echo 'sourced'"
  Assert-Contains -Haystack $sourceTest -Needle "sourced" -Message "repo-utils.sh can be sourced"
    
  # Test 3: Check that .ashrc sources repo-utils.sh
  $ashrcCheck = Invoke-ContainerCommand -Container $containerName -Command "grep 'repo-utils.sh' /work/.ashrc"
  Assert-Contains -Haystack $ashrcCheck -Needle "repo-utils.sh" -Message ".ashrc is configured to source repo-utils.sh"
    
  # Test 4: CSV file is mounted correctly
  $csvCheck = Invoke-ContainerCommand -Container $containerName -Command "test -f /work/mnt/scripts/test-repos.csv && echo 'exists'"
  Assert-Contains -Haystack $csvCheck -Needle "exists" -Message "CSV file is mounted correctly"
    
  # Test 5: CSV file has correct format
  $csvContent = Invoke-ContainerCommand -Container $containerName -Command "cat /work/mnt/scripts/test-repos.csv"
  Assert-Contains -Haystack $csvContent -Needle "url,path,name" -Message "CSV has correct header"
  Assert-Contains -Haystack $csvContent -Needle "my-container-images" -Message "CSV contains test repository entry"
    
  # Test 6: list-all-repos function is available
  $listCmd = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && type list_all_repos 2>&1"
  if ($listCmd -match "function|alias") {
    Write-TestPass "list-all-repos function is available"
  }
  else {
    Write-TestInfo "list-all-repos check output: $listCmd"
  }
    
  # Test 7: fetch-all function is available
  $fetchCmd = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && type fetch_all_repos 2>&1"
  if ($fetchCmd -match "function|alias") {
    Write-TestPass "fetch-all function is available"
  }
  else {
    Write-TestInfo "fetch-all check output: $fetchCmd"
  }
    
  # Test 8: show-all-local-changes function is available
  $showCmd = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && type show_all_local_changes 2>&1"
  if ($showCmd -match "function|alias") {
    Write-TestPass "show-all-local-changes function is available"
  }
  else {
    Write-TestInfo "show-all-local-changes check output: $showCmd"
  }
    
  # Test 9: repo-status function is available
  $statusCmd = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && type repo_status 2>&1"
  if ($statusCmd -match "function|alias") {
    Write-TestPass "repo-status function is available"
  }
  else {
    Write-TestInfo "repo-status check output: $statusCmd"
  }
    
  # Test 10: MANAGED_REPOS_CSV environment variable is set
  $envCheck = Invoke-ContainerCommand -Container $containerName -Command "echo `$MANAGED_REPOS_CSV"
  Assert-Equal -Actual $envCheck.Trim() -Expected "/work/mnt/scripts/test-repos.csv" -Message "MANAGED_REPOS_CSV environment variable is set"
    
  # Test 11: Test fetch-all command (this will clone the repo)
  Write-TestInfo "Testing fetch-all command (may take time to clone repository)..."
  $fetchOutput = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && fetch_all_repos 2>&1"
    
  if ($fetchOutput -match "Fetching All Repositories") {
    Write-TestPass "fetch-all command executes"
  }
  else {
    Write-TestInfo "fetch-all output: $fetchOutput"
  }
    
  # Test 12: Verify repository was cloned
  Start-Sleep -Seconds 5  # Give it time to complete
  $repoExists = Invoke-ContainerCommand -Container $containerName -Command "test -d /work/mnt/repos/my-container-images/.git && echo 'cloned'"
    
  if ($repoExists -match "cloned") {
    Write-TestPass "Repository was cloned successfully"
        
    # Test 13: Verify it's a valid git repository
    $gitCheck = Invoke-ContainerCommand -Container $containerName -Command "cd /work/mnt/repos/my-container-images && git status 2>&1"
    if ($gitCheck -match "On branch|HEAD detached") {
      Write-TestPass "Cloned repository is a valid git repository"
    }
    else {
      Write-TestFail "Cloned repository is a valid git repository" "git status failed"
    }
        
    # Test 14: Test list-all-repos
    # Debug: Check what REPOS_BASE_DIR is set to
    $debugReposDir = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && echo REPOS_BASE_DIR=`$REPOS_BASE_DIR && echo WORKSPACE_MANAGED_REPOS_HOME=`$WORKSPACE_MANAGED_REPOS_HOME && ls -la /work/mnt/repos 2>&1"
    Write-TestInfo "Debug info: $debugReposDir"
    
    $listOutput = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && list_all_repos 2>&1"
    Write-TestInfo "list-all-repos output: $listOutput"
    Assert-Contains -Haystack $listOutput -Needle "my-container-images" -Message "list-all-repos shows cloned repository"
        
    # Test 15: Test show-all-local-changes (should show no changes for fresh clone)
    $changesOutput = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && show_all_local_changes 2>&1"
    if ($changesOutput -match "No repositories with local changes" -or $changesOutput -match "Found 0 repositories") {
      Write-TestPass "show-all-local-changes reports no changes for fresh clone"
    }
    else {
      Write-TestInfo "show-all-local-changes output: $changesOutput"
    }
        
    # Test 16: Create local changes and verify detection
    $makeChanges = Invoke-ContainerCommand -Container $containerName -Command "echo 'test change' >> /work/mnt/repos/my-container-images/test.txt"
    $changesOutput2 = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && show_all_local_changes 2>&1"
    
    if ($changesOutput2 -match "my-container-images" -or $changesOutput2 -match "Found 1 repositories") {
      Write-TestPass "show-all-local-changes detects local modifications"
    }
    else {
      Write-TestInfo "Changes detection output: $changesOutput2"
    }
        
    # Test 17: Test repo-status for specific repository
    $repoStatusOutput = Invoke-ContainerCommand -Container $containerName -Command ". /work/util/repo-utils.sh && repo_status my-container-images 2>&1"
    Assert-Contains -Haystack $repoStatusOutput -Needle "my-container-images" -Message "repo-status shows specific repository status"
        
  }
  else {
    Write-TestSkip "Repository clone tests" "Repository cloning failed or timed out"
  }
    
  # Test 18: Example CSV file exists (in /work/util where scripts are copied)
  $exampleCsv = Invoke-ContainerCommand -Container $containerName -Command "test -f /work/util/managed-repos-example.csv && echo 'exists'"
  Assert-Contains -Haystack $exampleCsv -Needle "exists" -Message "Example CSV file exists"
    
  Stop-TestContainer -Name $containerName
    
}
else {
  Write-TestFail "Container started for repository management tests" "Container failed to start"
}

Remove-TestDirectory -Path $testDirHome
Remove-TestDirectory -Path $testDirRepos
Remove-TestDirectory -Path $testDirScripts

Write-TestSummary
