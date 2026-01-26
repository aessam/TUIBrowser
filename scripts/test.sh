#!/bin/bash
# Test script with isolated build directory
# Usage: ./scripts/test.sh [agent_id] [--filter ModuleName]

AGENT_ID="${1:-default}"
BUILD_DIR="/tmp/tuibrowser_build_${AGENT_ID}"

echo "Testing with scratch path: $BUILD_DIR"
swift test --scratch-path "$BUILD_DIR" "${@:2}"
