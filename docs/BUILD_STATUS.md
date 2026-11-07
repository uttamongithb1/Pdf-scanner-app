# Verified Android and iOS build results

Updated **7 November 2026**. This is a compiled and emulator/simulator-tested **development app**, not a store-qualified production release.

## Latest all-green build

**All five jobs passed** in [GitHub Actions run 42335247077](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/42335247077).

- Validated application source: `4a7ae5f73fb457ac953d3e04cbface22ee22d726`.
- Branch: `arena/dd30c98a-pdf-scanner-app`; main was not changed.
- Flutter **3.35.7** / Dart **3.9**, Java **17** on Linux for Android, macOS/Xcode for iOS.
- Subsequent documentation-only updates do not change that tested application source.

| Check | Executed result |
|---|---|
| Locked Flutter dependency resolution | Passed |
| Strict `flutter analyze` | **No issues found** |
| Flutter unit/widget tests with coverage | **27 passed**, including retake at fifty pages, cancellation, capture replay, draft recovery and reporting-consent regressions |
| Python asset/lock-transfer regression tests | **8 passed** |
| Repository/platform/privacy-default checks | Passed |
| Android debug APK | Built and uploaded |
| Android optimized release-mode APK | Built and uploaded, **53.7 MB**, explicitly development/debug signed |
| Unconfigured production-signing negative test | Passed: release rejected without private signing or explicit development override |
| Android API 35 x86_64 emulator native integration | **5 passed** |
| iOS simulator debug app | Built and uploaded |
| iPhone 16 Pro simulator native integration | **4 passed, 1 Android-only case explicitly skipped** |
| iOS device release compilation (`--no-codesign`) | Passed, **24.4 MB**; unsigned and not installable on an iPhone |
| Actual Kotlin JPEG PDF writer plus independent PDF parsing/rendering | Passed, including three-/fifty-page output |
| iOS Podfile.lock unchanged after native builds | Passed |

### Native scenarios actually exercised

- Synthetic image staging; Original/Enhanced/Greyscale/B&W previews; greyscale/B&W pixel-channel assertions; exact 0/90/180/270-degree dimensions; invalid quadrilateral rejection.
- PDF generation, page rendering, idempotent rename and delete with deletion acknowledgement.
- Fifty-page export and last-page rendering; induced real SQLite commit failure, transactional rollback and successful retry.
- Corrupt image input rolls back an already partially staged batch.
- Maintenance removes old unreferenced previews while preserving referenced ones.
- Android additionally replays persisted rename and partial-delete crash windows. This is simulated journal replay, **not proof of real OS process-kill handling**.

An earlier iOS simulator attempt stalled and was superseded without a runtime verdict. The final run establishes a Flutter surface before offscreen image work, bounds native test timeouts and passes the actual iPhone-simulator cases. Earlier analysis/fixture compilation findings were corrected and rerun rather than declared passing.

## Published GitHub preview

