#!/usr/bin/env bash
DOCKER_CMD="${DOCKER_CMD:-docker}"

if [ $# != 1 ]; then
	echo 'Usage: [DOCKER_CMD="sudo docker"] ./va.sh <[organization/]image[:tag]>'
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
OUTPUT_DIR="va-reports/"
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
$DOCKER_CMD save -o "$TARBALL_DIR/$FILENAME.tar" "$IMAGE" 

# Trivy
echo "===Trivy Analyzing==="
mkdir -p "$TRIVY_CACHE/image-reports/$FILEDIR"
$DOCKER_CMD run --rm \
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


$DOCKER_CMD run --rm \
  -v "$TARBALL_DIR":/workspace:ro,z \
  -v "$GRYPE_CACHE":/.cache/grype \
  "docker.io/anchore/grype:$GRYPE_IMAGE_TAG" \
  "/workspace/$FILENAME.tar" \
  -o sarif \
  --file "/.cache/grype/image-reports/$FILENAME.grype.sarif"

# Parse the SARIF file to OUTPUT_FORMAT
echo "===Outputting==="
if [ ! -d ".venv" ]; then
    uv venv image-va --python 3.11
    uv pip install sarif-tools 
fi

# shellcheck source=/dev/null
source .venv/bin/activate
mkdir -p "$OUTPUT_DIR/$FILEDIR"
sarif $OUTPUT_FORMAT -o "$TRIVY_OUTPUT_PATH" "${SARIF_OUTPUT_OPTION[@]}" "$TRIVY_CACHE/image-reports/$FILENAME.trivy.sarif"
sarif $OUTPUT_FORMAT -o "$GRYPE_OUTPUT_PATH" "${SARIF_OUTPUT_OPTION[@]}" "$GRYPE_CACHE/image-reports/$FILENAME.grype.sarif"
deactivate
