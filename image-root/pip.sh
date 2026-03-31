#!/bin/sh
set -euo pipefail

# Install Python test packages
pip3 install --no-cache-dir --root-user-action=ignore --upgrade pip
pip3 install --no-cache-dir --root-user-action=ignore parse
PYTHON_MINOR=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
rm -rf /usr/local/lib/python${PYTHON_MINOR}/ensurepip
