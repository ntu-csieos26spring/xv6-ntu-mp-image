# xv6-ntu-mp-image

A multi-architecture Docker image for NTU xv6 machine problems. Builds a slim, self-contained environment with QEMU (RISC-V 64), cross-compilation toolchains, and developer niceties (oh-my-bash, ble.sh, tmux, gdb-multiarch).

## Quick Start

### Prerequisites

- Docker (with BuildKit) or Podman
- [GitHub CLI (`gh`)](https://cli.github.com/) for authentication
- A remote ARM64 machine (if building multi-arch)

### 1. Authenticate with GHCR

```bash
./scripts/auth.sh <your-github-username>
```

This logs you into GitHub via `gh` and pipes a token to `docker login ghcr.io`. For Podman, log in directly with `podman login ghcr.io`.

> [!NOTE]
> Every script auto-detects whether `sudo` is needed (via `docker info` / `podman info`). There are separate script sets for Docker (`docker-build-*`) and Podman (`podman-build-*`).

### 2. Create your config files

```bash
cp configs/build.conf.template configs/build.conf       # image settings (always needed)
# For distributed Docker builds:
cp configs/remote.conf.template configs/remote.conf     # remote BuildKit cluster
# For distributed Podman builds:
cp configs/podman-remote.conf.template configs/podman-remote.conf  # remote SSH connection
# Edit to match your environment
```

See [Configuration](#configuration) below.

### 3. Build and push

There are two ways to produce the multi-arch image (distributed or local), with separate script sets for Docker and Podman.

#### Option A: Distributed build (recommended)

Dispatches each platform to a **native** machine so nothing is emulated. Requires two machines -- one per architecture.

##### Docker

On the **remote (slave) node**, start a BuildKit daemon in the foreground:

```bash
./scripts/docker-build-remote-fg.sh      # reads configs/remote.conf
```

On the **master node**, create the multi-node builder and kick off the build:

```bash
./scripts/docker-build-setup.sh          # reads configs/remote.conf, creates cluster-builder
./scripts/docker-build.sh                # reads configs/build.conf, builds both platforms natively, then pushes
```

##### Podman

On the **remote (slave) node**, start the podman API socket (or enable `podman.socket` via systemd):

```bash
./scripts/podman-build-remote-fg.sh
```

On the **master node**, create the farm and build:

```bash
./scripts/podman-build-setup.sh          # reads configs/podman-remote.conf, adds SSH connection + creates farm
./scripts/podman-build.sh                # reads configs/build.conf + podman-remote.conf, builds in parallel via podman farm
```

#### Option B: Local build (single machine)

Builds both platforms locally. The non-native platform is emulated via QEMU userspace emulation, which is **significantly slower**.

```bash
./scripts/docker-build-local.sh          # Docker
./scripts/podman-build-local.sh          # Podman
```

#### Script options

Both `docker-build.sh` and `docker-build-local.sh` accept `-c <config>` to override the build config (defaults to `configs/build.conf`). Any remaining arguments are forwarded to `docker buildx build` (e.g. `--no-cache`). `docker-build-setup.sh` and `docker-build-remote-fg.sh` accept an optional config path argument and default to `configs/remote.conf`.

The `podman-build-*` scripts follow the same pattern: `-c <config>` for build config. `podman-build.sh` also accepts `-r <config>` for the remote connection config (defaults to `configs/podman-remote.conf`). Remaining arguments are forwarded to `podman build`.

## Configuration

All `*.conf` files are git-ignored. Copy the templates and edit to taste.

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

Only needed for distributed Docker builds (`docker-build-setup.sh` / `docker-build-remote-fg.sh`).

| Variable | Description | Default |
|---|---|---|
| `MASTER_BUILDKIT_PORT` | Port the local BuildKit daemon listens on | `15424` |
| `SLAVE_BUILDKIT_PORT` | Port the remote BuildKit daemon listens on | `15423` |
| `MASTER_HOST` | IP of the master (local) machine | `127.0.0.1` |
| `SLAVE_HOST` | IP of the slave (remote) machine | |
| `MASTER_PLATFORM` | Platform of master node (`linux/amd64` or `linux/arm64`) | `linux/amd64` |
| `SLAVE_PLATFORM` | Platform of slave node | `linux/arm64` |

### `configs/podman-remote.conf` (distributed Podman builds)

Only needed for distributed Podman builds (`podman-build-setup.sh` / `podman-build.sh`).

| Variable | Description | Default |
|---|---|---|
| `FARM_NAME` | Name for `podman farm` | `cluster` |
| `CONNECTION_NAME` | Name for `podman system connection` | `slave` |
| `SLAVE_USER` | SSH username on the remote node | |
| `SLAVE_HOST` | IP of the slave (remote) machine | |
| `SLAVE_SSH_KEY` | Path to SSH private key | `$HOME/.ssh/id_rsa` |
| `SLAVE_PODMAN_SOCKET` | Path to podman socket on the remote | `/run/user/1000/podman/podman.sock` |

## Project Structure

```
.
├── Dockerfile               # Multi-stage build definition
├── run-with-utils.sh        # Loader that sources utils/ then runs a command
├── scripts/                 # Executable scripts
│   ├── auth.sh              # GitHub + GHCR login helper
│   ├── docker-detect.sh            # Auto-detects whether docker needs sudo
│   ├── docker-build-setup.sh      # Creates the multi-node BuildKit cluster (distributed)
│   ├── docker-build-remote-fg.sh  # Runs BuildKit on the remote slave node (distributed)
│   ├── docker-build.sh            # Builds and pushes via the cluster builder (distributed)
│   ├── docker-build-local.sh      # Builds and pushes on a single machine (slow, emulated)
│   ├── podman-detect.sh           # Auto-detects whether podman needs sudo
│   ├── podman-build-setup.sh     # Adds SSH connection + creates podman farm (distributed)
│   ├── podman-build-remote-fg.sh # Starts podman API socket on the remote node (distributed)
│   ├── podman-build.sh           # Builds in parallel via podman farm (distributed)
│   ├── podman-build-local.sh     # Builds and pushes manifest on a single machine (slow, emulated)
│   ├── va.sh                # Vulnerability analysis with Trivy + Grype
│   ├── add-completions.sh   # Loads shell completions for va.sh into the current session
│   ├── va.complete.bash     # Bash completions for va.sh
│   └── va.complete.zsh      # Zsh completions for va.sh
├── configs/                 # Build configuration templates
│   ├── build.conf.template         # Template for image build configuration
│   ├── remote.conf.template        # Template for distributed BuildKit cluster setup (Docker)
│   └── podman-remote.conf.template # Template for distributed podman farm setup
├── image-configs/           # Configuration files baked into the image
│   ├── tmux.conf            # tmux configuration baked into /etc/tmux.conf
│   └── screenrc             # GNU Screen configuration (not used in image)
├── utils/                   # Shell utility library (logging, pkg helpers, etc.)
├── qemu-build/
│   └── setup.sh             # Configures and compiles QEMU from a pre-verified tarball
└── image-root/              # Scripts sourced during the final image layers (ordered by filename)
    ├── base/                # L1: System utilities, locale, apt cleanup
    ├── user/                # L2: Student user creation + fixuid setup
    ├── systemd/             # L3: Optional systemd installation
    ├── devtools/            # L4: Native dev tools (git, make, gcc) + QEMU runtime deps + cleanup
    ├── riscv/               # L5: RISC-V cross-compiler, debugger + cleanup
    └── pip/                 # L6: Python packages (parse)
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

### Stage 0 -- `qemu-source` (Download + verify QEMU tarball)

A lightweight `alpine:3.23` stage that downloads the QEMU source tarball and verifies its GPG signature. Depends only on `QEMU_VERSION` and the GPG key, so it is fully cached regardless of `DEBIAN_SUITE` or `PYTHON_VERSION` changes.

### Stage 1a -- `qemu-builder` (Build QEMU from source)

Based on `debian:<suite>` (not `python:`, so Python version changes don't invalidate the QEMU build cache). Installs build dependencies via apt, then compiles QEMU targeting `riscv64-softmmu` with GUI, network, audio, and KVM backends disabled. Supports cross-compilation (e.g. building ARM64 binaries on an AMD64 host) via `CROSS_PREFIX`.

### Stage 1b -- `base-builder` (Build shell tools)

Based on `debian:<suite>`. Builds [ble.sh](https://github.com/akinomyoga/ble.sh) and fetches the [oh-my-bash](https://github.com/ohmybash/oh-my-bash) installer. Runs in parallel with the other builder stages.

### Stage 1c -- `go-builder` (Build fixuid)

Based on `golang:1-<suite>`. Compiles [fixuid](https://github.com/boxboat/fixuid) v0.6.0 as a static binary for the target architecture. This avoids downloading from GitHub CDN at runtime.

### Stage 2 -- `scripts` (Cherry-pick runtime files)

A `scratch`-based staging area that gathers artifacts from previous stages and the build context into two directory trees:

- `/rootfs/` -- root-owned files: QEMU binary, OpenSBI firmware, fixuid, and tmux.conf.
- `/homefs/` -- user-owned files: ble.sh and oh-my-bash installer.

### Stage 3 -- `runner` (Final slim image)

Based on `python:<version>-slim-<suite>`. Copies in binaries from `scripts`, then runs setup scripts from `image-root/` subdirectories as separate layers ordered by change frequency (least to most volatile):

- **L0** -- binary artifacts (QEMU, fixuid, /etc configs)
- **L1** (`base/`) -- system utilities (sudo, tmux, procps), locale, apt cleanup
- **L2** (`user/`) -- creates the `student` user with passwordless sudo, configures fixuid
- **L3** (`systemd/`) -- optionally installs systemd (if `USE_SYSTEMD=yes`)
- **L4** (`devtools/`) -- native dev tools (git, make, gcc) + QEMU runtime deps, then strips sanitizers/LTO/docs
- **L5** (`riscv/`) -- RISC-V cross-compiler + gdb-multiarch, then strips cross-toolchain bloat
- **L6** (`pip/`) -- installs the `parse` Python package
- **L7** -- user shell configuration (gdb safe-path, oh-my-bash, ble.sh)
- **L8** -- optional user password

OCI labels are applied at the very end so metadata changes never bust any RUN cache. The entrypoint is `fixuid -q` so that bind-mounted volumes get correct ownership.

> [!NOTE]
> GitHub Actions overrides the image entrypoint when using this image as a container in a workflow. The `fixuid` entrypoint will not run in that context, so UID remapping does not apply.
