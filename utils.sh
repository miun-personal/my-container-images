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

init(){
  ## Private constants
  __TRIVY_BASE_COMMAND='trivy image --offline-scan --cache-dir /mnt/trivy-cache'
  __IMAGE_METADATA_HOME='/dev/shm/images/metadata'
  # Trivy Settings
  __TR_CACHE="${TRIVY_CACHE_DIR:-/tmp/trivy-cache}"
  mkdir -p "${__TR_CACHE}"
  # Trivy global flags
  __TR_GF="--cache-dir ""${__TR_CACHE}"" --exit-code 3"
  # Trivy base command
  __TR_BC="trivy ${__TR_GF}"
}
init

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
    color_red "[build_image()] Info: current folder is: $(pwd)"
    return 1
  fi
  if [ ! -f "${__folder}/Dockerfile" ];then
    color_red "[build_image()] Fatal: folder ${__folder} is not a build context!"
    return 2
  fi

  local __crtPath
  __crtPath="$(pwd)"

  cd "${__folder}" || return 3

  if ! buildah bud --build-arg "__build_image_tag=${tag}" --isolation=chroot -t "$__image" .; then
    cd - > /dev/null
    color_red "[build_image()] Error: Failed to build $__image"
    echo "" >&2
    return 3
  fi

  cd "${__crtPath}" || return 4
  color_green "✓ Built $__image"
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

__scan_sbom(){
  # Parameters
  # $1 - SBOM file to scan
  # $2 - destination file
  # $3 - which scanners OPTIONAL, default vuln
  # $4 - which format OPTIONAL, default table

  local __scanners="${3:-vuln}"
  local __format="${4:-table}"

  color_cyan "[__scan_sbom()] Scanning Cyclone DX SBOM from file ${2} using scanners ${__scanners} and format ${__format}..."

  local __cmd_scan="${__TR_BC} sbom --offline-scan --scanners ${__scanners} --format ${__format}"
  __cmd_scan="${__cmd_scan} --output ""${2}"""
  __cmd_scan="${__cmd_scan} ""${1}"""
  local __ts
  __ts=$(date +%s)

  local __scan_stdout="${2}.${__ts}.stdout"
  local __scan_stderr="${2}.${__ts}.stderr"

  # Generate SBOM
  if ! eval "${__cmd_scan}" >"${__scan_stdout}" 2>"${__scan_stderr}"; then
    color_yellow "[__scan_sbom()] Warning: Creation of cyclonedx sbom for tar export ${1} completed with warnings: code $?"
    echo "========= command was ==============="
    echo "${__cmd_scan}"
    echo "========= stdout      ==============="
    cat "${__scan_stdout}"
    echo "========= stderr      ==============="
    cat "${__scan_stderr}"
    echo "========= end         ==============="
  fi
}

__scan_sbom_for_vulnerabilities(){
  __scan_sbom "$1" "$2" "vuln"
}

__scan_sbom_for_licenses(){
  # Params
  # $1 - sbom to scan
  # $2 - image destination directory
  __scan_sbom "$1" "$2"/licenses.txt "license" "table"
  __scan_sbom "$1" "$2"/licenses.spdx.txt "license" "spdx"
  __scan_sbom "$1" "$2"/licenses.spdx.json "license" "spdx-json"
}

__scan_img_tar_for_misconfiguration(){
  # Parameters
  # $1 - tar file of an exported image
  # $2 - destination directory

  local __out_fileName="${2}/misconfiguration-and-secrets.txt"

  color_cyan "[__scan_img_tar_for_misconfiguration()] Scanning image tar file ${1} for misconfigurations..."

  local __cmd_scan="${__TR_BC} image  --offline-scan --format table --input ""${1}"""
  __cmd_scan="${__cmd_scan} --output ""${__out_fileName}"""
  local __ts 
  __ts=$(date +%s)

  local __scan_stdout="${__out_fileName}.${__ts}.stdout"
  local __scan_stderr="${__out_fileName}.${__ts}.stderr"

  # Generate SBOM
  if ! eval "${__cmd_scan}" >"${__scan_stdout}" 2>"${__scan_stderr}"; then
    color_yellow "[__scan_img_tar_for_misconfiguration()] Warning: Creation of cyclonedx sbom for tar export ${1} completed with warnings: code $?"
    echo "========= command was ==============="
    echo "${__cmd_scan}"
    echo "========= stdout      ==============="
    cat "${__scan_stdout}"
    echo "========= stderr      ==============="
    cat "${__scan_stderr}"
    echo "========= end         ==============="
  fi
}

