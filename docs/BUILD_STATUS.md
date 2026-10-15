# Verified Android and iOS build results

Updated: **15 October 2026**. This is a compiled **development app**, not a store-qualified production release.

## Final passing build

**All four jobs passed** in [GitHub Actions run 38719406316](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38719406316).

- Validated application source: `2c9d72b40f7ea55b27820f94c77d97d4fec24636`.
- Branch: `arena/dd30c98a-pdf-scanner-app`; main was not changed.
- Flutter 3.35.7 / Dart 3.9, Java 17 on Linux for Android, macOS/Xcode for iOS.
- Subsequent documentation-only commits do not change this built application.

| Check | Actual result |
|---|---|
| Locked dependency resolution (`flutter pub get --enforce-lockfile`) | Passed |
| Strict `flutter analyze` | **No issues found**; informational findings are no longer ignored |
| Flutter unit/widget tests with coverage | **13 tests passed** |
| Python asset/lock-transfer regression tests | **8 tests passed** |
| Repository/platform/privacy-default checks | Passed |
| Android debug APK | Built and uploaded |
| Android optimized release-mode APK | Built and uploaded; **development/debug signed** |
| iOS simulator debug app | Built and uploaded |
| iOS device release compilation (`--no-codesign`) | Passed; **unsigned, not installable on an iPhone** |
| Actual Kotlin PDF writer + independent 3/50-page PDF parsing/rendering | Passed |
| iOS Podfile.lock unchanged after native builds | Passed |

## Downloads

Sign in to GitHub if prompted. Each download is an artifact ZIP containing the APK or tarball. Actions artifacts have limited retention; use the build guide to rebuild if expired.

- **[Download optimized Android development APK](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38719406316/artifacts/11963399730)** — extract `app-release.apk`. ZIP about 24 MiB; APK about 54 MB. It is optimized/AOT-compiled but debug signed, **not Play-ready**.
- [Android debug APK](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38719406316/artifacts/11963379430) — extract `app-debug.apk`.
- [iOS simulator app](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38719406316/artifacts/11964258870) — extract `ios-simulator-app.tar.gz` on a compatible Mac. The tarball preserves framework symlinks and executable permissions. This is **not an iPhone IPA**.
- [Resolved Flutter package lock](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38719406316/artifacts/11964625645).

SHA-256 of the optimized Android **artifact ZIP**, as reported by GitHub (not the extracted APK):

```text
757f58ca2409bc44a44ccfe0d62908335caf037ff1e74cde2932857f0dc30046
```

To install the extracted APK on a connected Android 8.0+ phone from a machine with platform-tools:

```sh
adb install -r app-release.apk
```

Alternatively, transfer the APK to your Android phone, open it, and allow installation from that source when Android prompts. If an older development APK used a different signing key, Android may reject an update. Uninstalling removes app-private drafts/data: retain important exported files independently first.

## Dependency lock provenance

Both checked-in locks were retrieved from the final successful run, with chunk-completeness and SHA-256 verification. The Cupertino icon dependency was initially pinned using Flutter 3.35.7's official workspace lock entry, then verified and re-emitted by real CI package resolution.

| File | SHA-256 of CI-verified contents |
|---|---|
| `pubspec.lock` | `c3fa7e7d69b342c6707807100db4f37d04597585755cf28e7f1236d576a48dfc` |
| `ios/Podfile.lock` | `714ce0739c406d5b6e79dfd105292c57c34869097e7bc5d772432fa7df16a1b1` |

Build findings were addressed rather than treating authored source as a completed build: three empty launch images were repaired, multiline Dart control-flow lint findings and a redundant import were fixed, the required Cupertino font was bundled, and Flutter package/plugin regeneration was restored between debug/release build modes to avoid a stale integration-test plugin registration.

## Workspace installation and execution limits

The Linux workspace contains a Flutter 3.35.7 **source checkout** and working test-only Java 17 runtime/Kotlin 2.1/Python tools. It does **not** contain a working Flutter/Dart binary SDK, full JDK, Android SDK/adb or Xcode.

Official SDK/package downloads and Actions blob downloads are blocked by this workspace's network policy. Full local SDK installation therefore could not be completed. Actual Android compilation ran on GitHub-hosted Linux and iOS compilation on a GitHub-hosted Mac; open artifact links in your browser to download them. No Android emulator, physical phone, iPhone or simulator app run is claimed here.

The actual JVM PDF writer was also compiled and executed locally; structural checks, source parsing and the eight Python regression tests pass locally. Parser checks were not substituted for the real remote Flutter/native compilation.

## Remaining release requirements

- Configure a protected Android signing key before Play distribution. Both APK variants above are development signed.
- Apple signing/provisioning is required for an installable iPhone build or App Store IPA. Unsigned compilation alone cannot provide one.
- Execute [the device test plan](DEVICE_TEST_PLAN.md), including capture, gallery, SAF/Files, storage exhaustion, cancellation/process death, accessibility and 50-page performance.
- Firebase remains unconfigured and reporting is off by default; attach a developer-owned project only if wanted.
- Remaining product/recovery/branding/privacy gaps are documented in [implementation status](IMPLEMENTATION.md). Successful compilation does not qualify those acceptance criteria.

See [BUILD.md](BUILD.md) for toolchain setup, exact rebuild commands and platform-specific limitations.
