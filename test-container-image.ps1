# Pester-based test harness for container images
# Save as: test-container-image.ps1

param(
  [Parameter(Mandatory = $true)]
  [string]$ImageName
)

Describe "Container Image Tests: $ImageName" {
  It "Image exists locally" {
    $images = docker images --format "{{.Repository}}:{{.Tag}}"
    $images | Should -Contain $ImageName
  }

  It "Image is runnable (exits 0)" {
    $result = docker run --rm $ImageName echo ok
    $LASTEXITCODE | Should -Be 0
    $result | Should -Match "ok"
  }
}
