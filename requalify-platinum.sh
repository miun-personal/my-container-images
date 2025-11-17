#!/bin/sh
# Re-qualify Platinum Images
# This script pulls all platinum-tagged images from Docker Hub,
# re-scans them for vulnerabilities, and updates their classification
# if they have been degraded due to newly discovered vulnerabilities.

set -e

# Colors for output (using printf with escape sequences)
color_red() { printf '\033[0;31m%s\033[0m' "$1"; }
color_green() { printf '\033[0;32m%s\033[0m' "$1"; }
color_yellow() { printf '\033[1;33m%s\033[0m' "$1"; }
color_cyan() { printf '\033[0;36m%s\033[0m' "$1"; }
color_magenta() { printf '\033[0;35m%s\033[0m' "$1"; }
color_gray() { printf '\033[0;90m%s\033[0m' "$1"; }

color_cyan "=== Platinum Image Re-qualification ==="
echo ""
echo ""

# Check Docker Hub login and get JWT token for API access
color_yellow "Checking Docker Hub login status..."
echo ""
if ! buildah login --get-login docker.io >/dev/null 2>&1; then
  color_yellow "Not logged in to Docker Hub. Please log in to continue."
  echo ""
  echo ""
  if ! buildah login docker.io; then
    color_red "Error: Failed to log in to Docker Hub"
    echo "" >&2
    exit 1
  fi
  echo ""
  color_green "✓ Successfully logged in to Docker Hub"
  echo ""
else
  current_user=$(buildah login --get-login docker.io 2>/dev/null)
  color_green "✓ Already logged in to Docker Hub as: $current_user"
  echo ""
fi

# Get Docker Hub JWT token for API operations
color_yellow "Authenticating with Docker Hub API for tag management..."
echo ""
username=$(buildah login --get-login docker.io 2>/dev/null)
printf "Enter Docker Hub token/password for $username: "
read -r docker_password

jwt_token=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$username\",\"password\":\"$docker_password\"}" \
  "https://hub.docker.com/v2/users/login/" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$jwt_token" ]; then
  color_red "Error: Failed to authenticate with Docker Hub API"
  echo "" >&2
  exit 1
fi

color_green "✓ Successfully authenticated with Docker Hub API"
echo ""
echo ""

# Check if images.csv exists
if [ ! -f "images.csv" ]; then
  color_red "Error: images.csv not found"
  echo "" >&2
  exit 1
fi

# Create timestamped scan folder
timestamp=$(date +%Y%m%d-%H%M%S)
scan_results_base="scan-results"
scan_results="${scan_results_base}/requalify-${timestamp}"
mkdir -p "$scan_results"

color_cyan "Scan results will be saved to: ${scan_results}/"
echo ""
echo ""

# Track results
results_file="$scan_results/.requalify_results.tmp"
: > "$results_file"

color_yellow "Step 1: Discovering platinum-tagged images..."
echo ""
echo ""

