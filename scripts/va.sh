#!/usr/bin/env bash
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# != 1 ]; then
	echo 'Usage: ./scripts/va.sh <[organization/]image[:tag]>'
	exit 1
fi

echo "Select container runtime:"
echo "  1) docker"
echo "  2) podman"
read -rp "Choice [1]: " choice
choice="${choice:-1}"

case "$choice" in
	1) source "$SCRIPT_DIR/docker-detect.sh"; CMD="$DOCKER_CMD" ;;
	2) source "$SCRIPT_DIR/podman-detect.sh"; CMD="$PODMAN_CMD" ;;
	*) echo "Invalid choice"; exit 1 ;;
esac

set -euo pipefail
IMAGE="$1"
OUTPUT_FORMAT="csv"
TARBALL_DIR="/tmp/image-tarballs"
TRIVY_CACHE="/tmp/trivy-cache"
GRYPE_CACHE="/tmp/grype-cache"

# Do not modify the variables below
# Replace ':' with '-'
FILENAME="${IMAGE//:/_}"
FILEDIR="$(dirname "$FILENAME")"
OUTPUT_DIR="$REPO_ROOT/va-reports/"
TRIVY_OUTPUT_PATH="$OUTPUT_DIR/$FILENAME.trivy.$OUTPUT_FORMAT"
GRYPE_OUTPUT_PATH="$OUTPUT_DIR/$FILENAME.grype.$OUTPUT_FORMAT"
# Do not modify the variables above

# might need to modify
SARIF_OUTPUT_OPTION=("--autotrim")
TRIVY_IMAGE_TAG="0.69.3"
GRYPE_IMAGE_TAG="v0.110.0"

# When the reports already exist, ask to continue
if [ -f "$TRIVY_OUTPUT_PATH" ] && [ -f "$GRYPE_OUTPUT_PATH" ]; then
    read -rp "Reports exist, still want to continue? (y/N): " resp
    resp=${resp:-N}
    resp=$(echo "$resp" | cut -c1 | tr 'Y' 'y')
    if [ "$resp" != 'y' ]; then
        exit 0
    fi
fi

# Package the image to tarball
echo "===Packing Image==="
rm -f "$TARBALL_DIR/$FILENAME.tar"
mkdir -p "$TARBALL_DIR/$FILEDIR"
$CMD save -o "$TARBALL_DIR/$FILENAME.tar" "$IMAGE" 

# Trivy
echo "===Trivy Analyzing==="
mkdir -p "$TRIVY_CACHE/image-reports/$FILEDIR"
$CMD run --rm \
  -v "$TARBALL_DIR":/workspace:ro,z \
  -v "$TRIVY_CACHE":/root/.cache/trivy \
  "docker.io/aquasec/trivy:$TRIVY_IMAGE_TAG" \
  image \
  --input "/workspace/$FILENAME.tar" \
  -f sarif \
  -o "/root/.cache/trivy/image-reports/$FILENAME.trivy.sarif"

# Grype
echo "===Grype Analyzing==="
mkdir -p "$GRYPE_CACHE/image-reports/$FILEDIR"


$CMD run --rm \
  -v "$TARBALL_DIR":/workspace:ro,z \
  -v "$GRYPE_CACHE":/.cache/grype \
  "docker.io/anchore/grype:$GRYPE_IMAGE_TAG" \
  "/workspace/$FILENAME.tar" \
  -o sarif \
  --file "/.cache/grype/image-reports/$FILENAME.grype.sarif"

# Parse the SARIF file to OUTPUT_FORMAT
echo "===Outputting==="
if [ ! -d "$REPO_ROOT/image-va" ]; then
    uv venv "$REPO_ROOT/image-va" --python 3.11
    uv pip install sarif-tools
fi

# shellcheck source=/dev/null
source "$REPO_ROOT/image-va/bin/activate"
mkdir -p "$OUTPUT_DIR/$FILEDIR"
sarif $OUTPUT_FORMAT -o "$TRIVY_OUTPUT_PATH" "${SARIF_OUTPUT_OPTION[@]}" "$TRIVY_CACHE/image-reports/$FILENAME.trivy.sarif"
sarif $OUTPUT_FORMAT -o "$GRYPE_OUTPUT_PATH" "${SARIF_OUTPUT_OPTION[@]}" "$GRYPE_CACHE/image-reports/$FILENAME.grype.sarif"
deactivate
