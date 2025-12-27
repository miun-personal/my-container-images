#!/bin/sh
# repo-utils.sh - Shell library for managing multiple git repositories
# This library provides functions for common multi-repo operations
#
# Usage: Source this file in your shell profile
#   . /work/util/repo-utils.sh

# shellcheck disable=SC3043

# Configuration
# Use WORKSPACE_MANAGED_REPOS_HOME if set, otherwise fall back to REPOS_BASE_DIR or default
if [ -n "${WORKSPACE_MANAGED_REPOS_HOME:-}" ]; then
  REPOS_BASE_DIR="${WORKSPACE_MANAGED_REPOS_HOME}"
else
  REPOS_BASE_DIR="${REPOS_BASE_DIR:-/work/mnt/repos}"
fi
MANAGED_REPOS_CSV="${MANAGED_REPOS_CSV:-}"
THIS_REPO_DIR="${WORKSPACE_MAIN_REPO_HOME:-/work/mnt/this-repo}"

# Color output
_REPO_COLOR_RED='\033[0;31m'
_REPO_COLOR_GREEN='\033[0;32m'
_REPO_COLOR_YELLOW='\033[1;33m'
_REPO_COLOR_BLUE='\033[0;34m'
_REPO_COLOR_NC='\033[0m' # No Color

# Function to log messages
_repo_log() {
  printf '%s|%s\n' "$(date '+%H%M%S')" "${1}" >&2
}

# Function to check if a directory is a git repository
_repo_is_git_repo() {
  [ -d "$1/.git" ]
}

# Function to get repository status details
_repo_get_status() {
  local repo_path="$1"
    
  if ! _repo_is_git_repo "$repo_path"; then
    return 1
  fi
    
  cd "$repo_path" || return 1
    
  local branch commits_behind commits_ahead staged unstaged untracked merge_conflicts
    
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
    
  # Commits behind/ahead
  local upstream
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '')"
  if [ -n "$upstream" ]; then
    commits_behind="$(git rev-list --count HEAD.."$upstream" 2>/dev/null || echo '0')"
    commits_ahead="$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo '0')"
  else
    commits_behind="-"
    commits_ahead="-"
  fi
  
  # Staged files
  staged="$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
  
  # Unstaged files
  unstaged="$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
    
  # Untracked files
  untracked="$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"
    
  # Merge conflicts
  local conflict_count
  conflict_count="$(git ls-files -u 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$conflict_count" -gt 0 ]; then
    merge_conflicts="yes"
  else
    merge_conflicts="no"
  fi
    
  # Last commit date
  local last_commit
  last_commit="$(git log -1 --format="%cd" --date=short 2>/dev/null || echo 'unknown')"
    
  # Return status as CSV
  echo "$branch,$commits_behind,$commits_ahead,$staged,$unstaged,$untracked,$merge_conflicts,$last_commit"
}

