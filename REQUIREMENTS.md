# Requirements

## Repository Purpose

This repository contains a set of container images for various endeavors. Images are added incrementally as needed.

## Image Requirements

All container images in this repository must adhere to the following requirements:

### 1. Version Pinning

**All components must explicitly declare and install specific version numbers.**

- No use of `latest` tags or version wildcards
- All base images must specify exact versions (e.g., `alpine:3.18.4` not `alpine:latest`)
- All installed packages must use explicit version numbers
- All downloaded artifacts must reference specific versions or commit hashes

### 2. Folder Structure

**Images must be organized in dedicated folders.**

- Each image has its own dedicated folder
- Image folders may be sub-folders of other folders for organizational purposes
- An image folder is always a **leaf** directory (contains no subdirectories with other images)

### 3. Image Chaining

**Images may be chained together.**

- Images can use other images from this repository as base images
- Document the chain in the image's README.md

### 4. Image Identifiers

**Default image identifiers follow a specific convention.**

By convention, the default identifier for an image is: `local/$path`

Where `$path` is the relative path of the Dockerfile to the root of this repository.

**Examples:**
- `alpine/neovim-01/Dockerfile` → `local/alpine/neovim-01`
- `ubuntu/python-dev/Dockerfile` → `local/ubuntu/python-dev`

### 5. AI Assistance

**This repository is built and maintained with assistance from AI agents.**

- AI agents are allowed to **create new files** only in the `ai-assist/` folder
- AI agents are allowed and expected to **modify files** anywhere in the repository at user request and under user supervision
- All AI-assisted changes must be reviewed by the user

### 6. Image Documentation

**Each leaf image folder must contain three files:**

1. **`Dockerfile`** - The container image definition

2. **`README.md`** - Documentation explaining:
   - What the container is for
   - How to build it
   - How to use it
   - Any dependencies or prerequisites

3. **`TRACK.md`** - Tracking file documenting:
   - The composition of the image (all modules, packages, tools)
   - Related licenses for each component
   - Version information
   - Update history

**Special Note:** This repository will contain a special container for:
- SBOM (Software Bill of Materials) creation
- Vulnerability scanning
- License scanning

This tool will assist in maintaining the `TRACK.md` files and ensuring compliance.

## Compliance

All images must comply with these requirements. Non-compliant images should be updated or removed from the repository.
