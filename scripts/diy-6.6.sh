#!/bin/bash
set -e -o pipefail

WORKSPACE_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"

# Inject standalone golang1.26 feed without changing default golang
GOLANG126_SRC_DIR="$WORKSPACE_ROOT/scripts/golang1.26"
GOLANG126_FEED_DIR="feeds/packages/lang/golang1.26"
rm -rf "$GOLANG126_FEED_DIR"
mkdir -p "$GOLANG126_FEED_DIR"
cp -rf "$GOLANG126_SRC_DIR/." "$GOLANG126_FEED_DIR/"
./scripts/feeds update -f packages
./scripts/feeds install golang1.26


# passwall daed use golang1.26/host
find package/dae package/passwall-packages -name "Makefile" -type f -exec sed -i \
  -e 's|\<golang/golang-package.mk\>|golang1.26/golang-package.mk|g' \
  -e 's|\<golang/host\>|golang1.26/host|g' {} +