[Release v0.1.0-preview.1](https://github.com/uttamongithb1/Pdf-scanner-app/releases/tag/v0.1.0-preview.1) is public, with a directly installable **development-signed Android APK**, a clearly labelled **Mac/iOS-simulator-only archive**, `INSTALL.md`, `SHA256SUMS.txt` and `BUILD_PROVENANCE.json`. No installable iPhone IPA is available.

[Publisher run 42358470102](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/42358470102) passed. It verified the pinned successful source/run/artifact IDs and digests, confirmed that application sources match merged main commit `d76898ec789501380f9e03df1cc755d3f8733cb9`, checked APK/simulator structure and uploaded every asset before publishing the pre-release. Fifteen Python regressions now include release-publisher safety tests. Application binaries are unchanged from the validated build below.

- [Direct Android APK](https://github.com/uttamongithb1/Pdf-scanner-app/releases/download/v0.1.0-preview.1/pdf-scanner-v0.1.0-preview.1-android.apk): **53,687,854 bytes**, no ZIP extraction required.
- [iOS simulator archive](https://github.com/uttamongithb1/Pdf-scanner-app/releases/download/v0.1.0-preview.1/pdf-scanner-v0.1.0-preview.1-ios-simulator.tar.gz): **53,674,583 bytes**, not usable on an iPhone/iPad.

## Original Actions downloads

Sign in to GitHub if prompted. Downloads are artifact ZIPs containing an APK or tarball. Artifacts expire; rebuild using [BUILD.md](BUILD.md) if necessary.

- **[Optimized Android development APK](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/42335247077/artifacts/13559024471)** — extract `app-release.apk`. ZIP **25,295,867 bytes**; APK approximately **53.7 MB**. AOT compiled but debug signed: **not Play-ready**.
- [Android debug APK](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/42335247077/artifacts/13559451668) — extract `app-debug.apk`.
- [iOS simulator app](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/42335247077/artifacts/13559526601) — extract `ios-simulator-app.tar.gz` on a compatible Mac. The tarball preserves executable permissions/framework symlinks. **Not an iPhone IPA.**
- [Android native-memory sampling report](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/42335247077/artifacts/13559431710).
- [Resolved Flutter package lock](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/42335247077/artifacts/13558948753).

SHA-256 of the optimized Android **artifact ZIP**, reported by GitHub, not the extracted APK:

```text
94b72af09be65c3a56d9d7c09e5560da75130d37c1d804e347f5b8c478bf02f5
```

Install the extracted APK on an Android 8.0+ device using platform-tools:

```sh
adb install -r app-release.apk
```

Alternatively, transfer the APK to the phone and open it, allowing installation from that source when Android prompts. A different development signing key can prevent updating an older installation. **Uninstalling removes private drafts/data**: independently retain important exported files before uninstalling.

## Memory evidence — deliberately limited

The final Android integration report contains **2 whole-app emulator/debug samples**:

| Measurement | Maximum sampled value |
|---|---:|
| Total app PSS | **237,523 KiB** |
| Total app RSS | **356,488 KiB** |

These are not Dart-heap-only values. They are also **not true peak memory, not per-scenario attribution, and not a release/physical-phone benchmark**. Two-second sampling misses short peaks; hosted scanner process memory is excluded. The fifty-page fixture repeats a small synthetic image, not fifty high-resolution camera photographs. Do not use these figures to claim the PRD's real-device memory/latency targets are qualified.

## Dependency locks

Both checked-in locks match the resolved graph used by the final passing builds. Public locks were originally transferred with bounded chunks and SHA-256 integrity checks; no credentials or private configuration were exported.

| File | SHA-256 |
|---|---|
| `pubspec.lock` | `c3fa7e7d69b342c6707807100db4f37d04597585755cf28e7f1236d576a48dfc` |
| `ios/Podfile.lock` | `714ce0739c406d5b6e79dfd105292c57c34869097e7bc5d772432fa7df16a1b1` |

## Workspace versus remote execution

Current local checks pass: repository metadata/import/privacy checks, source parsing of twenty-six Dart/Kotlin/Swift files and eight Python regressions. Formatting was applied with the Dart WASM formatter. The actual Kotlin PDF writer has also been executed with an independent PDF parser in earlier workspace validation and again in the final remote CI job.

This restricted Linux workspace cannot run the full Flutter/Android SDK or Xcode. Download hosts for the mobile toolchains are blocked; caches are ephemeral. **Actual Flutter analysis/tests, Android compilation/emulation and iOS compilation/simulator execution above ran on GitHub-hosted Linux/Mac runners.** Source parsing was never substituted for those executions. Actions artifact downloads redirect to a blob host blocked from this workspace; open the browser download links above instead.

## Remaining release gates

- Protected Android production signing and final application ID; Apple team/provisioning for an installable iPhone build or App Store IPA. Development signing is not production signing.
- Physical-device camera/offline-fallback/SAF/Files tests, actual process kills, low-storage behaviour, independent PDF readers, accessibility and high-resolution fifty-page release/profile performance: [device acceptance plan](DEVICE_TEST_PLAN.md).
- English-first scope remains explicit. Full externalised localisation/Hindi, full RTL/screen-reader qualification and visual goldens are unfinished product/QA work, not features proven by these tests.
- Optional Firebase remains unconfigured/default-off. An owner-configured build requires consent/network audit, symbol uploads and accurate disclosures before distribution.
- Final store SDK/licence/privacy/backup review and brand approval. See [implementation boundaries](IMPLEMENTATION.md).

**No physical-device performance qualification, signed iPhone IPA or store-ready release is claimed.**
