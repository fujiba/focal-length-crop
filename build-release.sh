#!/usr/bin/env bash
#
# build-release.sh
# 配布用の .zip パッケージを生成する。
# Info.lua から VERSION を抽出してファイル名に埋め込む。
#
# Usage: ./build-release.sh

set -euo pipefail

PLUGIN_DIR="FocalLengthCrop.lrplugin"
INFO_LUA="${PLUGIN_DIR}/Info.lua"
DIST_DIR="dist"

if [[ ! -d "${PLUGIN_DIR}" ]]; then
    echo "Error: ${PLUGIN_DIR} not found. Run this script from project root." >&2
    exit 1
fi

# Info.lua から VERSION = { major = X, minor = Y, revision = Z } を抽出
VERSION_LINE=$(sed -n -E '/VERSION[[:space:]]*=/p' "${INFO_LUA}")
MAJOR=$(echo "${VERSION_LINE}" | sed -n -E 's/.*major[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p')
MINOR=$(echo "${VERSION_LINE}" | sed -n -E 's/.*minor[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p')
REVISION=$(echo "${VERSION_LINE}" | sed -n -E 's/.*revision[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p')

VERSION="${MAJOR}.${MINOR}.${REVISION}"
ZIP_NAME="FocalLengthCrop-v${VERSION}.zip"

echo "Building ${ZIP_NAME}..."

mkdir -p "${DIST_DIR}"
rm -f "${DIST_DIR}/${ZIP_NAME}"

# .DS_Store などを除外してzip化
zip -r "${DIST_DIR}/${ZIP_NAME}" "${PLUGIN_DIR}" \
    -x "*.DS_Store" \
    -x "*/Thumbs.db" \
    -x "*~"

echo ""
echo "Done: ${DIST_DIR}/${ZIP_NAME}"
ls -lh "${DIST_DIR}/${ZIP_NAME}"
