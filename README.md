# My Container Images

A curated collection of Alpine-based container images with automated security scanning and classification.

## Overview

This repository contains containerized development and utility tools built on Alpine Linux. Each image is automatically scanned for vulnerabilities and secrets, then classified based on security findings. Images are tagged with qualifiers that reflect their security posture.

## Security Classification System

All images are scanned using [Trivy](https://trivy.dev/) and classified into tiers:

| Tier | Tag Suffix | Criteria |
|------|------------|----------|
| 🏆 **Platinum** | `-platinum` | No vulnerabilities detected at any severity level |
| 🥇 **Gold** | `-gold` | No HIGH or CRITICAL vulnerabilities (may have MEDIUM or LOW) |
| 🥈 **Silver** | `-silver` | Contains HIGH and eventually lower vulnerabilities (no CRITICAL) |
| 🥉 **Bronze** | `-bronze` | MEDIUM or LOW vulnerabilities only (no HIGH or CRITICAL) |
| ❌ **Unqualified** | *(none)* | Contains CRITICAL vulnerabilities OR has not been evaluated |
| ⛔ **Rejected** | `-secret-exposed` | Secrets detected - **DO NOT USE** |

## Available Images

Images are defined in `images.csv`:

| Repository | Folder | Description |
|------------|--------|-------------|
| `miunpersonal/alpine-trivy-scanner` | `alpine/01.trivy-scanner` | Trivy security scanner with classification scripts |
| `miunpersonal/alpine-git-client-sw` | `alpine/02.git-client-sw` | Git client with SSH and development tools |
| `miunpersonal/alpine-neovim-01` | `alpine/03.neovim-01` | Neovim editor with development tools |

## Image Tagging Convention

Images use a date-based tagging format: `YYMDD[-qualifier]`

- **YY**: 2-digit year (e.g., `25` for 2025)
- **M**: Hexadecimal month (1-9, A=October, B=November, C=December)
- **DD**: 2-digit day (01-31)
- **qualifier**: Security classification suffix (optional)

**Examples:**
- `25B13` = November 13, 2025 (base build)
- `25B13-platinum` = November 13, 2025, platinum security rating
- `25B13-secret-exposed` = November 13, 2025, rejected due to secrets

## Build and Scan Process

### Automated Build Script

The `build-and-scan-all.ps1` PowerShell script automates the entire build and security scanning pipeline:

1. **Build Phase**: Builds all images from `images.csv` with the current date tag
2. **Security Scanning**: Scans each image for:
   - Secrets (API keys, tokens, credentials)
   - Vulnerabilities (CRITICAL, HIGH, MEDIUM, LOW)
3. **Classification**: Assigns security tier based on findings
4. **Tagging**: Creates additional image tags with security qualifiers
5. **Reporting**: Generates comprehensive security reports

### Usage

```powershell
# Build and scan all images
.\build-and-scan-all.ps1
```

The script will:
- Generate a date-based tag (e.g., `25B13`)
- Build all images with this tag
- Scan each image for security issues
- Apply classification tags
- Save reports to `scan-results/` directory

### Output Files

For each scanned image, three files are generated in `scan-results/`:

| File | Description |
|------|-------------|
| `scan-<tag>.txt` | Detailed vulnerability report (table format) |
| `sbom-<tag>.json` | CycloneDX Software Bill of Materials |
| `classification-<tag>.txt` | Security classification summary |

## Adding New Images

1. Add a new entry to `images.csv`:
   ```csv
   miunpersonal/your-image-name,alpine/folder-path
   ```

2. Create the image directory and Dockerfile:
   ```powershell
   mkdir alpine\XX.your-image-name
   # Create Dockerfile in the new directory
   ```

3. Run the build script:
   ```powershell
   .\build-and-scan-all.ps1
   ```

## Requirements

- **Windows PowerShell 5.1+**
- **Docker Desktop** with BuildKit enabled
- **Docker socket access** for Trivy scanning

## Security Notes

- ⚠️ **Never use images tagged with `-secret-exposed`**
- 🔒 Regularly rebuild images to incorporate security patches
- 📊 Review scan reports in `scan-results/` directory
- 🔄 Images are scanned against the latest Trivy vulnerability database

## Repository Structure

```
my-container-images/
├── alpine/
│   ├── trivy-scanner/      # Trivy scanner + classification scripts
│   ├── git-client-sw/      # Git client
│   └── neovim-01/          # Neovim editor
├── scan-results/              # Security scan reports (generated)
├── images.csv                 # Image repository definitions
├── build-and-scan-all.ps1    # Automated build and scan script
└── README.md                  # This file
```

## License

See [LICENSE](LICENSE) file for details.
