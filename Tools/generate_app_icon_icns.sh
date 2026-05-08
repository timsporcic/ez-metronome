#!/bin/sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

swift \
  -module-cache-path "$ROOT_DIR/DerivedData/ModuleCache.noindex" \
  "$ROOT_DIR/Tools/generate_app_icon.swift"
