#!/bin/sh
# Build and Scan All Alpine Images
# This script builds all Alpine-based images and scans them with Trivy

set -e

# Colors for output (using printf with escape sequences)
color_red() { printf '\033[0;31m%s\033[0m' "$1"; }
color_green() { printf '\033[0;32m%s\033[0m' "$1"; }
color_yellow() { printf '\033[1;33m%s\033[0m' "$1"; }
color_cyan() { printf '\033[0;36m%s\033[0m' "$1"; }
color_magenta() { printf '\033[0;35m%s\033[0m' "$1"; }
color_gray() { printf '\033[0;90m%s\033[0m' "$1"; }

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
echo ""
echo ""

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
echo ""

# Check if images.csv exists
if [ ! -f "images.csv" ]; then
  color_red "Error: images.csv not found"
  echo "" >&2
  exit 1
fi

color_cyan "=== Building and Scanning Alpine Images ==="
echo ""
echo ""

# Step 1: Build all images
color_yellow "Step 1: Building all images..."
echo ""
echo ""

# Read CSV file (skip header) and build images
tail -n +2 images.csv | while IFS=, read -r repo folder || [ -n "$repo" ]; do
  # Trim whitespace
  repo=$(echo "$repo" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  folder=$(echo "$folder" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  full_image_name="docker.io/${repo}:${tag}"
  color_green "Building $full_image_name..."
  echo ""
  
  cd "$folder"
  if ! buildah bud --isolation=chroot -t "$full_image_name" .; then
    cd - > /dev/null
    color_red "Error: Failed to build $full_image_name"
    echo "" >&2
    exit 1
  fi
  cd - > /dev/null
  
  color_green "✓ Built $full_image_name"
  echo ""
  echo ""
done

# Step 2: Build the trivy-scanner image (if not already built)
color_yellow "Step 2: Ensuring trivy-scanner is ready..."
echo ""
echo ""

sleep 5 # Allow a bit of time for buildah to register the new images locally, otherwise the first scans may fail

# Step 3: Scan all images with Trivy
color_yellow "Step 3: Scanning all images with Trivy..."
echo ""
echo ""

# Create timestamped scan folder
timestamp=$(date +%Y%m%d-%H%M%S)
scan_results_base="scan-results"
scan_results="${scan_results_base}/${timestamp}"
mkdir -p "$scan_results"

color_cyan "Scan results will be saved to: ${scan_results}/"
echo ""
echo ""

# Track image classifications for summary
classifications_file="$scan_results/.classifications.tmp"
: > "$classifications_file"

# Scan each image
tail -n +2 images.csv | while IFS=, read -r repo folder || [ -n "$repo" ]; do
  # Trim whitespace
  repo=$(echo "$repo" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  full_image_name="docker.io/${repo}:${tag}"
  image_safe_name=$(echo "$repo" | tr '/' '-')
  
  color_green "Scanning $full_image_name..."
  echo ""
  
  # Scan with Trivy directly
  scan_file="$scan_results/scan-$image_safe_name.txt"
  sbom_file="$scan_results/sbom-$image_safe_name.json"
  
  # Run Trivy scan
  if ! trivy image --offline-scan --cache-dir /mnt/trivy-cache --format table --output "$scan_file" "$full_image_name"; then
    color_yellow "Warning: Scan of $full_image_name completed with warnings"
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
  
  # Determine classification based on vulnerability counts
  class_type=""
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
  classification_file="$scan_results/classification-$image_safe_name.txt"
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
  
  # Store classification info
  echo "$repo|$class_type|$recommended_tag|$critical_count|$high_count|$medium_count|$low_count" >> "$classifications_file"
  
  # Display classification with color
  new_image_name="docker.io/${repo}:${recommended_tag}"
  printf "Classification: "
    case "$class_type" in
      PLATINUM) color_cyan "$class_type" ;;
      GOLD) color_yellow "$class_type" ;;
      SILVER) color_gray "$class_type" ;;
      BRONZE) color_yellow "$class_type" ;;
      UNQUALIFIED) color_magenta "$class_type" ;;
      REJECTED) color_red "$class_type" ;;
      *) printf "%s" "$class_type" ;;
    esac
    echo ""
    
    # Only tag and push if not rejected
    if [ "$class_type" != "REJECTED" ]; then
      color_green "Tagging image as: $new_image_name"
      echo ""
      buildah tag "$full_image_name" "$new_image_name"
      
      # Push both tags to Docker Hub
      color_cyan "Pushing $full_image_name to Docker Hub..."
      echo ""
      if buildah push "$full_image_name"; then
        color_green "✓ Pushed $full_image_name"
        echo ""
      else
        color_red "✗ Failed to push $full_image_name"
        echo ""
      fi
      
      color_cyan "Pushing $new_image_name to Docker Hub..."
      echo ""
      if buildah push "$new_image_name"; then
        color_green "✓ Pushed $new_image_name"
        echo ""
      else
        color_red "✗ Failed to push $new_image_name"
        echo ""
      fi
    else
      color_red "Image REJECTED - not creating additional tag or pushing"
      echo ""
    fi
  
  color_green "✓ Scan reports saved to: ${scan_results}/"
  echo ""
  echo ""
done

color_cyan "=== All builds and scans complete ==="
echo ""
echo ""

