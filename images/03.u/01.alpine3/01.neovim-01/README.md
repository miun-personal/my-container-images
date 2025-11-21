# Neovim on Alpine 01

## Purpose

A lightweight development container based on Alpine Linux, designed for editing and testing code files with Neovim. This container is particularly well-suited for:

- Shell script development and testing
- Quick file editing tasks
- Git repository interactions
- Code formatting and linting with shell tools

## Image Identifier

By convention: `local/alpine/neovim-01`

## Contents

This container includes:

- **Neovim** (0.11.1) - Modern, extensible text editor
- **Git** (2.49.1) - Version control system
- **ShellCheck** (0.10.0) - Shell script static analysis tool
- **shfmt** (3.11.0) - Shell script formatter
- **shunit2** (2.1.8) - Unit testing framework for shell scripts
- **curl** (8.14.1) - Data transfer tool
- **mandoc** (1.14.6) - Manual page viewer

All packages are pinned to specific versions for reproducibility.

## Building

From the repository root:

```bash
docker build -t local/alpine/neovim-01 -f alpine/neovim-01/Dockerfile alpine/neovim-01
```

Or from the image directory:

```bash
cd alpine/neovim-01
docker build -t local/alpine/neovim-01 .
```

### Build Arguments

The following build arguments can be customized:

- `__image_version` (default: 3.22) - Alpine Linux base image version
- `__uid` (default: 1000) - User ID for the non-root user
- `__gid` (default: 1000) - Group ID for the non-root user
- `__uname` (default: dev) - Username
- `__gname` (default: dev) - Group name

Example with custom user:

```bash
docker build -t local/alpine/neovim-01 \
  --build-arg __uid=1001 \
  --build-arg __gid=1001 \
  --build-arg __uname=myuser \
  -f alpine/neovim-01/Dockerfile alpine/neovim-01
```

## Usage

### Interactive Shell

Run an interactive session with a mounted volume:

```bash
docker run -it --rm -v ${PWD}:/workspace -w /workspace local/alpine/neovim-01 /bin/sh
```

### Edit a File with Neovim

```bash
docker run -it --rm -v ${PWD}:/workspace -w /workspace local/alpine/neovim-01 nvim myfile.sh
```

### Run ShellCheck on a Script

```bash
docker run --rm -v ${PWD}:/workspace -w /workspace local/alpine/neovim-01 shellcheck myscript.sh
```

### Format a Shell Script

```bash
docker run --rm -v ${PWD}:/workspace -w /workspace local/alpine/neovim-01 shfmt -w myscript.sh
```

## User Configuration

The container runs as a non-root user (`dev:dev` by default with UID/GID 1000). This ensures better security and file permission compatibility when mounting host directories.

## Dependencies

- Base Image: `alpine:3.22`
- No chained images (this is a base development image)

## Version Information

See [TRACK.md](./TRACK.md) for detailed component tracking and license information.
