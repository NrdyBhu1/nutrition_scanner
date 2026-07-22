#!/usr/bin/env bash
set -euo pipefail

BUILD_MODE="${BUILD_MODE:-release}"
OUTPUT_DIR="/output"

echo "==> Building Flutter APK (${BUILD_MODE}) with Flutter $(flutter --version | head -n1)"

flutter build apk --${BUILD_MODE}

mkdir -p "${OUTPUT_DIR}"

APK_SRC_DIR="/app/build/app/outputs/flutter-apk"

if [ -d "${APK_SRC_DIR}" ]; then
  cp -v "${APK_SRC_DIR}"/*.apk "${OUTPUT_DIR}/"
  echo "==> APK(s) copied to ${OUTPUT_DIR}"
else
  echo "==> ERROR: expected build output directory not found: ${APK_SRC_DIR}"
  exit 1
fi
