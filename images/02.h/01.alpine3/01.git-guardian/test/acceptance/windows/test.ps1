
# Pester-based test harness for container images
# Save as: test-container-image.ps1

function Get-ImageTag {
  $date = Get-Date
  $year = $date.ToString("yy")
  $month = "{0:X}" -f $date.Month  # Convert month to hex (1-C)
  $day = $date.ToString("dd")
  return "${year}${month}${day}"
}

$tag = Get-ImageTag
$fullImgName = "miunpersonal/h-alpine-git-ssh-client:$tag"

Describe "Container Image Tests: $fullImgName" {

  BeforeAll {
    # Start a persistent container for exec/alias tests
    $tag = Get-ImageTag
    $fullImgName = "miunpersonal/h-alpine-git-ssh-client:$tag"
    $testContainerName = "test-repo-utils-$(Get-Random)"
  }

  It "Image exists locally" {
    $images = docker images --format "{{.Repository}}:{{.Tag}}"
    $images | Should -Contain $fullImgName
  }

  It "Image is runnable (exits 0)" {
    $result = docker run --rm $fullImgName echo ok
    $LASTEXITCODE | Should -Be 0
    $result | Should -Match "ok"
  }

  It "ENV points correctly" {
    $result = docker run --rm $fullImgName env | Select-String -Pattern "ENV="
    $result | Should -Be "ENV=/work/.ashrc"
  }

  It "ll alias defined correctly" {
    $result = docker run --rm "$fullImgName" "cat" "/work/.ashrc" | Select-String -Pattern "alias ll="
    $result | Should -Be 'alias ll="ls -lah"'
  }

}

# Additional tests for repo-utils.sh
$testContainerName = "test-repo-utils-$(Get-Random)"

Describe "repo-utils.sh functions in container (persistent)" {
  BeforeAll {
    # Start a persistent container for exec/alias tests
    $tag = Get-ImageTag
    $fullImgName = "miunpersonal/h-alpine-git-ssh-client:$tag"
    $testContainerName = "test-repo-utils-$(Get-Random)"
    docker run -d --name "${testContainerName}" "${fullImgName}" sleep infinity | Out-Null
  }
  AfterAll {
    # Clean up the container
    docker rm -f $testContainerName | Out-Null
  }

  It "repo-utils.sh is present in the image" {
    $result = docker exec $testContainerName sh -c "test -f /work/util/repo-utils.sh"
    $LASTEXITCODE | Should -Be 0
  }

  It "_repo_is_git_repo returns success for a git repo" {
    $result = docker exec $testContainerName sh -c "git init /tmp/testrepo >/dev/null 2>&1 && . /work/util/repo-utils.sh && _repo_is_git_repo /tmp/testrepo"
    $LASTEXITCODE | Should -Be 0
  }

  It "_repo_is_git_repo returns failure for non-git dir" {
    $result = docker exec $testContainerName sh -c "mkdir -p /tmp/notrepo && . /work/util/repo-utils.sh && _repo_is_git_repo /tmp/notrepo"
    $LASTEXITCODE | Should -Not -Be 0
  }

  It "_repo_get_status outputs branch info for a git repo" {
    $result = docker exec $testContainerName sh -c "git init /tmp/testrepo2 >/dev/null 2>&1 && . /work/util/repo-utils.sh && _repo_get_status /tmp/testrepo2"
    $result | Should -Match "unknown|master|main|HEAD"
  }

  It "aliases from repo-utils.sh are available in login shell" {
    $result = docker exec $testContainerName sh -lc ". /work/.ashrc && alias | grep ll"
    $LASTEXITCODE | Should -Be 0
  }
}

Install-Module -Name Pester -Force -RequiredVersion 5.7.1