#!/usr/bin/env bash
# Release builds for SchoolSync.
#
#   scripts/build_apk.sh            # split-per-abi APKs  (sideload / QA / most stores' APK uploads)
#   scripts/build_apk.sh aab        # Play Store App Bundle
#   scripts/build_apk.sh debug      # debug APK for phone testing (arm64 + x86_64), includes Developer options
#
# Extra flags pass straight through, e.g. your production dart-defines:
#   scripts/build_apk.sh apk --dart-define=BASE_DOMAIN=myschool.app --dart-define=PIN_SHA256=...
#
# Release builds are obfuscated and shrunk (R8). KEEP build/symbols/<version>/ AND the R8 mapping file
# (build/app/outputs/mapping/release/mapping.txt): without them crash reports cannot be de-obfuscated.
# They are copied to dist/symbols/<version>+<build>/ for you to archive (dist/ is gitignored).
#
# Memory: on a shared dev machine run it as
#   /home/bala/SCHOOL-SYNC/scripts/dev/heavy.sh -m 5G -- scripts/build_apk.sh
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-apk}"
[[ $# -gt 0 ]] && shift || true

VERSION="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"   # e.g. 1.0.0+1
SYMBOLS="build/symbols/${VERSION}"

case "$MODE" in
  apk)
    flutter build apk --release --split-per-abi --obfuscate --split-debug-info="$SYMBOLS" "$@"
    ;;
  aab)
    flutter build appbundle --release --obfuscate --split-debug-info="$SYMBOLS" "$@"
    ;;
  debug)
    flutter build apk --debug --target-platform android-arm64,android-x64 "$@"
    echo "Debug APK: build/app/outputs/flutter-apk/app-debug.apk"
    exit 0
    ;;
  *)
    echo "usage: $0 [apk|aab|debug] [extra flutter flags]" >&2
    exit 2
    ;;
esac

mkdir -p "dist/symbols/${VERSION}"
cp -r "$SYMBOLS"/. "dist/symbols/${VERSION}/"
MAPPING="build/app/outputs/mapping/release/mapping.txt"
[[ -f "$MAPPING" ]] && cp "$MAPPING" "dist/symbols/${VERSION}/r8-mapping.txt"

if [[ ! -f android/key.properties ]]; then
  echo
  echo "WARNING: android/key.properties is missing, so this build is signed with the DEBUG key."
  echo "         It installs fine for local testing but MUST NOT be uploaded to a store. See README > Release signing."
fi
echo
echo "Archive dist/symbols/${VERSION}/ (Dart symbols + R8 mapping) with the release."
ls -la build/app/outputs/flutter-apk/*.apk build/app/outputs/bundle/release/*.aab 2>/dev/null || true
