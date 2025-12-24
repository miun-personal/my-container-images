# test-helpers.ps1 - Common helper functions for acceptance tests

# Test result counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

# Color output functions
function Write-TestHeader {
  param([string]$Message)
  Write-Host "`n========================================" -ForegroundColor Cyan
  Write-Host $Message -ForegroundColor Cyan
  Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-TestPass {
  param([string]$Message)
  Write-Host "[PASS] $Message" -ForegroundColor Green
  $script:TestsPassed++
}

function Write-TestFail {
  param([string]$Message, [string]$Details = "")
  Write-Host "[FAIL] $Message" -ForegroundColor Red
  if ($Details) {
    Write-Host "  Details: $Details" -ForegroundColor Yellow
  }
  $script:TestsFailed++
}

function Write-TestSkip {
  param([string]$Message, [string]$Reason = "")
  Write-Host "[SKIP] $Message" -ForegroundColor Yellow
  if ($Reason) {
    Write-Host "  Reason: $Reason" -ForegroundColor Yellow
  }
  $script:TestsSkipped++
}

function Write-TestInfo {
  param([string]$Message)
  Write-Host "[INFO] $Message" -ForegroundColor Gray
}

function Write-TestSummary {
  Write-Host "`n========================================" -ForegroundColor Cyan
  Write-Host "TEST SUMMARY" -ForegroundColor Cyan
  Write-Host "========================================" -ForegroundColor Cyan
  Write-Host "Passed : $script:TestsPassed" -ForegroundColor Green
  Write-Host "Failed : $script:TestsFailed" -ForegroundColor Red
  Write-Host "Skipped: $script:TestsSkipped" -ForegroundColor Yellow
  Write-Host "Total  : $($script:TestsPassed + $script:TestsFailed + $script:TestsSkipped)" -ForegroundColor Cyan
  Write-Host "========================================`n" -ForegroundColor Cyan
    
  if ($script:TestsFailed -gt 0) {
    exit 1
  }
}

# Container helper functions
function Start-TestContainer {
  param(
    [string]$Name,
    [string]$Image = "local/u/alpine/git-ssh-overwatch-devcontainer:latest",
    [hashtable]$Volumes = @{},
    [hashtable]$Environment = @{},
    [switch]$Detach,
    [string]$Command = ""
  )
    
  $dockerArgs = @("run", "--rm")
    
  if ($Detach) {
    $dockerArgs += "-d"
  }
    
  $dockerArgs += "--name", $Name
    
  foreach ($key in $Volumes.Keys) {
    $dockerArgs += "-v", "$($Volumes[$key]):$key"
  }
    
  foreach ($key in $Environment.Keys) {
    $dockerArgs += "-e", "$key=$($Environment[$key])"
  }
    
  $dockerArgs += $Image
    
  if ($Command) {
    $dockerArgs += "sh", "-c", $Command
  }
    
  $result = & docker @dockerArgs 2>&1
  return $result
}

function Stop-TestContainer {
  param([string]$Name)
    
  $null = docker stop $Name 2>&1
  $null = docker rm -f $Name 2>&1
}

function Invoke-ContainerCommand {
  param(
    [string]$Container,
    [string]$Command
  )
    
  $result = docker exec $Container sh -c $Command 2>&1
  return $result
}

function Test-ContainerRunning {
  param([string]$Name)
    
  $result = docker ps --filter "name=$Name" --format "{{.Names}}" 2>&1
  return $result -contains $Name
}

# File system helpers
function New-TestDirectory {
  param([string]$Name)
    
  $path = Join-Path $env:TEMP "git-ssh-test-$Name-$(Get-Random)"
  New-Item -ItemType Directory -Path $path -Force | Out-Null
  return $path
}

function Remove-TestDirectory {
  param([string]$Path)
    
  if (Test-Path $Path) {
    Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function New-TestCSV {
  param(
    [string]$Path,
    [array]$Entries
  )
    
  $csv = "url,path,name`n"
  foreach ($entry in $Entries) {
    $csv += "$($entry.url),$($entry.path),$($entry.name)`n"
  }
    
  Set-Content -Path $Path -Value $csv -NoNewline
}

# Image verification
function Test-ImageExists {
  param([string]$Image = "local/u/alpine/git-ssh-overwatch-devcontainer:latest")
    
  $result = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String -Pattern "^$Image$"
  return $null -ne $result
}

# Assert functions
function Assert-Equal {
  param(
    [string]$Actual,
    [string]$Expected,
    [string]$Message
  )
    
  if ($Actual -eq $Expected) {
    Write-TestPass $Message
    return $true
  }
  else {
    Write-TestFail $Message "Expected: '$Expected', Actual: '$Actual'"
    return $false
  }
}

function Assert-Contains {
  param(
    [string]$Haystack,
    [string]$Needle,
    [string]$Message
  )
    
  if ($Haystack -match [regex]::Escape($Needle)) {
    Write-TestPass $Message
    return $true
  }
  else {
    Write-TestFail $Message "Expected to find '$Needle' in output"
    return $false
  }
}

function Assert-NotContains {
  param(
    [string]$Haystack,
    [string]$Needle,
    [string]$Message
  )
    
  if ($Haystack -notmatch [regex]::Escape($Needle)) {
    Write-TestPass $Message
    return $true
  }
  else {
    Write-TestFail $Message "Did not expect to find '$Needle' in output"
    return $false
  }
}

function Assert-Success {
  param(
    [int]$ExitCode,
    [string]$Message
  )
    
  if ($ExitCode -eq 0 -or $LASTEXITCODE -eq 0) {
    Write-TestPass $Message
    return $true
  }
  else {
    Write-TestFail $Message "Exit code: $ExitCode or $LASTEXITCODE"
    return $false
  }
}

function Assert-CommandExists {
  param(
    [string]$Container,
    [string]$CommandName,
    [string]$Message
  )
    
  $result = Invoke-ContainerCommand -Container $Container -Command "command -v $CommandName"
    
  if ($result) {
    Write-TestPass $Message
    return $true
  }
  else {
    Write-TestFail $Message "Command '$CommandName' not found"
    return $false
  }
}

# Functions are available when dot-sourced
# Note: Export-ModuleMember is not needed when dot-sourcing (only for modules)
