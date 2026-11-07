#!/usr/bin/env bash
# Reports real capabilities without confusing SDK source with installed binaries.
set -uo pipefail
source "$(dirname "$0")/workspace_env.sh"
failed=0
if command -v java >/dev/null; then java -version; else echo 'MISSING: Java runtime'; failed=1; fi
if [[ -x "${JAVA_HOME:-/nonexistent}/bin/javac" ]]; then javac -version; else echo 'MISSING: full JDK (installed Java runtime has no javac)'; failed=1; fi
if [[ -x "$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart" ]]; then
  dart --version
  flutter --version
else
  echo 'MISSING: Dart/Flutter executable SDK artifacts (Flutter source checkout alone is not enough)'
  failed=1
fi
if command -v sdkmanager >/dev/null; then sdkmanager --version; else echo 'MISSING: Android SDK command-line tools'; failed=1; fi
if command -v adb >/dev/null; then adb version; else echo 'MISSING: Android platform-tools/adb'; failed=1; fi
if [[ "$(uname -s)" == Darwin ]] && command -v xcodebuild >/dev/null; then xcodebuild -version; else echo 'UNAVAILABLE: Xcode/iOS build (requires a Mac)'; fi
exit "$failed"
