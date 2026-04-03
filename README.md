# xv6-ntu-mp-image

A multi-architecture Docker image for NTU xv6 machine problems. Builds a slim, self-contained environment with QEMU (RISC-V 64), cross-compilation toolchains, and developer niceties (oh-my-bash, ble.sh, tmux, gdb-multiarch).

## Quick Start

### Prerequisites

- Docker (or Podman) with BuildKit support
- [GitHub CLI (`gh`)](https://cli.github.com/) for authentication
- A remote ARM64 machine (if building multi-arch)

### 1. Authenticate with GHCR

```bash
./auth.sh <your-github-username>
```

This logs you into GitHub via `gh` and pipes a token to `docker login ghcr.io`.

### 2. Create your build config

```bash
cp build.conf.template build.conf
# Edit build.conf to match your environment
```

See [Configuring `build.conf`](#configuring-buildconf) below.

### 3. Set up the multi-node builder

```bash
./buildx-setup.sh          # uses build.conf by default
# or
./buildx-setup.sh my.conf  # use a custom config file
```

This starts a local BuildKit daemon and creates a `cluster-builder` that fans out to master (amd64) and slave (arm64) nodes.

If you are the **remote (slave) node**, run this instead in the foreground:

```bash
./buildx-remote-fg.sh
```

### 4. Build and push

```bash
./buildx.sh                # uses build.conf by default
```

The image is built for `linux/amd64` and `linux/arm64`, then pushed to the configured registry.

## Configuring `build.conf`

Copy `build.conf.template` to `build.conf` (git-ignored) and adjust the values:

| Variable | Description | Default |
|---|---|---|
| `DOCKER_CMD` | Docker-compatible CLI to use | `docker` |
| **Image manifest** | | |
| `ORGANIZATION` | Registry + org prefix (e.g. `ghcr.io/ntu-csieos26spring`) | |
| `IMAGE_NAME` | Image name | `mp-draft` |
| `IMAGE_TAG` | Image tag | `latest` |
| `REPOSITORY_SOURCE` | URL embedded in OCI labels | |
| `IMAGE_DESCRIPTION` | Human-readable description embedded in OCI labels | |
| **BuildKit setup** | | |
| `MASTER_BUILDKIT_PORT` | Port the local BuildKit daemon listens on | `15424` |
| `SLAVE_BUILDKIT_PORT` | Port the remote BuildKit daemon listens on | `15423` |
| `MASTER_HOST` | IP of the master (local) machine | `127.0.0.1` |
| `SLAVE_HOST` | IP of the slave (remote) machine | |
| `MASTER_PLATFORM` | Platform of master node (`linux/amd64` or `linux/arm64`) | `linux/amd64` |
| `SLAVE_PLATFORM` | Platform of slave node | `linux/arm64` |
| **Image versions** | | |
| `QEMU_VERSION` | QEMU version to build from source | `10.2.2` |
| `PYTHON_VERSION` | Python base image version | `3.14` |
| `DEBIAN_SUITE` | Debian release codename | `trixie` |

## Project Structure

```
.
├── build.conf.template      # Template for build configuration (copy to build.conf)
├── auth.sh                  # GitHub + GHCR login helper
├── buildx-setup.sh          # Creates the multi-node BuildKit cluster
├── buildx-remote-fg.sh      # Runs BuildKit on the remote (slave) node
├── buildx.sh                # Builds and pushes the multi-arch image
├── Dockerfile               # Multi-stage build definition
├── run-with-utils.sh        # Loader that sources utils/ then runs a command
├── utils/                   # Shell utility library (logging, pkg helpers, etc.)
├── qemu-build/
│   └── setup.sh             # Downloads, verifies, and compiles QEMU 10.2.2
├── image-root/              # Scripts sourced during the final image setup
│   ├── packages.sh          # Installs runtime APT packages
│   ├── locale.sh            # Configures locale and timezone
│   ├── systemd.sh           # Optional systemd installation
│   ├── setup.sh             # Creates the student user
│   ├── fixuid.sh            # Configures fixuid for UID remapping
│   ├── pip.sh               # Installs Python packages (parse)
│   └── cleanup.sh           # Strips unused libs and caches to shrink image
├── tmux.conf                # tmux configuration baked into /etc/tmux.conf
└── screenrc                 # GNU Screen configuration (not used in image)
```

## Dockerfile Stages

### Stage 1a -- `builder` (Build QEMU from source)

Based on `python:<version>-<suite>`. Compiles QEMU 10.2.2 targeting `riscv64-softmmu` with all GUI/network backends disabled. Supports cross-compilation (e.g. building ARM64 binaries on an AMD64 host) via `CROSS_PREFIX`. Also builds [ble.sh](https://github.com/akinomyoga/ble.sh) and fetches the [oh-my-bash](https://github.com/ohmybash/oh-my-bash) installer.

### Stage 1b -- `fixuid-builder` (Build fixuid)

Based on `golang:1-<suite>`. Compiles [fixuid](https://github.com/boxboat/fixuid) v0.6.0 as a static binary for the target architecture. This avoids downloading from GitHub CDN at runtime.

### Stage 2 -- `scripts` (Cherry-pick runtime files)

A `scratch`-based staging area that gathers artifacts from previous stages and the build context into two directory trees:

- `/rootfs/` -- root-owned files: QEMU binary, OpenSBI firmware, fixuid, tmux.conf, and the `image-root/` setup scripts.
- `/homefs/` -- user-owned files: ble.sh and oh-my-bash installer.

### Stage 3 -- `runner` (Final slim image)

Based on `python:<version>-slim-<suite>`. Copies in the two trees from `scripts`, then runs the setup scripts in order:

1. **packages.sh** -- installs runtime packages (git, make, gcc, gdb-multiarch, RISC-V cross-toolchain, tmux, etc.)
2. **locale.sh** -- generates locale and sets timezone
3. **systemd.sh** -- optionally installs systemd (if `USE_SYSTEMD=yes`)
4. **setup.sh** -- creates the `student` user with passwordless sudo
5. **fixuid.sh** -- configures fixuid so container UID can match the host user
6. **pip.sh** -- installs the `parse` Python package
7. **cleanup.sh** -- aggressively removes unused libs (sanitizers, LTO, docs) to shrink the image

Finally, as the `student` user, it sets up gdb safe-path, installs oh-my-bash + ble.sh into `.bashrc`, and optionally sets a user password. The entrypoint is `fixuid -q` so that bind-mounted volumes get correct ownership.
