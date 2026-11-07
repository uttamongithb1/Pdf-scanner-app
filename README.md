# PDF Scanner

A local-first **Flutter Android/iOS app** for turning paper and photos into multi-page PDFs, with saved page images in an app-named folder.

## What's implemented

- Automatic document scanning: **ML Kit** on Android, **VisionKit** on iOS.
- Manual camera fallback and multi-image import.
- Multiple durable/resumable drafts, drag/accessibility ordering, removal/undo and in-place retake even at fifty pages; four-corner crop, rotation and filters.
- A4 / Letter / image-fit export, margins, orientation and quality presets.
- PDF and processed-image saving; optional original-image copies.
- Android local-folder selection through SAF; iOS Files-visible Documents container.
- Native export progress/cancellation, capture/export receipts, recoverable rename/delete intents and conservative cleanup.
- Document search/sort, grid/list, in-app PDF preview, share, rename and delete.
- Light/dark modes, defaults, basic storage cleanup.
- Optional **Firebase Crashlytics + Analytics**, off by default and not connected to a project yet.

## Run

Use Flutter **3.35.7**, Java **17** for Android, and Xcode/CocoaPods on a Mac for iOS.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The native projects are included—do not regenerate them with `flutter create .`.

**Development build, not store-ready.** The latest GitHub Actions run passed all five jobs: Android debug/optimized development APKs, iOS simulator/unsigned-release compilation, strict analysis, **27 Flutter tests**, **5 Android native integration cases**, **4 iPhone-simulator cases** (1 Android-only skip), Python regressions and native PDF-writer checks. See [verified build results and downloads](docs/BUILD_STATUS.md) for current Android/iOS outcomes. Local SDK installation is blocked by workspace download restrictions, and no physical-device run is claimed. Production signing and device qualification remain necessary; see [implementation status](docs/IMPLEMENTATION.md).

## Public preview downloads

**[Open GitHub Release v0.1.0-preview.1](https://github.com/uttamongithb1/Pdf-scanner-app/releases/tag/v0.1.0-preview.1)**

- **[Android APK — direct download](https://github.com/uttamongithb1/Pdf-scanner-app/releases/download/v0.1.0-preview.1/pdf-scanner-v0.1.0-preview.1-android.apk)**: Android 8.0+, approximately 53.7 MB. Open the downloaded APK to install. Development/debug signed, not a production Play release.
- **[iOS simulator archive — Mac only](https://github.com/uttamongithb1/Pdf-scanner-app/releases/download/v0.1.0-preview.1/pdf-scanner-v0.1.0-preview.1-ios-simulator.tar.gz)**: **NOT an IPA and cannot be installed on an iPhone/iPad**. Apple signing and TestFlight/App Store distribution are not configured.
- The release includes installation instructions, `SHA256SUMS.txt` and build provenance. These are direct release assets, not expiring Actions ZIP downloads.

This is a **pre-release**. Keep independent copies of important documents. Updating a development-signed installation may require uninstalling, which deletes app-private drafts/files.

## Where files go

```text
PDF Scanner/
├── PDFs/
└── Images/
    ├── Processed/<document-id>/page-001.jpg
    └── Originals/<document-id>/page-001.jpg   # optional
```

- **Android:** choose Internal storage or SD card in the system folder picker; the app creates `PDF Scanner` there. Without a grant, the fallback is labelled private app storage. Cloud providers are not accepted as the local library.
- **iOS:** Files → On My iPhone / iPad → PDF Scanner. App-owned files may be removed when uninstalling. Share copies elsewhere to retain them independently.

No account, advertising or app-operated document upload. Hosted scanner provisioning and OS backup/sharing have separate platform behaviours; do not interpret local processing as a guarantee against user/OS backups.

## Code

```text
lib/
  core/        Models, SQLite, controller, native bridge, optional monitoring
  ui/          Home/library, review/editor/crop, export, viewer, settings
android/       Kotlin scanner, SAF storage, transforms, streaming JPEG PDF writer
ios/           Swift VisionKit/Core Image/Core Graphics pipeline and Files storage
test/          Flutter model/channel/widget tests and JVM writer smoke fixture
scripts/       Repository, syntax and independent PDF checks
.github/       Android/iOS/shared/PDF-writer CI definitions
```

## Documents

| Document | Purpose |
|---|---|
| [PRD.md](PRD.md) | Proposed product scope and engineering requirements |
| [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | Lumen design specification |
| [Build guide](docs/BUILD.md) | Toolchains, running, checks and platform setup |
| [Implementation status](docs/IMPLEMENTATION.md) | Implemented source, executed tests, deviations and release gaps |
| [Monitoring setup](docs/MONITORING.md) | Connect your Firebase project and configure consent/symbols |
| [Device test plan](docs/DEVICE_TEST_PLAN.md) | Capture/storage/recovery/performance acceptance checklist |

Platform shell templates originate from Flutter 3.35.7 under its [BSD licence](docs/FLUTTER_TEMPLATE_LICENSE). Production signing, store disclosures, Firebase project registration and device validation require your own configuration.