# Read each repository and find platinum tags
tail -n +2 images.csv | while IFS=, read -r repo folder || [ -n "$repo" ]; do
  # Trim whitespace
  repo=$(echo "$repo" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  color_cyan "Checking $repo for platinum tags..."
  echo ""
  
  # Use Docker Hub API to list tags
  # Extract namespace and repository name
  namespace=$(echo "$repo" | cut -d'/' -f1)
  repository=$(echo "$repo" | cut -d'/' -f2)
  
  # Query Docker Hub API for tags
  platinum_tags=$(curl -s "https://registry.hub.docker.com/v2/repositories/${namespace}/${repository}/tags/?page_size=100" | \
    grep -o '"name":"[^"]*-platinum"' | \
    cut -d'"' -f4 || true)
  
  # If more than 100 tags, we may need pagination, but this is a simple approach
  if [ -z "$platinum_tags" ]; then
    # Fallback: try common recent patterns (last 2 years)
    platinum_tags=""
    for year in 24 25; do
      for month in 1 2 3 4 5 6 7 8 9 A B C; do
        for day in $(seq -w 1 31); do
          tag="${year}${month}${day}-platinum"
          # Just check if tag exists using curl (much faster than pull)
          if curl -s "https://registry.hub.docker.com/v2/repositories/${namespace}/${repository}/tags/${tag}" | grep -q "\"name\":\"${tag}\""; then
            platinum_tags="${platinum_tags}${tag}
"
          fi
        done
      done
    done
  fi
  
  if [ -z "$platinum_tags" ]; then
    color_gray "  No platinum tags found"
    echo ""
  else
    echo "$platinum_tags" | while read -r ptag; do
      [ -z "$ptag" ] && continue
      echo "$repo|$ptag" >> "$results_file"
      color_green "  Found: $repo:$ptag"
      echo ""
    done
  fi
  echo ""
done

if [ ! -s "$results_file" ]; then
  color_yellow "No platinum-tagged images found. Nothing to requalify."
  echo ""
  exit 0
fi

color_yellow "Step 2: Re-scanning platinum images..."
echo ""
echo ""

# Track reclassification summary
summary_file="$scan_results/.summary.tmp"
: > "$summary_file"

# Process each platinum image
while IFS='|' read -r repo ptag; do
  [ -z "$repo" ] && continue
  
  # Extract the date tag from platinum tag (remove -platinum suffix)
  date_tag=$(echo "$ptag" | sed 's/-platinum$//')
  full_image_name="docker.io/${repo}:${ptag}"
  image_safe_name=$(echo "$repo" | tr '/' '-')
  
  color_cyan "Processing $full_image_name..."
  echo ""
  
  # Pull the image
  color_yellow "  Pulling image..."
  echo ""
  if ! buildah pull "$full_image_name"; then
    color_red "  Failed to pull $full_image_name"
    echo ""
    continue
  fi
  
  # Scan with Trivy
  color_yellow "  Scanning for vulnerabilities..."
  echo ""
  scan_file="$scan_results/scan-${image_safe_name}-${date_tag}.txt"
  sbom_file="$scan_results/sbom-${image_safe_name}-${date_tag}.json"
  
  if ! trivy image --offline-scan --cache-dir /mnt/trivy-cache --format table --output "$scan_file" "$full_image_name"; then
    color_yellow "  Warning: Scan completed with warnings"
    echo ""
  fi
  
  # Generate SBOM
  trivy image --offline-scan --cache-dir /mnt/trivy-cache --format cyclonedx --output "$sbom_file" "$full_image_name" 2>/dev/null || true
  
  # Count vulnerabilities by severity
  critical_count=0
  high_count=0
  medium_count=0
  low_count=0
  
  if [ -f "$scan_file" ]; then
    critical_count=$(grep -c "CRITICAL" "$scan_file" || true)
    high_count=$(grep -c "HIGH" "$scan_file" || true)
    medium_count=$(grep -c "MEDIUM" "$scan_file" || true)
    low_count=$(grep -c "LOW" "$scan_file" || true)
  fi
  
  # Determine new classification
  old_class="PLATINUM"
  new_class=""
  if [ "$critical_count" -gt 0 ]; then
    new_class="REJECTED"
  elif [ "$high_count" -gt 0 ]; then
    new_class="BRONZE"
  elif [ "$medium_count" -gt 5 ]; then
    new_class="SILVER"
  elif [ "$medium_count" -gt 0 ]; then
    new_class="GOLD"
  else
    new_class="PLATINUM"
  fi
  
  new_tag="${date_tag}-$(echo "$new_class" | tr '[:upper:]' '[:lower:]')"
  
  # Save classification report
  classification_file="$scan_results/classification-${image_safe_name}-${date_tag}.txt"
  {
    echo "Image Re-qualification Report"
    echo "============================="
    echo "Image: $full_image_name"
    echo "Original Classification: $old_class"
    echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Vulnerability Summary:"
    echo "  Critical Vulnerabilities: $critical_count"
    echo "  High Vulnerabilities: $high_count"
    echo "  Medium Vulnerabilities: $medium_count"
    echo "  Low Vulnerabilities: $low_count"
    echo ""
    echo "New Classification: $new_class"
    echo "New Recommended Tag: $new_tag"
  } > "$classification_file"
  
  # Display results
  printf "  Vulnerabilities: C:$critical_count H:$high_count M:$medium_count L:$low_count"
  echo ""
  printf "  Old Classification: "
  color_cyan "$old_class"
  echo ""
  printf "  New Classification: "
  case "$new_class" in
    PLATINUM) color_cyan "$new_class" ;;
    GOLD) color_yellow "$new_class" ;;
    SILVER) color_gray "$new_class" ;;
    BRONZE) color_yellow "$new_class" ;;
    UNQUALIFIED) color_magenta "$new_class" ;;
    REJECTED) color_red "$new_class" ;;
    *) printf "%s" "$new_class" ;;
  esac
  echo ""
  echo ""
  
  # Store summary
  echo "$repo|$date_tag|$old_class|$new_class|$critical_count|$high_count|$medium_count|$low_count|$new_tag" >> "$summary_file"
  
  # Take action based on classification change
  if [ "$new_class" != "$old_class" ]; then
    color_red "  ⚠ DEGRADED: Classification changed from $old_class to $new_class"
    echo ""
    
    # Extract namespace and repository name for API calls
    namespace=$(echo "$repo" | cut -d'/' -f1)
    repository=$(echo "$repo" | cut -d'/' -f2)
    
    if [ "$new_class" = "REJECTED" ]; then
      color_red "  Image is now REJECTED - removing platinum tag"
      echo ""
      
      # Remove platinum tag locally
      color_yellow "  Removing local platinum tag..."
      echo ""
      buildah rmi "$full_image_name" 2>/dev/null || true
      
      # Delete tag from Docker Hub using API
      color_yellow "  Deleting tag '$ptag' from Docker Hub..."
      echo ""
      
      # Delete the tag using JWT token from initial authentication
      response=$(curl -s -X DELETE \
        -H "Authorization: JWT $jwt_token" \
        "https://hub.docker.com/v2/repositories/${namespace}/${repository}/tags/${ptag}/")
      
      if echo "$response" | grep -q "error"; then
        color_red "  ✗ Failed to delete tag from Docker Hub"
        echo ""
      else
        color_green "  ✓ Deleted tag '$ptag' from Docker Hub"
        echo ""
      fi
    else
      # Update to new classification tag
      new_image_name="docker.io/${repo}:${new_tag}"
      color_yellow "  Retagging as: $new_image_name"
      echo ""
      buildah tag "$full_image_name" "$new_image_name"
      
      # Push new tag
      color_cyan "  Pushing $new_image_name to Docker Hub..."
      echo ""
      if buildah push "$new_image_name"; then
        color_green "  ✓ Pushed $new_image_name"
        echo ""
      else
        color_red "  ✗ Failed to push $new_image_name"
        echo ""
      fi
      
      # Delete old platinum tag from Docker Hub
      color_yellow "  Deleting old platinum tag '$ptag' from Docker Hub..."
      echo ""
      
      # Delete the tag using JWT token from initial authentication
      response=$(curl -s -X DELETE \
        -H "Authorization: JWT $jwt_token" \
        "https://hub.docker.com/v2/repositories/${namespace}/${repository}/tags/${ptag}/")
      
      if echo "$response" | grep -q "error"; then
        color_red "  ✗ Failed to delete old platinum tag from Docker Hub"
        echo ""
      else
        color_green "  ✓ Deleted old platinum tag '$ptag' from Docker Hub"
        echo ""
      fi
    fi
  else
    color_green "  ✓ Still PLATINUM - no action needed"
    echo ""
  fi
  
  echo ""