__generate_sbom_from_tar(){
  # Parameters
  # $1 - tar file of an exported image
  # $2 - destination file
  color_cyan "[__generate_sbom_from_tar()] Generating a complete Cyclone DX SBOM for tar file ${1} into output file ${2}..."

  local __cmd="${__TR_BC} image --offline-scan --license-full --format cyclonedx"
  __cmd="${__cmd} --scanners vuln,misconfig,secret,license"
  __cmd="${__cmd} --output ""${2}"" --input ""$1"" "
  local __ts 
  __ts=$(date +%s)

  local __sbom_stdout="${2}.${__ts}.stdout"
  local __sbom_stderr="${2}.${__ts}.stderr"
  
  # Generate SBOM
  if ! eval "${__cmd}" >"${__sbom_stdout}" 2>"${__sbom_stderr}"; then
    color_yellow "[__generate_sbom_from_tar()] Warning: Creation of cyclonedx sbom for tar export ${1} completed with warnings: code $?"
    echo "========= command was ==============="
    echo "${__cmd_sbom}"
    echo "========= stdout      ==============="
    cat "${__sbom_stdout}"
    echo "========= stderr      ==============="
    cat "${__sbom_stderr}"
    echo "========= end         ==============="
  fi
}

scan_image(){
  ## Notes
    # Tactic is to scan is SBOM first, then vulnerabilities on sbom, then misconfiguration
    # Extend as needed with iterations
    # Results are stored in /dev/shm/my-images-data on a per image basis

  local __image=$1
  color_green "[scan_image()] Scanning $__image..."
  if ! buildah inspect "${__image}" >/dev/null 2>&1; then
    color_red "[scan_image()] Fatal: Cannot inspect image $1. Was it built before?"
    return 1
  fi

  local __shm_image_dir
  __shm_image_dir=$(get_shm_dir_for_image "${__image}")
  mkdir -p "${__shm_image_dir}"

  mkdir -p "${TRIVY_CACHE_DIR}/scanned_images"
  local __shm_image_tar
  __shm_image_tar="${TRIVY_CACHE_DIR}/scanned_images/img_$(date +%s).tar"

  color_cyan "[scan_image()] Exporting the image ${__image} into tar file ${__shm_image_tar} ..."
  buildah push --format docker "${__image}" "docker-archive:${__shm_image_tar}"

  # Step 1 - generate SBOM
  local __sbom_file="${__shm_image_dir}/sbom.json"
  __generate_sbom_from_tar "${__shm_image_tar}" "${__sbom_file}"

  # Step 2 - scan for vulnerabilities based on sbom
  local __scan_file="${__shm_image_dir}/scan.txt"
  __scan_sbom_for_vulnerabilities "${__sbom_file}" "${__scan_file}"

  # Step 3 - scan for licenses based on sbom
  __scan_sbom_for_licenses "${__sbom_file}" "${__shm_image_dir}"

  # Step 4 - scan for misconfiguration and secrets
  __scan_img_tar_for_misconfiguration "${__shm_image_tar}" "${__shm_image_dir}"
}

classify_image(){
  local __image="$1"
  local __shm_image_dir
  __shm_image_dir=$(get_shm_dir_for_image "${__image}")

  if [ ! -f "${__shm_image_dir}/sbom.json" ]; then
    if ! scan_image "${__image}" ; then
      color_red "ERROR: scanning of image ${__image} failed, cannot classify. Code $?"
    fi
  fi

  color_cyan "[classify_image()] Classifying $__image..."

  # Count vulnerabilities by severity
  local critical_count=0
  local high_count=0
  local medium_count=0
  local low_count=0
  local __sbom_file="${__shm_image_dir}/sbom.json"

  if [ -f "$__sbom_file" ]; then
    local __jq_query='[.vulnerabilities[]? | select([.ratings[]? | .severity == "critical"] | any)] | length'
    critical_count=$(jq "${__jq_query}" "${__sbom_file}" || echo 0)
    __jq_query='[.vulnerabilities[]? | select([.ratings[]? | .severity == "high"] | any)] | length'
    high_count=$(jq "${__jq_query}" "${__sbom_file}" || echo 0)
    __jq_query='[.vulnerabilities[]? | select([.ratings[]? | .severity == "medium"] | any)] | length'
    medium_count=$(jq "${__jq_query}" "${__sbom_file}" || echo 0)
    __jq_query='[.vulnerabilities[]? | select([.ratings[]? | .severity == "low"] | any)] | length'
    low_count=$(jq "${__jq_query}" "${__sbom_file}" || echo 0)
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
  color_green "[classify_image()] Recommended tag is ${recommended_tag}"

  # Save classification report
  classification_file="${__shm_image_dir}/classification.txt"
  {
    echo "Image Classification Report"
    echo "==========================="
    echo "Image: $1"
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

  color_cyan "Applying tags..."
  # apply tags
  buildah tag "$1" "${1%%:*}:${tag}-${class_type}"
  buildah tag "$1" "${1%%:*}:latest-${class_type}"
  buildah tag "$1" "${1%%:*}:latest"

  color_green "Classification done"
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

push_image_with_tags(){
  # Params
  # $1 - image without tag (e.g., docker.io/miunpersonal/sa3-bind-ci-agent)
  local image_base="$1"
  # Ensure we are logged in before pushing
  assure_login_status
  # Get all tags for this image base
  buildah images | awk -v img="$image_base" '$1 == img {print $1":"$2}' | while read -r full_tag; do
    color_cyan "Pushing $full_tag ..."
    buildah push "$full_tag"
  done
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