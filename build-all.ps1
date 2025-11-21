# Build All Images in the images.csv file, in order

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

Write-Host "Building all images..." -ForegroundColor Yellow
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
