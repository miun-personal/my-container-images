# Build and Scan All Alpine Images
# This script builds all Alpine-based images and scans them with Trivy

$ErrorActionPreference = "Stop"

# Generate tag in format YYMDD (YY=year, M=hex month, DD=day)
function Get-ImageTag {
  $date = Get-Date
  $year = $date.ToString("yy")
  $month = "{0:X}" -f $date.Month  # Convert month to hex (1-C)
  $day = $date.ToString("dd")
  return "${year}${month}${day}"
}

$tag = Get-ImageTag
Write-Host "Using tag: $tag" -ForegroundColor Cyan
Write-Host ""

# Load image definitions from CSV
if (-not (Test-Path "images.csv")) {
  Write-Error "images.csv not found"
  exit 1
}

$images = Import-Csv -Path "images.csv"

Write-Host "=== Building and Scanning Alpine Images ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Build all images
Write-Host "Step 1: Building all images..." -ForegroundColor Yellow
Write-Host ""

foreach ($image in $images) {
  $fullImageName = "$($image.Repo):$tag"
  Write-Host "Building $fullImageName..." -ForegroundColor Green
  Push-Location $image.folder
  docker buildx build --build-arg __build_image_tag=$tag -t $fullImageName .
  if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Error "Failed to build $fullImageName"
    exit 1
  }
  Pop-Location
  Write-Host "✓ Built $fullImageName" -ForegroundColor Green
  Write-Host ""
}

# Step 2: Build the trivy-scanner image (if not already built)
Write-Host "Step 2: Ensuring trivy-scanner is ready..." -ForegroundColor Yellow
Write-Host ""

# Step 3: Scan all images with Trivy
Write-Host "Step 3: Scanning all images with Trivy..." -ForegroundColor Yellow
Write-Host ""

# Create timestamped scan folder
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$scanResultsBase = "scan-results"
$scanResults = "$scanResultsBase\$timestamp"
if (-not (Test-Path $scanResults)) {
  New-Item -ItemType Directory -Path $scanResults -Force | Out-Null
}

Write-Host "Scan results will be saved to: $scanResults\" -ForegroundColor Cyan
Write-Host ""

# Track image classifications for summary
$imageClassifications = @()

