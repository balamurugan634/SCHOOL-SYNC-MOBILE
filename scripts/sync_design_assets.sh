#!/usr/bin/env bash
# Copies the shared "Soft Geometry" illustrations from the monorepo (design/illustrations) into
# assets/illustrations. Re-run after the design set changes. They are re-themed at runtime
# (see lib/core/design/illustration.dart), so the files must keep the six literal placeholder colours.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:-/home/bala/SCHOOL-SYNC/design/illustrations}"
mkdir -p assets/illustrations
cp "$SRC"/*.svg assets/illustrations/
echo "synced $(ls assets/illustrations | wc -l) illustrations from $SRC"
