# Component Tracking - alpine/neovim-01

This file tracks all components, versions, and licenses included in this container image.

## Image Metadata

- **Image Path**: `alpine/neovim-01`
- **Image Identifier**: `local/alpine/neovim-01`
- **Last Updated**: 2025-10-14
- **Base Image**: `alpine:3.22`

## Base Image

| Component | Version | License | Source |
|-----------|---------|---------|--------|
| Alpine Linux | 3.22 | MIT | https://www.alpinelinux.org/ |

**Alpine Linux License**: MIT License - Alpine Linux is licensed under the MIT license and various component licenses. See https://www.alpinelinux.org/about/

## Installed Packages

All packages installed from Alpine Linux package repository (https://pkgs.alpinelinux.org/).

| Package | Version | License | Purpose |
|---------|---------|---------|---------|
| neovim | 0.11.1-r1 | Apache-2.0 | Modern extensible text editor |
| neovim-doc | 0.11.1-r1 | Apache-2.0 | Neovim documentation |
| git | 2.49.1-r0 | GPL-2.0-only | Version control system |
| shellcheck | 0.10.0-r2 | GPL-3.0-or-later | Shell script static analysis |
| shfmt | 3.11.0-r3 | BSD-3-Clause | Shell script formatter |
| shunit2 | 2.1.8-r1 | Apache-2.0 | Shell script unit testing framework |
| curl | 8.14.1-r2 | curl | Data transfer tool with URL syntax |
| mandoc | 1.14.6-r13 | ISC | Manual page viewer and formatter |

## License Breakdown

### Apache-2.0
- neovim
- neovim-doc
- shunit2

### GPL (GNU General Public License)
- git (GPL-2.0-only)
- shellcheck (GPL-3.0-or-later)

### BSD-3-Clause
- shfmt

### curl License
- curl (MIT/X derivate license, permissive)

### ISC License
- mandoc (ISC - permissive, similar to MIT)

## Security & Compliance Notes

- All package versions are explicitly pinned for reproducibility
- No "latest" tags are used
- Base image version is explicitly declared
- Container runs as non-root user (UID/GID 1000 by default)

## Update History

| Date | Component | Old Version | New Version | Reason |
|------|-----------|-------------|-------------|--------|
| 2025-10-14 | (initial) | - | - | Initial image creation |

## License References

- **Apache-2.0**: https://www.apache.org/licenses/LICENSE-2.0
- **GPL-2.0**: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
- **GPL-3.0**: https://www.gnu.org/licenses/gpl-3.0.html
- **BSD-3-Clause**: https://opensource.org/licenses/BSD-3-Clause
- **curl License**: https://curl.se/docs/copyright.html
- **ISC License**: https://opensource.org/licenses/ISC
- **MIT License**: https://opensource.org/licenses/MIT

## SBOM Generation

For automated SBOM generation and vulnerability scanning, use the dedicated SBOM container from this repository (when available).

## Notes

- Alpine Linux uses musl libc instead of glibc
- All packages are from the official Alpine Linux repositories
- Package license information sourced from Alpine package database and upstream projects
- Some packages may have additional dependencies with their own licenses
