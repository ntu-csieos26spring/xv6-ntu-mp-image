#!/usr/bin/env bash
DOCKER_CMD="${DOCKER_CMD:-docker}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# != 1 ]; then
	echo 'Usage: [DOCKER_CMD="sudo docker"] ./scripts/va.sh <[organization/]image[:tag]>'
	exit 1
fi

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

# Package the image to OCI directory layout
echo "===Packing Image==="
rm -rf "$TARBALL_DIR/$FILENAME"
mkdir -p "$TARBALL_DIR/$FILENAME"
$DOCKER_CMD save "$IMAGE" | tar -xf - -C "$TARBALL_DIR/$FILENAME"

# Trivy
echo "===Trivy Analyzing==="
mkdir -p "$TRIVY_CACHE/image-reports/$FILEDIR"
$DOCKER_CMD run --rm \
  -v "$TARBALL_DIR":/workspace:ro,z \
  -v "$TRIVY_CACHE":/root/.cache/trivy \
  "docker.io/aquasec/trivy:$TRIVY_IMAGE_TAG" \
  image \
  --input "/workspace/$FILENAME" \
  -f sarif \
  -o "/root/.cache/trivy/image-reports/$FILENAME.trivy.sarif"

# Grype
echo "===Grype Analyzing==="
mkdir -p "$GRYPE_CACHE/image-reports/$FILEDIR"

$DOCKER_CMD run --rm \
  -v "$TARBALL_DIR":/workspace:ro,z \
  -v "$GRYPE_CACHE":/.cache/grype \
  "docker.io/anchore/grype:$GRYPE_IMAGE_TAG" \
  "oci-dir:/workspace/$FILENAME" \
  -o sarif \
  --file "/.cache/grype/image-reports/$FILENAME.grype.sarif"

# Parse the SARIF file to OUTPUT_FORMAT
echo "===Outputting==="
if [ ! -d "$REPO_ROOT/.venv" ]; then
    uv venv "$REPO_ROOT/image-va" --python 3.11
    uv pip install sarif-tools
fi

# shellcheck source=/dev/null
source "$REPO_ROOT/.venv/bin/activate"
mkdir -p "$OUTPUT_DIR/$FILEDIR"
sarif $OUTPUT_FORMAT -o "$TRIVY_OUTPUT_PATH" "${SARIF_OUTPUT_OPTION[@]}" "$TRIVY_CACHE/image-reports/$FILENAME.trivy.sarif"
sarif $OUTPUT_FORMAT -o "$GRYPE_OUTPUT_PATH" "${SARIF_OUTPUT_OPTION[@]}" "$GRYPE_CACHE/image-reports/$FILENAME.grype.sarif"
deactivate
