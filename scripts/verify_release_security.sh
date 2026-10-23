#!/usr/bin/env bash
# Proves the RELEASE build is HTTPS-only and carries no developer tooling.
#
#   scripts/verify_release_security.sh [path/to/app-release.apk]
#
# Checks (exit 1 on any failure):
#   * merged manifest: usesCleartextTraffic=false, allowBackup=false, networkSecurityConfig set, not debuggable
#   * the packaged network_security_config.xml permits no cleartext (no cleartextTrafficPermitted="true",
#     no cleartext domain-config)
#   * Dart code in libapp.so contains no "Developer options" UI strings
set -euo pipefail
cd "$(dirname "$0")/.."
APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
[[ -f "$APK" ]] || { echo "APK not found: $APK (build it first: scripts/build_apk.sh)"; exit 2; }

: "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-}}"
AAPT2="$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1 || true)"
[[ -x "${AAPT2:-}" ]] || { echo "aapt2 not found (set ANDROID_HOME)"; exit 2; }

fail=0
check() { # description, command...
  local d="$1"; shift
  if "$@"; then echo "  ok    $d"; else echo "  FAIL  $d"; fail=1; fi
}

MANIFEST="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK")"
NSC="$("$AAPT2" dump xmltree --file res/xml/network_security_config.xml "$APK" 2>/dev/null || true)"
[[ -z "$NSC" ]] && NSC="$("$AAPT2" dump xmltree --file "$("$AAPT2" dump resources "$APK" | grep -A3 'xml/network_security_config' | grep -o 'res/[^ ]*xml' | head -1)" "$APK")"

echo "Release manifest:"
check "android:usesCleartextTraffic is false"        grep -Eq 'usesCleartextTraffic.*=(false|0x0)' <<<"$MANIFEST"
check "android:allowBackup is false"                  grep -Eq 'allowBackup.*=(false|0x0)' <<<"$MANIFEST"
check "networkSecurityConfig is set"                  grep -q 'networkSecurityConfig' <<<"$MANIFEST"
check "application is not debuggable"                 bash -c '! grep -Eq "debuggable.*=(true|0xffffffff)" <<<"$0"' "$MANIFEST"

echo "Packaged network security config:"
check "base-config cleartextTrafficPermitted=false"   grep -Eq 'cleartextTrafficPermitted.*=(false|0x0)' <<<"$NSC"
check "no cleartextTrafficPermitted=true anywhere"    bash -c '! grep -Eq "cleartextTrafficPermitted.*=(true|0xffffffff)" <<<"$0"' "$NSC"
check "no domain-config exceptions (10.0.2.2, LAN)"   bash -c '! grep -q "domain-config" <<<"$0"' "$NSC"

echo "Developer tooling:"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
unzip -q -o "$APK" 'lib/*/libapp.so' -d "$TMP" 2>/dev/null || true
if ls "$TMP"/lib/*/libapp.so >/dev/null 2>&1; then
  check "no 'Developer options' UI in libapp.so"      bash -c '! strings -a "$@" | grep -q "Developer options"' _ "$TMP"/lib/*/libapp.so
  check "no dev API field in libapp.so"               bash -c '! strings -a "$@" | grep -q "Reset to build default"' _ "$TMP"/lib/*/libapp.so
else
  echo "  skip  libapp.so not found (is this a debug APK?)"; fail=1
fi
check "no kernel_blob.bin (debug payload) in APK"     bash -c '! unzip -l "$0" | grep -q kernel_blob.bin' "$APK"

if (( fail )); then echo "RELEASE SECURITY CHECK FAILED"; exit 1; fi
echo "Release security check passed: $APK"
