# Verified build status

Updated: **15 October 2026**. Development builds only; no store release or physical-device qualification is claimed.

## Passing Android and iOS builds

**All four jobs passed** in [GitHub Actions run 38715855688](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38715855688).

Validated application source: `6f126563d7c039c6d32566ba2d7c89214e4da546` on `arena/dd30c98a-pdf-scanner-app`. Tooling/documentation updates and committed dependency locks may follow this revision; this report identifies the exact app build rather than implying every later commit was already compiled.

| Check | Result |
|---|---|
| Real Flutter dependency resolution | Passed |
| Flutter static analysis (`--no-fatal-infos`) | Passed |
| Flutter unit/widget tests with coverage | Passed |
| Repository/platform/privacy-default checks | Passed |
| PNG asset regression tests | Passed |
| Android debug APK | Built and uploaded |
| Android optimized release-mode APK | Built and uploaded; **development/debug signed** |
| iOS simulator debug app | Built and uploaded |
| iOS device release compilation (`--no-codesign`) | Passed; **unsigned, not installable on an iPhone** |
| Actual Kotlin PDF writer + independent 3/50-page PDF parsing/rendering | Passed |

The first iOS build exposed three empty launch image placeholders. They were replaced with valid PNG assets; Xcode then compiled both simulator and device release targets. Regression checks now validate PNG framing, CRCs, compressed pixels and declared icon dimensions.

## Dependency locks and follow-up validation

`pubspec.lock` and `ios/Podfile.lock` were retrieved from the successful [run 38717258360](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38717258360), source `8ce49dcf672b8bfdc14184d029bc8886310f813c`. All four jobs in that run also passed; the resolved graph exactly matches the earlier fully passing app build above.

| File | SHA-256 of actual CI-generated contents |
|---|---|
| `pubspec.lock` | `7759a1359a3ace49ba46b3c2d2b12b896f96de73cc51f7cc7c6c20279d5f25c8` |
| `ios/Podfile.lock` | `714ce0739c406d5b6e79dfd105292c57c34869097e7bc5d772432fa7df16a1b1` |

The shared test report confirms **13 Flutter tests passed**. The original analyzer invocations allowed informational lint findings, not errors or warnings. A follow-up change adds explicit blocks to multiline control-flow bodies and removes a redundant import; CI now requires strict `flutter analyze` and `flutter pub get --enforce-lockfile`. Its results must be checked independently rather than inferred from the earlier run.

## Downloads

Sign in to GitHub if prompted. Actions artifacts have limited retention; rebuild if expired. Each download is an artifact ZIP containing the named APK or tarball.

- **[Optimized Android development APK](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38715855688/artifacts/11961894865)** — `app-release.apk`; artifact about 24 MiB.
- [Android debug APK](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38715855688/artifacts/11962203600) — `app-debug.apk`.
- [iOS simulator app](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38715855688/artifacts/11962278683) — `ios-simulator-app.tar.gz`. Extract on a compatible Mac; the tarball preserves framework symlinks and executable permissions. It cannot run on an iPhone.
- [Resolved Flutter package lock](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/38715855688/artifacts/11961893508).

To install an Android APK on a connected phone from a machine with platform-tools:

```sh
adb install -r app-release.apk
```

Alternatively, transfer the extracted APK to your Android phone, open it, and allow installation from that source when Android prompts. This is a development build, not a Play Store release. If a prior development build used a different signing key, Android may reject an update; uninstalling it removes app-private drafts/data, so independently retain important exports first.

## Workspace versus build runners

The Linux workspace contains a Flutter 3.35.7 **source checkout** and test-only Java 17 runtime/Kotlin 2.1/Python tools, not a working full mobile SDK. Official SDK/package downloads and Actions blob downloads are blocked by its network policy. Android compilation took place on GitHub-hosted Linux; iOS compilation on a GitHub-hosted Mac. No Android emulator, phone or iPhone run has occurred here.

Local structural checks, all 24 Dart/Kotlin/Swift source parses, the actual JVM PDF writer smoke test, and eight Python asset/lock-transfer regression tests pass. Flutter analysis/tests and the full native builds above were executed remotely, not substituted with parser checks.

## Remaining release requirements

- Android development APKs use debug signing, including the optimized release-mode variant. Configure your own protected signing key before distribution through Play.
- An iOS simulator app is not an iPhone install. Unsigned iOS release compilation does not produce an installable signed IPA; Apple signing/provisioning is required.
- Execute [the device test plan](DEVICE_TEST_PLAN.md), including camera, gallery, SAF/Files, storage exhaustion, cancellation/process death and 50-page performance checks.
- Firebase remains unconfigured and reporting is off by default. Provide a developer-owned project only if monitoring is wanted.
- Remaining product/recovery/branding/privacy gaps are listed in [implementation status](IMPLEMENTATION.md). Compilation is not proof of those acceptance criteria.

See [BUILD.md](BUILD.md) for setup, CI rebuild commands, dependency lock retrieval and platform-specific limitations.