# Function to check if repository has local changes
_repo_has_changes() {
  local repo_path="$1"
    
  if ! _repo_is_git_repo "$repo_path"; then
    return 1
  fi
  
  cd "$repo_path" || return 1

  # Check for any changes
  local has_changes=0

  # Check staged files
  if [ "$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
    has_changes=1
  fi
    
  # Check unstaged files
  if [ "$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
    has_changes=1
  fi
    
  # Check untracked files
  if [ "$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
    has_changes=1
  fi

  # Check commits ahead/behind
  local upstream
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '')"
  if [ -n "$upstream" ]; then
    local commits_behind commits_ahead
    commits_behind="$(git rev-list --count HEAD.."$upstream" 2>/dev/null || echo '0')"
    commits_ahead="$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo '0')"
    if [ "$commits_behind" -gt 0 ] || [ "$commits_ahead" -gt 0 ]; then
      has_changes=1
    fi
  fi
  
  return $((1 - has_changes))
}

# Function to find all git repositories under a base directory
_repo_find_all() {
  local base_dir="$1"
    
  if [ ! -d "$base_dir" ]; then
    return 0
  fi
    
  # Find all .git directories and return their parent paths
  find "$base_dir" -name ".git" -type d 2>/dev/null | while read -r git_dir; do
    dirname "$git_dir"
  done
}

# Function to fetch a single repository
_repo_fetch_one() {
  local repo_path="$1"
  local repo_name="${2:-$(basename "$repo_path")}"

  if ! _repo_is_git_repo "$repo_path"; then
    _repo_log "Error: $repo_path is not a git repository"
    return 1
  fi

  _repo_log "Fetching $repo_name..."
  
  cd "$repo_path" || return 1
  
  # Fetch all remotes
  if ! git fetch --all --prune 2>&1; then
    _repo_log "Error: Failed to fetch $repo_name"
    return 1
  fi
    
  # Get current branch
  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  
  if [ "$current_branch" = "unknown" ] || [ -z "$current_branch" ]; then
    _repo_log "Warning: Could not determine current branch for $repo_name, skipping pull"
    return 0
  fi
    
  # Update current branch if it has an upstream
  if git rev-parse --verify "@{upstream}" > /dev/null 2>&1; then
    _repo_log "Updating branch $current_branch in $repo_name..."
    if git pull --ff-only 2>&1; then
      _repo_log "Successfully updated $repo_name"
    else
      _repo_log "Warning: Could not fast-forward $repo_name (may have local changes)"
    fi
  else
    _repo_log "No upstream configured for branch $current_branch in $repo_name"
  fi

  return 0
}

# Function to clone or update repository from CSV entry
# CSV format: url,path,name
_repo_clone_or_update() {
  local url="$1"
  local parent_dir="$2"
  local repo_name="$3"
  
  local repo_path="${parent_dir}/${repo_name}"
  
  _repo_log "Processing: $repo_name at $repo_path"
  
  # Ensure parent directory exists
  if [ ! -d "$parent_dir" ]; then
    _repo_log "Creating parent directory: $parent_dir"
    mkdir -p "$parent_dir"
  fi
  
  if [ -d "$repo_path" ]; then
    # Repository exists, fetch it
    _repo_fetch_one "$repo_path" "$repo_name"
  else
    # Repository doesn't exist, clone it
    _repo_log "Cloning $repo_name from $url..."
    
    cd "$parent_dir" || return 1
    
    if git clone "$url" "$repo_name" 2>&1; then
      _repo_log "Successfully cloned $repo_name"
    else
      _repo_log "Error: Failed to clone $repo_name from $url"
      return 1
    fi
  fi
}

# Public function: fetch_all_repos
# Fetches all repositories from CSV (if configured) and all repos in base directory
fetch_all_repos() {
    printf "%b=== Fetching All Repositories ===%b\n" "$_REPO_COLOR_GREEN" "$_REPO_COLOR_NC"
    printf "\n"
    
    local total_processed=0
    
    # Process CSV if configured
    if [ -n "$MANAGED_REPOS_CSV" ] && [ -f "$MANAGED_REPOS_CSV" ]; then
        printf "%bProcessing managed repositories from CSV: %s%b\n" "$_REPO_COLOR_YELLOW" "$MANAGED_REPOS_CSV" "$_REPO_COLOR_NC"
        printf "\n"
        
        # Read CSV and process all repositories (format: url,path,name)
        tail -n +2 "$MANAGED_REPOS_CSV" > /dev/shm/fetch-repos-$$.tmp
        while IFS=',' read -r url parent_dir repo_name; do
            # Skip empty lines
            if [ -z "$url" ] || [ -z "$parent_dir" ] || [ -z "$repo_name" ]; then
                continue
            fi
            
            # Process all repositories without hostname filtering
            _repo_clone_or_update "$url" "$parent_dir" "$repo_name"
            total_processed=$((total_processed + 1))
        done < /dev/shm/fetch-repos-$$.tmp
        rm -f /dev/shm/fetch-repos-$$.tmp
    fi
    
    # Also fetch all existing repositories in the base directory
    if [ -d "$REPOS_BASE_DIR" ]; then
        printf "\n%bFetching existing repositories in %s%b\n" "$_REPO_COLOR_YELLOW" "$REPOS_BASE_DIR" "$_REPO_COLOR_NC"
        printf "\n"
        
        _repo_find_all "$REPOS_BASE_DIR" | while read -r repo_path; do
            local repo_name
            repo_name="$(basename "$repo_path")"
            _repo_fetch_one "$repo_path" "$repo_name"
            total_processed=$((total_processed + 1))
        done
    fi
    
    # Fetch this-repo if it exists
    if [ -d "$THIS_REPO_DIR" ] && _repo_is_git_repo "$THIS_REPO_DIR"; then
        printf "\n%bFetching main repository: %s%b\n" "$_REPO_COLOR_YELLOW" "$THIS_REPO_DIR" "$_REPO_COLOR_NC"
        _repo_fetch_one "$THIS_REPO_DIR" "this-repo"
        total_processed=$((total_processed + 1))
    fi
    
    printf "\n%b=== Fetch Complete ===%b\n" "$_REPO_COLOR_GREEN" "$_REPO_COLOR_NC"
    printf "Total repositories processed: %d\n" "$total_processed"
}

# Public function: show_all_local_changes
# Shows all repositories with local changes
show_all_local_changes() {
  printf "%b=== Repositories With Local Changes ===%b\n" "$_REPO_COLOR_GREEN" "$_REPO_COLOR_NC"
  printf "\n"
  
  local report_tmpfile="/dev/shm/repo-changes-$$.tmp"
  rm -f "$report_tmpfile"
  
  # Check this-repo
  if [ -d "$THIS_REPO_DIR" ] && _repo_is_git_repo "$THIS_REPO_DIR"; then
    if _repo_has_changes "$THIS_REPO_DIR"; then
      local status
      status="$(_repo_get_status "$THIS_REPO_DIR")"
      echo "$THIS_REPO_DIR,$status" >> "$report_tmpfile"
    fi
  fi
  
  # Check all repos in base directory
  if [ -d "$REPOS_BASE_DIR" ]; then
    _repo_find_all "$REPOS_BASE_DIR" | while read -r repo_path; do
      if _repo_has_changes "$repo_path"; then
        local repo_name
        repo_name="$(basename "$repo_path")"
        local status
        status="$(_repo_get_status "$repo_path")"
        echo "$repo_path,$status" >> "$report_tmpfile"
      fi
    done
  fi
  
  # Display report
  if [ -s "$report_tmpfile" ]; then
    local repo_count
    repo_count=$(wc -l < "$report_tmpfile")
    
    # Calculate maximum repository path length
    local max_repo_len=10
    while IFS=',' read -r repo _; do
      local repo_len=${#repo}
      if [ "$repo_len" -gt "$max_repo_len" ]; then
        max_repo_len=$repo_len
      fi
    done < "$report_tmpfile"
    
    # Add some padding
    max_repo_len=$((max_repo_len + 2))
    
    printf "%bFound %d repositories with changes:%b\n" "$_REPO_COLOR_YELLOW" "$repo_count" "$_REPO_COLOR_NC"
    printf "\n"
    printf "%-${max_repo_len}s %-15s %-8s %-8s %-8s %-10s %-10s %-10s %-12s\n" \
      "Repository" "Branch" "Behind" "Ahead" "Staged" "Unstaged" "Untracked" "Conflicts" "LastCommit"
    
    # Calculate separator length
    local sep_len=$((max_repo_len + 15 + 8 + 8 + 8 + 10 + 10 + 10 + 12 + 8))
    printf '%*s\n' "$sep_len" '' | tr ' ' '-'
    
    while IFS=',' read -r repo branch behind ahead staged unstaged untracked conflicts lastcommit; do
      printf "%-${max_repo_len}s %-15s %-8s %-8s %-8s %-10s %-10s %-10s %-12s\n" \
        "$repo" "$branch" "$behind" "$ahead" "$staged" "$unstaged" "$untracked" "$conflicts" "$lastcommit"
    done < "$report_tmpfile"
    
    printf '%*s\n' "$sep_len" '' | tr ' ' '-'
  else
    printf "%bNo repositories with local changes.%b\n" "$_REPO_COLOR_GREEN" "$_REPO_COLOR_NC"
  fi
  
  rm -f "$report_tmpfile"
}

# Public function: list_all_repos
# Lists all known repositories
list_all_repos() {
  printf "%b=== All Known Repositories ===%b\n" "$_REPO_COLOR_GREEN" "$_REPO_COLOR_NC"
  printf "\n"
  
  local count=0
  local tmpfile="/dev/shm/list-repos-$$.tmp"
  
  # List this-repo
  if [ -d "$THIS_REPO_DIR" ] && _repo_is_git_repo "$THIS_REPO_DIR"; then
    printf "%-30s %s\n" "this-repo" "$THIS_REPO_DIR"
    count=$((count + 1))
  fi
  
  # List repos in base directory
  if [ -d "$REPOS_BASE_DIR" ]; then
    _repo_find_all "$REPOS_BASE_DIR" > "$tmpfile"
    while read -r repo_path; do
      local repo_name
      repo_name="$(basename "$repo_path")"
      printf "%-30s %s\n" "$repo_name" "$repo_path"
      count=$((count + 1))
    done < "$tmpfile"
    rm -f "$tmpfile"
  fi
  
  printf "\n%bTotal: %d repositories%b\n" "$_REPO_COLOR_GREEN" "$count" "$_REPO_COLOR_NC"
}

# Public function: repo_status
# Shows detailed status of a specific repository
repo_status() {
    local repo_name="$1"
    
    if [ -z "$repo_name" ]; then
      printf "%bUsage: repo_status <repo-name>%b\n" "$_REPO_COLOR_RED" "$_REPO_COLOR_NC"
      return 1
    fi
    
    local repo_path=""
    
    # Check if it's this-repo
    if [ "$repo_name" = "this-repo" ] && [ -d "$THIS_REPO_DIR" ]; then
      repo_path="$THIS_REPO_DIR"
    else
      # Find in base directory
      local found_path
      found_path=$(_repo_find_all "$REPOS_BASE_DIR" | grep -F "/$repo_name\$" | head -1)
      if [ -n "$found_path" ]; then
        repo_path="$found_path"
      fi
    fi
    
    if [ -z "$repo_path" ]; then
      printf "%bRepository not found: %s%b\n" "$_REPO_COLOR_RED" "$repo_name" "$_REPO_COLOR_NC"
      return 1
    fi
    
    if ! _repo_is_git_repo "$repo_path"; then
      printf "%bNot a git repository: %s%b\n" "$_REPO_COLOR_RED" "$repo_path" "$_REPO_COLOR_NC"
      return 1
    fi
    
    printf "%b=== Status: %s ===%b\n" "$_REPO_COLOR_GREEN" "$repo_name" "$_REPO_COLOR_NC"
    printf "Path: %s\n" "$repo_path"
    printf "\n"
    
    cd "$repo_path" || return 1
    git status
}

# Create user-friendly aliases with hyphens
alias fetch-all='fetch_all_repos'
alias show-all-local-changes='show_all_local_changes'
alias list-all-repos='list_all_repos'
alias repo-status='repo_status'

# Export functions (not needed in sh but documents public API)
# Public API:
# - fetch-all (alias for fetch_all_repos)
# - show-all-local-changes (alias for show_all_local_changes)
# - list-all-repos (alias for list_all_repos)
# - repo-status <repo-name> (alias for repo_status)
