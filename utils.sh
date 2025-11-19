#!/bin/sh

# shellcheck disable=SC3043

# Build and Scan All Alpine Images
# This script builds all Alpine-based images and scans them with Trivy

set -e

# Colors for output (using printf with escape sequences)
color_red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
color_green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
color_yellow() { printf '\033[1;33m%s\033[0m\n' "$1"; }
color_cyan() { printf '\033[0;36m%s\033[0m\n' "$1"; }
color_magenta() { printf '\033[0;35m%s\033[0m\n' "$1"; }
color_gray() { printf '\033[0;90m%s\033[0m\n' "$1"; }

# Generate tag in format YYMDD (YY=year, M=hex month, DD=day)
get_image_tag() {
  year=$(date +%y)
  month=$(date +%-m)
  month_hex=$(printf '%X' "$month")  # Convert month to hex (1-C)
  day=$(date +%d)
  echo "${year}${month_hex}${day}"
}

tag=$(get_image_tag)
color_cyan "Using tag: $tag"

assure_login_status(){
  # Check Docker Hub login
  color_yellow "Checking Docker Hub login status..."
  echo ""
  if ! buildah login --get-login docker.io >/dev/null 2>&1; then
    color_yellow "Not logged in to Docker Hub. Please log in to continue."
    echo ""
    echo ""
    if ! buildah login docker.io; then
      color_red "Error: Failed to log in to Docker Hub"
      echo "" >&2
      return 1
    fi
    echo ""
    color_green "✓ Successfully logged in to Docker Hub"
    echo ""
  else
    current_user=$(buildah login --get-login docker.io 2>/dev/null)
    color_green "✓ Already logged in to Docker Hub as: $current_user"
    echo ""
  fi
  echo ""
}

build_image(){
  local __image=$1
  local __folder=$2
  color_green "=== Building Image ${__image} from context folder ${__folder} ==="

  if [ ! -d "${__folder}" ]; then
    color_red "[build_image()] Fatal: folder ${__folder} does not exist"
    return 1
  fi
  if [ ! -f "${__folder}/Dockerfile" ];then
    color_red "[build_image()] Fatal: folder ${__folder} is not a build context!"
    return 2
  fi

  local __crtPath
  __crtPath="$(pwd)"

  cd "${__folder}" || return 3

  if ! buildah bud --build-arg "__build_image_tag=${tag}" --isolation=chroot -t "$full_image_name" .; then
    cd - > /dev/null
    color_red "[build_image()] Error: Failed to build $full_image_name"
    echo "" >&2
    return 3
  fi

  cd "${__crtPath}" || return 4
  color_green "✓ Built $full_image_name"
  return 0
}