done < "$results_file"

color_cyan "=== Re-qualification Complete ==="
echo ""
echo ""

# Display summary
color_cyan "=== Re-qualification Summary ==="
echo ""
echo ""

if [ -f "$summary_file" ] && [ -s "$summary_file" ]; then
  printf "%-40s %-10s %-10s %-10s %-8s %-4s %-6s %-3s\n" "Image" "Date Tag" "Old Class" "New Class" "Critical" "High" "Medium" "Low"
  printf "%-40s %-10s %-10s %-10s %-8s %-4s %-6s %-3s\n" "-----" "--------" "---------" "---------" "--------" "----" "------" "---"
  while IFS='|' read -r repo date_tag old_class new_class critical high medium low new_tag; do
    printf "%-40s %-10s %-10s %-10s %-8s %-4s %-6s %-3s\n" "$repo" "$date_tag" "$old_class" "$new_class" "$critical" "$high" "$medium" "$low"
  done < "$summary_file"
  echo ""
  
  # Count degraded images
  degraded_count=$(awk -F'|' '$3 != $4' "$summary_file" | wc -l)
  still_platinum=$(awk -F'|' '$4 == "PLATINUM"' "$summary_file" | wc -l)
  
  echo ""
  if [ "$degraded_count" -gt 0 ]; then
    color_red "⚠ $degraded_count image(s) degraded from PLATINUM"
    echo ""
  fi
  color_green "✓ $still_platinum image(s) still qualify as PLATINUM"
  echo ""
else
  color_gray "No images were processed"
  echo ""
fi

echo ""
color_cyan "Scan results saved in: ${scan_results}/"
echo ""

# Cleanup temp files
rm -f "$results_file" "$summary_file"