# Generate summary table
color_cyan "=== Image Classification Summary ==="
echo ""
echo ""
if [ -f "$classifications_file" ] && [ -s "$classifications_file" ]; then
  printf "%-40s %-15s %-8s %-4s %-6s %-3s %-30s\n" "Image" "Classification" "Critical" "High" "Medium" "Low" "Tag"
  printf "%-40s %-15s %-8s %-4s %-6s %-3s %-30s\n" "-----" "--------------" "--------" "----" "------" "---" "---"
  while IFS='|' read -r image class_type recommended_tag critical high medium low; do
    printf "%-40s %-15s %-8s %-4s %-6s %-3s %-30s\n" "$image" "$class_type" "$critical" "$high" "$medium" "$low" "$recommended_tag"
  done < "$classifications_file"
  echo ""
fi

# Generate consolidated vulnerability report
color_cyan "=== Generating Consolidated Vulnerability Report ==="
echo ""
echo ""

vuln_report_file="$scan_results/vulnerability-report-$tag.csv"
temp_vuln_file="$scan_results/.vulnerabilities.tmp"
: > "$temp_vuln_file"

# Process each SBOM file
tail -n +2 images.csv | while IFS=, read -r repo folder || [ -n "$repo" ]; do
  repo=$(echo "$repo" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  image_safe_name=$(echo "$repo" | tr '/' '-')
  sbom_file="$scan_results/sbom-$image_safe_name.json"
  
  if [ -f "$sbom_file" ]; then
    color_gray "Processing SBOM for $repo..."
    echo ""
    
    # Extract vulnerabilities from SBOM using simple JSON parsing
    # This is a simplified version - for production use, consider using jq
    if grep -q '"vulnerabilities"' "$sbom_file"; then
      # Extract vulnerability IDs, severities, and descriptions
      # Note: This is basic parsing. For more complex JSON, install jq
      awk -v repo="$repo" '
        /"id":/ { 
          gsub(/.*"id": *"/, ""); 
          gsub(/".*/, ""); 
          vuln_id = $0 
        }
        /"severity":/ && vuln_id != "" { 
          gsub(/.*"severity": *"/, ""); 
          gsub(/".*/, ""); 
          severity = $0 
        }
        /"description":/ && vuln_id != "" && severity != "" { 
          gsub(/.*"description": *"/, ""); 
          gsub(/".*/, ""); 
          desc = substr($0, 1, 100);
          if (length($0) > 100) desc = desc "..."
          print vuln_id "|" severity "|" repo "|" desc
          vuln_id = ""
          severity = ""
        }
      ' "$sbom_file" >> "$temp_vuln_file"
    fi
  fi
done

# Create CSV header
echo "VulnerabilityID,Severity,AffectedImages,ImageCount,Description" > "$vuln_report_file"

# Consolidate vulnerabilities (group by vulnerability ID)
if [ -f "$temp_vuln_file" ] && [ -s "$temp_vuln_file" ]; then
  sort "$temp_vuln_file" | awk -F'|' '
    {
      vuln_id = $1
      severity = $2
      image = $3
      desc = $4
      
      if (!(vuln_id in seen)) {
        severity_map[vuln_id] = severity
        desc_map[vuln_id] = desc
        images[vuln_id] = image
        count[vuln_id] = 1
        seen[vuln_id] = 1
      } else {
        if (index(images[vuln_id], image) == 0) {
          images[vuln_id] = images[vuln_id] ", " image
          count[vuln_id]++
        }
      }
    }
    END {
      for (vuln_id in seen) {
        # Sort order: CRITICAL=1, HIGH=2, MEDIUM=3, LOW=4, other=5
        sev = severity_map[vuln_id]
        order = 5
        if (sev == "CRITICAL") order = 1
        else if (sev == "HIGH") order = 2
        else if (sev == "MEDIUM") order = 3
        else if (sev == "LOW") order = 4
        
        # Escape quotes in description
        desc_safe = desc_map[vuln_id]
        gsub(/"/, "\"\"", desc_safe)
        
        print order "|" vuln_id "|" sev "|" images[vuln_id] "|" count[vuln_id] "|\"" desc_safe "\""
      }
    }
  ' | sort -t'|' -k1,1n -k2,2 | cut -d'|' -f2- | sed 's/|/,/g' >> "$vuln_report_file"
fi

color_green "✓ Vulnerability report saved to: $vuln_report_file"
echo ""

# Display summary
critical_vulns=0
high_vulns=0
medium_vulns=0
low_vulns=0

if [ -f "$vuln_report_file" ]; then
  critical_vulns=$(grep -c ',CRITICAL,' "$vuln_report_file" || true)
  high_vulns=$(grep -c ',HIGH,' "$vuln_report_file" || true)
  medium_vulns=$(grep -c ',MEDIUM,' "$vuln_report_file" || true)
  low_vulns=$(grep -c ',LOW,' "$vuln_report_file" || true)
fi

echo ""
color_yellow "Unique Vulnerabilities Found:"
echo ""
if [ "$critical_vulns" -gt 0 ]; then
  printf "  "
  color_red "CRITICAL: $critical_vulns"
  echo ""
else
  printf "  "
  color_green "CRITICAL: $critical_vulns"
  echo ""
fi
if [ "$high_vulns" -gt 0 ]; then
  printf "  "
  color_red "HIGH:     $high_vulns"
  echo ""
else
  printf "  "
  color_green "HIGH:     $high_vulns"
  echo ""
fi
if [ "$medium_vulns" -gt 0 ]; then
  printf "  "
  color_yellow "MEDIUM:   $medium_vulns"
  echo ""
else
  printf "  "
  color_green "MEDIUM:   $medium_vulns"
  echo ""
fi
printf "  "
color_gray "LOW:      $low_vulns"
echo ""
echo ""
color_cyan "Scan results saved in: ${scan_results}/"
echo ""

# Cleanup temp files
rm -f "$classifications_file" "$temp_vuln_file"
