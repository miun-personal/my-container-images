#!/bin/sh
# Scan and classify container images based on security findings
# Usage: scan-and-classify.sh <image-name> <output-dir> <base-tag> <image-safe-name>

set -e

IMAGE_NAME="$1"
OUTPUT_DIR="$2"
BASE_TAG="$3"
IMAGE_SAFE_NAME="$4"

if [ -z "$IMAGE_NAME" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$BASE_TAG" ] || [ -z "$IMAGE_SAFE_NAME" ]; then
    echo "Usage: $0 <image-name> <output-dir> <base-tag> <image-safe-name>"
    exit 1
fi

SCAN_REPORT="${OUTPUT_DIR}/scan-${IMAGE_SAFE_NAME}.txt"
SBOM_FILE="${OUTPUT_DIR}/sbom-${IMAGE_SAFE_NAME}.json"
CLASSIFICATION_FILE="${OUTPUT_DIR}/classification-${IMAGE_SAFE_NAME}.txt"

echo "Scanning image: ${IMAGE_NAME}"

# Step 1: Check for secrets
echo "Step 1: Checking for secrets..."
SECRET_COUNT=$(trivy image --scanners secret --severity HIGH,CRITICAL --format json --quiet "${IMAGE_NAME}" | \
    jq '[.Results[]? | select(.Secrets != null) | .Secrets[]] | length')

if [ "$SECRET_COUNT" -gt 0 ]; then
    echo "SECRETS DETECTED! Image is REJECTED."
    QUALIFIER="-secret-exposed"
    
    # Generate detailed report
    trivy image --scanners secret --severity HIGH,CRITICAL --no-progress "${IMAGE_NAME}" > "${SCAN_REPORT}"
    
    # Still generate SBOM for documentation
    trivy image --format cyclonedx --scanners vuln "${IMAGE_NAME}" > "${SBOM_FILE}" 2>/dev/null
    
    # Write classification
    echo "Image: ${IMAGE_NAME}" > "${CLASSIFICATION_FILE}"
    echo "Classification: REJECTED" >> "${CLASSIFICATION_FILE}"
    echo "Qualifier: ${QUALIFIER}" >> "${CLASSIFICATION_FILE}"
    echo "Reason: Secrets detected (${SECRET_COUNT})" >> "${CLASSIFICATION_FILE}"
    echo "Recommended Tag: ${BASE_TAG}${QUALIFIER}" >> "${CLASSIFICATION_FILE}"
    
    exit 0
fi

echo "No secrets detected."

# Step 2: Scan for vulnerabilities
echo "Step 2: Scanning for vulnerabilities..."
VULN_JSON=$(trivy image --scanners vuln --format json --quiet "${IMAGE_NAME}")

# Count vulnerabilities by severity
CRITICAL_COUNT=$(echo "$VULN_JSON" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length')
HIGH_COUNT=$(echo "$VULN_JSON" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length')
MEDIUM_COUNT=$(echo "$VULN_JSON" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length')
LOW_COUNT=$(echo "$VULN_JSON" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "LOW")] | length')
TOTAL_VULN=$(echo "$VULN_JSON" | jq '[.Results[]?.Vulnerabilities[]?] | length')

echo "Vulnerabilities found - Critical: ${CRITICAL_COUNT}, High: ${HIGH_COUNT}, Medium: ${MEDIUM_COUNT}, Low: ${LOW_COUNT}, Total: ${TOTAL_VULN}"

# Step 3: Classify based on vulnerabilities
if [ "$TOTAL_VULN" -eq 0 ]; then
    QUALIFIER="-platinum"
    CLASSIFICATION="PLATINUM"
    REASON="No vulnerabilities detected"
elif [ "$CRITICAL_COUNT" -eq 0 ] && [ "$HIGH_COUNT" -eq 0 ] && [ "$MEDIUM_COUNT" -eq 0 ] && [ "$LOW_COUNT" -eq 0 ]; then
    QUALIFIER="-gold"
    CLASSIFICATION="GOLD"
    REASON="No vulnerabilities detected"
elif [ "$CRITICAL_COUNT" -eq 0 ] && [ "$HIGH_COUNT" -eq 0 ]; then
    QUALIFIER="-bronze"
    CLASSIFICATION="BRONZE"
    REASON="MEDIUM or LOW vulnerabilities only (Medium: ${MEDIUM_COUNT}, Low: ${LOW_COUNT})"
elif [ "$CRITICAL_COUNT" -eq 0 ] && [ "$HIGH_COUNT" -gt 0 ]; then
    QUALIFIER="-silver"
    CLASSIFICATION="SILVER"
    REASON="HIGH vulnerabilities only (${HIGH_COUNT}), no CRITICAL"
else
    QUALIFIER=""
    CLASSIFICATION="UNQUALIFIED"
    REASON="CRITICAL vulnerabilities detected (${CRITICAL_COUNT})"
fi

echo "Classification: ${CLASSIFICATION} ${QUALIFIER}"

# Step 4: Generate full vulnerability report
trivy image --severity HIGH,CRITICAL --no-progress "${IMAGE_NAME}" > "${SCAN_REPORT}"

# Step 5: Generate CycloneDX SBOM
echo "Generating CycloneDX SBOM..."
trivy image --format cyclonedx --scanners vuln "${IMAGE_NAME}" > "${SBOM_FILE}" 2>/dev/null

# Step 6: Write classification summary
cat > "${CLASSIFICATION_FILE}" <<EOF
Image: ${IMAGE_NAME}
Classification: ${CLASSIFICATION}
Qualifier: ${QUALIFIER}
Recommended Tag: ${BASE_TAG}${QUALIFIER}

Security Summary:
- Secrets: 0
- Critical Vulnerabilities: ${CRITICAL_COUNT}
- High Vulnerabilities: ${HIGH_COUNT}
- Medium Vulnerabilities: ${MEDIUM_COUNT}
- Low Vulnerabilities: ${LOW_COUNT}
- Total Vulnerabilities: ${TOTAL_VULN}

Reason: ${REASON}

Reports Generated:
- Scan Report: scan-${IMAGE_SAFE_NAME}.txt
- SBOM (CycloneDX): sbom-${IMAGE_SAFE_NAME}.json
- Classification: classification-${IMAGE_SAFE_NAME}.txt
EOF

echo "Scan complete. Classification: ${CLASSIFICATION}"
echo "Recommended tag: ${BASE_TAG}${QUALIFIER}"
