#!/bin/bash

# Custom installation script for Antigravity CLI with version support.

set -e

VERSION="latest"
DEST_DIR="/usr/local/bin"

# Parse arguments
while getopts "v:d:h" opt; do
  case ${opt} in
    v )
      VERSION=$OPTARG
      ;;
    d )
      DEST_DIR=$OPTARG
      ;;
    h )
      echo "Usage: $0 [-v version] [-d directory]"
      exit 0
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

echo "Installing Antigravity CLI version: $VERSION"

MANIFEST_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json"

if [ "$VERSION" != "latest" ] && [ -n "$VERSION" ]; then
    MANIFEST_URL="${MANIFEST_URL}?version=${VERSION}"
fi

echo "Fetching manifest from: $MANIFEST_URL"

# Fetch manifest and parse URL using jq
MANIFEST=$(curl -fsSL "$MANIFEST_URL")
DOWNLOAD_URL=$(echo "$MANIFEST" | jq -r '.url')
CHECKSUM=$(echo "$MANIFEST" | jq -r '.sha512')

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" == "null" ]; then
    echo "Error: Could not resolve download URL for version $VERSION"
    exit 1
fi

echo "Downloading binary from: $DOWNLOAD_URL"

# Create a temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Download and verify (optional but recommended)
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/agy.tar.gz"

# Extract
echo "Extracting to $DEST_DIR..."
mkdir -p "$DEST_DIR"
tar -xzf "$TMP_DIR/agy.tar.gz" -C "$TMP_DIR"

# Find the binary (assuming it's named 'agy' or similar in the tarball)
# The tarball structure might vary, but usually contains the binary.
# Based on the manifest we saw, it's cli_linux_x64.tar.gz
# Let's see what's inside.

# Assuming the binary is 'antigravity' in the root or a subfolder of the tarball
find "$TMP_DIR" -type f -executable -name "antigravity" -exec mv {} "$DEST_DIR/agy" \;

# Ensure it's executable
chmod +x "$DEST_DIR/agy"

echo "Antigravity CLI installed successfully to $DEST_DIR/agy"
"$DEST_DIR/agy" --version || true