foreach ($image in $images) {
  $fullImageName = "$($image.Repo):$tag"
  $imageSafeName = $image.Repo.Replace('/', '-')
    
  Write-Host "Scanning $fullImageName..." -ForegroundColor Green
    
  # Get absolute path for volume mount
  $scanResultsAbsolute = (Resolve-Path $scanResults).Path
    
  docker run --rm `
    --user root `
    -v /var/run/docker.sock:/var/run/docker.sock `
    -v "${scanResultsAbsolute}:/reports" `
    miunpersonal/u-alpine-trivy-scanner:$tag `
    /usr/local/bin/scan-and-classify.sh "$fullImageName" "/reports" "$tag" "$imageSafeName"
    
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Scan of $fullImageName completed with warnings"
  }
  
  # Read classification to determine new tag
  $classificationFile = "$scanResults\classification-$imageSafeName.txt"
  if (Test-Path $classificationFile) {
    $classification = Get-Content $classificationFile -Raw
    
    # Extract classification details
    $classType = "UNKNOWN"
    $recommendedTag = ""
    $criticalCount = 0
    $highCount = 0
    $mediumCount = 0
    $lowCount = 0
    
    if ($classification -match 'Classification: (\w+)') {
      $classType = $matches[1]
    }
    if ($classification -match 'Recommended Tag: (.+)') {
      $recommendedTag = $matches[1].Trim()
    }
    if ($classification -match 'Critical Vulnerabilities: (\d+)') {
      $criticalCount = [int]$matches[1]
    }
    if ($classification -match 'High Vulnerabilities: (\d+)') {
      $highCount = [int]$matches[1]
    }
    if ($classification -match 'Medium Vulnerabilities: (\d+)') {
      $mediumCount = [int]$matches[1]
    }
    if ($classification -match 'Low Vulnerabilities: (\d+)') {
      $lowCount = [int]$matches[1]
    }
    
    # Store classification info
    $imageClassifications += [PSCustomObject]@{
      Image          = $image.Repo
      Classification = $classType
      Tag            = $recommendedTag
      Critical       = $criticalCount
      High           = $highCount
      Medium         = $mediumCount
      Low            = $lowCount
    }
    
    # Display classification
    $newImageName = "$($image.Repo):$recommendedTag"
    Write-Host "Classification: " -NoNewline
    $color = switch ($classType) {
      "PLATINUM" { "Cyan" }
      "GOLD" { "Yellow" }
      "SILVER" { "Gray" }
      "BRONZE" { "DarkYellow" }
      "UNQUALIFIED" { "Magenta" }
      "REJECTED" { "Red" }
      default { "White" }
    }
    Write-Host $classType -ForegroundColor $color
    
    # Only tag if not rejected
    if ($classType -ne 'REJECTED') {
      Write-Host "Tagging image as: $newImageName" -ForegroundColor Green
      docker tag $fullImageName $newImageName
    }
    else {
      Write-Host "Image REJECTED - not creating additional tag" -ForegroundColor Red
    }
  }
    
  Write-Host "✓ Scan reports saved to: $scanResults\" -ForegroundColor Green
  Write-Host ""
}

Write-Host "=== All builds and scans complete ===" -ForegroundColor Cyan
Write-Host ""

# Generate summary table
Write-Host "=== Image Classification Summary ===" -ForegroundColor Cyan
Write-Host ""
$imageClassifications | Format-Table -Property Image, Classification, Critical, High, Medium, Low, Tag -AutoSize

# Generate consolidated vulnerability report
Write-Host "=== Generating Consolidated Vulnerability Report ===" -ForegroundColor Cyan
Write-Host ""

$allVulnerabilities = @{}

foreach ($image in $images) {
  $imageSafeName = $image.Repo.Replace('/', '-')
  $sbomFile = "$scanResults\sbom-$imageSafeName.json"
  
  if (Test-Path $sbomFile) {
    Write-Host "Processing SBOM for $($image.Repo)..." -ForegroundColor Gray
    $sbomContent = Get-Content $sbomFile -Raw | ConvertFrom-Json
    
    # Parse vulnerabilities from SBOM components
    if ($sbomContent.components) {
      foreach ($component in $sbomContent.components) {
        if ($component.'bom-ref' -match 'pkg:') {
          # Get vulnerabilities for this component from metadata
          $componentRef = $component.'bom-ref'
          
          # Look for vulnerabilities in the vulnerabilities array
          if ($sbomContent.vulnerabilities) {
            foreach ($vuln in $sbomContent.vulnerabilities) {
              if ($vuln.affects -and $vuln.affects.ref -contains $componentRef) {
                $vulnId = $vuln.id
                
                # Determine severity
                $severity = "UNKNOWN"
                if ($vuln.ratings -and $vuln.ratings.Count -gt 0) {
                  $severity = $vuln.ratings[0].severity
                }
                
                if (-not $allVulnerabilities.ContainsKey($vulnId)) {
                  $description = ""
                  if ($vuln.description) {
                    $description = $vuln.description.Substring(0, [Math]::Min(100, $vuln.description.Length))
                    if ($vuln.description.Length -gt 100) { $description += "..." }
                  }
                  
                  $allVulnerabilities[$vulnId] = [PSCustomObject]@{
                    VulnerabilityID = $vulnId
                    Severity        = $severity
                    Description     = $description
                    AffectedImages  = @()
                  }
                }
                
                if ($allVulnerabilities[$vulnId].AffectedImages -notcontains $image.Repo) {
                  $allVulnerabilities[$vulnId].AffectedImages += $image.Repo
                }
              }
            }
          }
        }
      }
    }
  }
}

# Convert to array and sort by severity
$vulnReport = $allVulnerabilities.Values | ForEach-Object {
  [PSCustomObject]@{
    VulnerabilityID = $_.VulnerabilityID
    Severity        = $_.Severity
    AffectedImages  = ($_.AffectedImages -join ", ")
    ImageCount      = $_.AffectedImages.Count
    Description     = $_.Description
  }
} | Sort-Object @{Expression = {
    switch ($_.Severity) {
      "CRITICAL" { 1 }
      "HIGH" { 2 }
      "MEDIUM" { 3 }
      "LOW" { 4 }
      default { 5 }
    }
  }
}, VulnerabilityID

# Save vulnerability report
$vulnReportFile = "$scanResults\vulnerability-report-$tag.csv"
$vulnReport | Export-Csv -Path $vulnReportFile -NoTypeInformation
Write-Host "✓ Vulnerability report saved to: $vulnReportFile" -ForegroundColor Green

# Display summary
$criticalVulns = ($vulnReport | Where-Object { $_.Severity -eq "CRITICAL" }).Count
$highVulns = ($vulnReport | Where-Object { $_.Severity -eq "HIGH" }).Count
$mediumVulns = ($vulnReport | Where-Object { $_.Severity -eq "MEDIUM" }).Count
$lowVulns = ($vulnReport | Where-Object { $_.Severity -eq "LOW" }).Count

Write-Host ""
Write-Host "Unique Vulnerabilities Found:" -ForegroundColor Yellow
Write-Host "  CRITICAL: $criticalVulns" -ForegroundColor $(if ($criticalVulns -gt 0) { "Red" } else { "Green" })
Write-Host "  HIGH:     $highVulns" -ForegroundColor $(if ($highVulns -gt 0) { "Red" } else { "Green" })
Write-Host "  MEDIUM:   $mediumVulns" -ForegroundColor $(if ($mediumVulns -gt 0) { "Yellow" } else { "Green" })
Write-Host "  LOW:      $lowVulns" -ForegroundColor "Gray"
Write-Host ""
Write-Host "Scan results saved in: $scanResults\" -ForegroundColor Cyan
