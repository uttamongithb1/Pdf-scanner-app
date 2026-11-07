#!/usr/bin/env bash
# Source this file in each fresh terminal. Tool binaries are NOT tracked.
LUMEN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FLUTTER_ROOT="${FLUTTER_ROOT:-$LUMEN_ROOT/.cache/toolchains/flutter}"
export PUB_CACHE="${PUB_CACHE:-$LUMEN_ROOT/.cache/pub}"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$LUMEN_ROOT/.cache/toolchains/android-sdk}}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
# Never replace a caller's full JDK with the test-only Java runtime.
if [[ ! -x "${JAVA_HOME:-/nonexistent}/bin/java" ]] && [[ -x "$LUMEN_ROOT/.cache/python/jdk4py/java-runtime/bin/java" ]]; then
  export JAVA_HOME="$LUMEN_ROOT/.cache/python/jdk4py/java-runtime"
fi
export PATH="$FLUTTER_ROOT/bin:${JAVA_HOME:+$JAVA_HOME/bin:}$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$LUMEN_ROOT/.cache/kotlin/node_modules/kotlin-compiler/bin:$PATH"
export PYTHONPATH="$LUMEN_ROOT/.cache/python${PYTHONPATH:+:$PYTHONPATH}"
export FLUTTER_SUPPRESS_ANALYTICS=true
