# xv6-ntu-mp-image

A multi-architecture Docker image for NTU xv6 machine problems. Builds a slim, self-contained environment with QEMU (RISC-V 64), cross-compilation toolchains, and developer niceties (oh-my-bash, ble.sh, tmux, gdb-multiarch).

## Quick Start

### Prerequisites

- Docker (or Podman) with BuildKit support
- [GitHub CLI (`gh`)](https://cli.github.com/) for authentication
- A remote ARM64 machine (if building multi-arch)

### 1. Authenticate with GHCR

```bash
./scripts/auth.sh <your-github-username>
# or, if Docker requires root:
DOCKER_CMD="sudo docker" ./scripts/auth.sh <your-github-username>
```

This logs you into GitHub via `gh` and pipes a token to `docker login ghcr.io`.

> **Note:** Every script respects the `DOCKER_CMD` environment variable (defaults to `docker`). You can `export DOCKER_CMD="sudo docker"` (or `"podman"`) once, or set it per-command as shown above.

### 2. Create your config files

```bash
cp configs/build.conf.template configs/build.conf       # image settings (always needed)
cp configs/remote.conf.template configs/remote.conf     # remote BuildKit cluster (distributed builds only)
# Edit both to match your environment
```

See [Configuration](#configuration) below.

### 3. Build and push

There are two ways to produce the multi-arch image:

#### Option A: Distributed build (recommended)

The `buildx-setup.sh` / `buildx.sh` scripts dispatch each platform to a **native** machine so nothing is emulated. This requires two machines -- one per architecture.

On the **remote (slave) node**, start a BuildKit daemon in the foreground:

```bash
./scripts/buildx-remote-fg.sh      # reads configs/remote.conf
```

On the **master node**, create the multi-node builder and kick off the build:

```bash
./scripts/buildx-setup.sh          # reads configs/remote.conf, creates cluster-builder
./scripts/buildx.sh                # reads configs/build.conf, builds both platforms natively, then pushes
```

#### Option B: Local build (single machine)

If you only have one machine, `buildx-local.sh` builds both platforms locally using the default builder. The non-native platform is emulated via QEMU userspace emulation, which is **significantly slower**.

```bash
./scripts/buildx-local.sh
```

Both `buildx.sh` and `buildx-local.sh` accept `-c <config>` to override the config file (defaults to `configs/build.conf`). Any remaining arguments are forwarded to `docker buildx build` (e.g. `--no-cache`). `buildx-setup.sh` and `buildx-remote-fg.sh` accept an optional config path argument and default to `configs/remote.conf`.

## Configuration

Both `*.conf` files are git-ignored. Copy the templates and edit to taste.

### `configs/build.conf` (image settings)

| Variable | Description | Default |
|---|---|---|
| **Image manifest** | | |
| `ORGANIZATION` | Registry + org prefix (e.g. `ghcr.io/ntu-csieos26spring`) | |
| `IMAGE_NAME` | Image name | `mp-draft` |
| `IMAGE_TAG` | Image tag | `latest` |
| `REPOSITORY_SOURCE` | URL embedded in OCI labels | |
| `IMAGE_DESCRIPTION` | Human-readable description embedded in OCI labels | |
| **Image versions** | | |
| `PYTHON_VERSION` | Python base image version | `3.14` |
| `DEBIAN_SUITE` | Debian release codename | `trixie` |
| **QEMU** | | |
| `QEMU_VERSION` | QEMU version to build from source | `10.2.2` |
| `QEMU_GPG_KEY` | GPG key fingerprint for verifying the QEMU tarball | `CEACC9E1...` |
| `QEMU_RUNTIME_DEPS` | QEMU runtime library packages (suite-specific names) | `libpng16-16 libcurl4` |

### `configs/remote.conf` (distributed BuildKit cluster)

Only needed for distributed builds (`buildx-setup.sh` / `buildx-remote-fg.sh`).

| Variable | Description | Default |
|---|---|---|
| `MASTER_BUILDKIT_PORT` | Port the local BuildKit daemon listens on | `15424` |
| `SLAVE_BUILDKIT_PORT` | Port the remote BuildKit daemon listens on | `15423` |
| `MASTER_HOST` | IP of the master (local) machine | `127.0.0.1` |
| `SLAVE_HOST` | IP of the slave (remote) machine | |
| `MASTER_PLATFORM` | Platform of master node (`linux/amd64` or `linux/arm64`) | `linux/amd64` |
| `SLAVE_PLATFORM` | Platform of slave node | `linux/arm64` |

## Project Structure

```
.
├── Dockerfile               # Multi-stage build definition
├── run-with-utils.sh        # Loader that sources utils/ then runs a command
├── scripts/                 # Executable scripts
│   ├── auth.sh              # GitHub + GHCR login helper
│   ├── buildx-setup.sh      # Creates the multi-node BuildKit cluster (distributed)
│   ├── buildx-remote-fg.sh  # Runs BuildKit on the remote slave node (distributed)
│   ├── buildx.sh            # Builds and pushes via the cluster builder (distributed)
│   ├── buildx-local.sh      # Builds and pushes on a single machine (slow, emulated)
│   ├── va.sh                # Vulnerability analysis with Trivy + Grype
│   ├── add-completions.sh   # Loads shell completions for va.sh into the current session
│   ├── va.complete.bash     # Bash completions for va.sh
│   └── va.complete.zsh      # Zsh completions for va.sh
├── configs/                 # Build configuration templates
│   ├── build.conf.template  # Template for image build configuration
│   └── remote.conf.template # Template for distributed BuildKit cluster setup
├── image-configs/           # Configuration files baked into the image
│   ├── tmux.conf            # tmux configuration baked into /etc/tmux.conf
│   └── screenrc             # GNU Screen configuration (not used in image)
├── utils/                   # Shell utility library (logging, pkg helpers, etc.)
├── qemu-build/
│   └── setup.sh             # Downloads, verifies, and compiles QEMU (version from build.conf)
└── image-root/              # Scripts sourced during the final image setup
    ├── packages.sh          # Installs runtime APT packages
    ├── locale.sh            # Configures locale and timezone
    ├── systemd.sh           # Optional systemd installation
    ├── setup.sh             # Creates the student user
    ├── fixuid.sh            # Configures fixuid for UID remapping
    ├── pip.sh               # Installs Python packages (parse)
    └── cleanup.sh           # Strips unused libs, caches, etc. to shrink image
```

## Vulnerability Analysis

`va.sh` scans a Docker image for known vulnerabilities using both [Trivy](https://github.com/aquasecurity/trivy) and [Grype](https://github.com/anchore/grype), then converts the SARIF reports to CSV via [sarif-tools](https://pypi.org/project/sarif-tools/).

```bash
./scripts/va.sh <[organization/]image[:tag]>
```

The script:
1. Exports the image to a tarball under `/tmp/image-tarballs/`
2. Runs Trivy and Grype in containers against the tarball
3. Parses the SARIF output into CSV files under `va-reports/`

If reports already exist for the image, the script prompts before overwriting.

### Shell completions

Source `add-completions.sh` to get tab-completion for image names in `va.sh`:

```bash
source ./scripts/add-completions.sh
./scripts/va.sh <TAB>              # completes from local Docker images
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
7. **cleanup.sh** -- aggressively removes unused libs (sanitizers, LTO, docs, etc.) to shrink the image

Finally, as the `student` user, it sets up gdb safe-path, installs oh-my-bash + ble.sh into `.bashrc`, and optionally sets a user password. The entrypoint is `fixuid -q` so that bind-mounted volumes get correct ownership.
