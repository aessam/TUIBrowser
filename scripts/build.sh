#!/bin/bash
# Build script with isolated build directory
# Usage: ./scripts/build.sh [agent_id]

AGENT_ID="${1:-default}"
BUILD_DIR="/tmp/tuibrowser_build_${AGENT_ID}"

echo "Building with scratch path: $BUILD_DIR"
swift build --scratch-path "$BUILD_DIR" "${@:2}"
