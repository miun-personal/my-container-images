# run-all-tests.ps1 - Run all acceptance tests

param(
  [string]$ImageName = "local/u/alpine/git-ssh-overwatch-devcontainer:latest",
  [string]$TestPattern = "test-*.ps1"
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Git SSH Client - Acceptance Test Suite" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Image: $ImageName" -ForegroundColor Yellow
Write-Host "Test Pattern: $TestPattern`n" -ForegroundColor Yellow

# Check if Docker is running
$dockerCheck = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] Docker is not running or not accessible" -ForegroundColor Red
  Write-Host "Please ensure Docker/Rancher Desktop is running and try again." -ForegroundColor Yellow
  exit 1
}

Write-Host "[OK] Docker is running`n" -ForegroundColor Green

# Build the image
Write-Host "Building image: $ImageName" -ForegroundColor Yellow
$dockerfileDir = Join-Path $PSScriptRoot "..\..\.."
Write-Host "Dockerfile directory: $dockerfileDir`n" -ForegroundColor Gray

$buildOutput = docker build -t $ImageName $dockerfileDir 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] Failed to build image" -ForegroundColor Red
  Write-Host "Build output:" -ForegroundColor Yellow
  Write-Host $buildOutput
  exit 1
}

Write-Host "[OK] Image '$ImageName' built successfully`n" -ForegroundColor Green

# Find all test scripts (exclude test-helpers.ps1)
$testScripts = Get-ChildItem -Path $PSScriptRoot -Filter $TestPattern | 
Where-Object { $_.Name -ne "test-helpers.ps1" } | 
Sort-Object Name

if ($testScripts.Count -eq 0) {
  Write-Host "[ERROR] No test scripts found matching pattern '$TestPattern'" -ForegroundColor Red
  exit 1
}

Write-Host "Found $($testScripts.Count) test script(s):`n" -ForegroundColor Yellow
foreach ($script in $testScripts) {
  Write-Host "  - $($script.Name)" -ForegroundColor Gray
}
Write-Host ""

# Initialize counters
$totalTests = 0
$passedTests = 0
$failedTests = 0
$skippedTests = 0
$failedScripts = @()

# Run each test script
foreach ($script in $testScripts) {
  Write-Host "`n========================================" -ForegroundColor Cyan
  Write-Host "Running: $($script.Name)" -ForegroundColor Cyan
  Write-Host "========================================`n" -ForegroundColor Cyan
    
  $startTime = Get-Date
    
  # Run the test script
  & $script.FullName -ImageName $ImageName
    
  $exitCode = $LASTEXITCODE
  $duration = (Get-Date) - $startTime
    
  Write-Host "`nCompleted in $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor Gray
    
  if ($exitCode -eq 0) {
    Write-Host "[PASS] $($script.Name) completed successfully`n" -ForegroundColor Green
    $passedTests++
  }
  else {
    Write-Host "[FAIL] $($script.Name) failed with exit code $exitCode`n" -ForegroundColor Red
    $failedTests++
    $failedScripts += $script.Name
  }
    
  $totalTests++
}

# Print final summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "FINAL TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Test Scripts: $totalTests" -ForegroundColor Yellow
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "Green" })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($failedTests -gt 0) {
  Write-Host "Failed test scripts:" -ForegroundColor Red
  foreach ($script in $failedScripts) {
    Write-Host "  - $script" -ForegroundColor Red
  }
  Write-Host ""
  exit 1
}
else {
  Write-Host "[PASS] All test scripts passed successfully!`n" -ForegroundColor Green
  exit 0
}