build_all(){
  # Check if images.csv exists
  if [ ! -f "images.csv" ]; then
    color_red "[build_all()] Error: images.csv not found"
    return 1
  fi
  color_yellow "[build_all()] Building all images..."
  # Read CSV file (skip header) and build images
  tail -n +2 images.csv | while IFS=, read -r repo folder || [ -n "$repo" ]; do
    # Trim whitespace
    repo=$(echo "$repo" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    folder=$(echo "$folder" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    build_image "docker.io/${repo}:${tag}" "$folder"
  done
}

get_shm_dir_for_image(){
  echo "/dev/shm/my-images-data/$(echo "${1}" | tr '/.:' '_')"
}

scan_image(){
  local __image=$1
  color_green "[scan_image()] Scanning $__image..."
  if ! buildah inspect "${__image}" >/dev/null 2>&1; then
    color_red "[scan_image()] Fatal: Cannot inspect image $1"
    return 1
  fi

  local __shm_image_dir
  __shm_image_dir=$(get_shm_dir_for_image "${__image}")

  mkdir -p "${__shm_image_dir}"

  local __scan_file="${__shm_image_dir}/scan.txt"
  local __cmd_base="trivy image --offline-scan --cache-dir /mnt/trivy-cache  --exit-code 3"
  local __cmd_scan="${__cmd_base} --format table --output ""${__scan_file}"""
  __cmd_scan="${__cmd_scan} \"$__image\""

  local __scan_stdout="${__shm_image_dir}/scan.stdout"
  local __scan_stderr="${__shm_image_dir}/scan.stderr"

  # Run Trivy scan
  #echo "DEBUG: About to run: ${__cmd_scan}"
  #echo "DEBUG: Command (hex): $(echo -n "${__cmd_scan}" | xxd)"
  if ! eval "${__cmd_scan}" >"${__scan_stdout}" 2>"${__scan_stderr}"; then
    color_yellow "[scan_image()] Warning: Scan of $__image completed with warnings: code $?"
    echo "========= command was ==============="
    echo "${__cmd_scan}"
    echo "========= stdout      ==============="
    cat "${__scan_stdout}"
    echo "========= stderr      ==============="
    cat "${__scan_stderr}"
    echo "========= scan result ==============="
    cat "${__scan_file}"
    echo "========= end         ==============="
  fi

  local __sbom_file="${__shm_image_dir}/sbom.json"
  local __cmd_sbom="${__cmd_base} --format cyclonedx --output ""${__sbom_file}"" ""$__image"""
  local __sbom_stdout="${__shm_image_dir}/sbom.stdout"
  local __sbom_stderr="${__shm_image_dir}/sbom.stderr"
  
  # Generate SBOM
  if ! eval "${__cmd_sbom}" >"${__sbom_stdout}" 2>"${__sbom_stderr}"; then
    color_yellow "[scan_image()] Warning: Creation of cyclonedx sbom form image $__image completed with warnings: code $?"
    echo "========= command was ==============="
    echo "${__cmd_sbom}"
    echo "========= stdout      ==============="
    cat "${__sbom_stdout}"
    echo "========= stderr      ==============="
    cat "${__sbom_stderr}"
    echo "========= end         ==============="
  fi
}

classify_image(){
  local __image="$1"
  color_green "[classify_image()] Classifying $__image..."

  local __shm_image_dir
  __shm_image_dir=$(get_shm_dir_for_image "${__image}")

  if [ ! -f "${__shm_image_dir}/sbom.json" ]; then
    if ! scan_image "${__image}" ; then
      color_red "ERROR: scanning of image ${__image} failed, cannot classify. Code $?"
    fi
  fi

    # Count vulnerabilities by severity
  local critical_count=0
  local high_count=0
  local medium_count=0
  local low_count=0
  local __scan_file="${__shm_image_dir}/scan.txt"

  if [ -f "$__scan_file" ]; then
    critical_count=$(grep -c "CRITICAL" "$__scan_file" || true)
    high_count=$(grep -c "HIGH" "$__scan_file" || true)
    medium_count=$(grep -c "MEDIUM" "$__scan_file" || true)
    low_count=$(grep -c "LOW" "$__scan_file" || true)
  fi

  # Determine classification based on vulnerability counts
  local class_type=""
  if [ "$critical_count" -gt 0 ]; then
    class_type="REJECTED"
  elif [ "$high_count" -gt 0 ]; then
    class_type="BRONZE"
  elif [ "$medium_count" -gt 5 ]; then
    class_type="SILVER"
  elif [ "$medium_count" -gt 0 ]; then
    class_type="GOLD"
  else
    class_type="PLATINUM"
  fi

  # Create recommended tag
  recommended_tag="${tag}-$(echo "$class_type" | tr '[:upper:]' '[:lower:]')"

  # Save classification report
  classification_file="${__shm_image_dir}/classification.txt"
  {
    echo "Image Classification Report"
    echo "==========================="
    echo "Image: $full_image_name"
    echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Vulnerability Summary:"
    echo "  Critical Vulnerabilities: $critical_count"
    echo "  High Vulnerabilities: $high_count"
    echo "  Medium Vulnerabilities: $medium_count"
    echo "  Low Vulnerabilities: $low_count"
    echo ""
    echo "Classification: $class_type"
    echo "Recommended Tag: $recommended_tag"
  } > "$classification_file"

  # Save classification csv
  classification_csv_file="${__shm_image_dir}/classification.csv"
  echo "$__image,$class_type,$recommended_tag,$critical_count,$high_count,$medium_count,$low_count" >> "$classification_csv_file"
}

classify_all(){
  rm -rf /dev/shm/my-images-data
  # Check if images.csv exists
  if [ ! -f "images.csv" ]; then
    color_red "[classify_all()] Error: images.csv not found"
    return 1
  fi

  color_yellow "[classify_all()] Classifying all images..."
  # Read CSV file (skip header) and build images
  tail -n +2 images.csv | while IFS=, read -r repo folder || [ -n "$repo" ]; do
    # Trim whitespace
    repo=$(echo "$repo" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    classify_image "docker.io/${repo}:${tag}"
  done

  # Generate summary table from all /dev/shm/my-images-data/*/classification.csv
  color_cyan "=== Image Classification Summary (from /dev/shm/my-images-data) ==="
  echo ""
  echo ""

  print_classification_report

  cp -r /dev/shm/my-images-data "$scan_results"/
}

print_classification_report(){
  printf "%-15s %-8s %-4s %-6s %-3s %-15s %s\n" "Classification" "Critical" "High" "Medium" "Low" "Tag" "Image"
  printf "%-15s %-8s %-4s %-6s %-3s %-15s %s\n" "--------------" "--------" "----" "------" "---" "---" "-----"
  for dir in /dev/shm/my-images-data/*; do
    [ -d "$dir" ] || continue
    class_csv="$dir/classification.csv"
    [ -f "$class_csv" ] || continue
    IFS=',' read -r image_name class_type recommended_tag critical high medium low < "$class_csv"
    printf "%-15s %-8s %-4s %-6s %-3s %-15s %s\n" "$class_type" "$critical" "$high" "$medium" "$low" "$recommended_tag" "$image_name"
  done
  echo ""

  timestamp=$(date +%Y%m%d-%H%M%S)
  scan_results_base="scan-results"
  scan_results="${scan_results_base}/${timestamp}"
  mkdir -p "$scan_results"
}

push_platinums(){
  for dir in /dev/shm/my-images-data/*; do
    [ -d "$dir" ] || continue
    class_csv="$dir/classification.csv"
    [ -f "$class_csv" ] || continue
    IFS=',' read -r image_name class_type recommended_tag critical high medium low < "$class_csv"

    local __latest_tag
    
    if [ "$class_type" = "PLATINUM" ]; then
      # shellcheck disable=SC3060
      __latest_tag="${image_name//:${tag}/:latest}"
      buildah tag "$image_name" "$image_name-platinum"
      buildah tag "$image_name" "$__latest_tag"
      buildah tag "$image_name" "$__latest_tag-platinum"
      echo "Pushing ""$image_name""" 
      buildah push "$image_name"

      echo "Pushing ""$image_name-platinum""" 
      buildah push "$image_name-platinum"

      echo "Pushing ""$__latest_tag""" 
      buildah push "$__latest_tag"

      echo "Pushing ""$__latest_tag-platinum""" 
      buildah push "$__latest_tag-platinum"
    fi
  
  done
}