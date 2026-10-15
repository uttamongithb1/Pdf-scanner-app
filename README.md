# PDF Scanner

A local-first **Flutter Android/iOS app** for turning paper and photos into multi-page PDFs, with saved page images in an app-named folder.

## What's implemented

- Automatic document scanning: **ML Kit** on Android, **VisionKit** on iOS.
- Manual camera fallback and multi-image import.
- Durable drafts, page reordering/removal/retake, four-corner perspective crop, rotation and filters.
- A4 / Letter / image-fit export, margins, orientation and quality presets.
- PDF and processed-image saving; optional original-image copies.
- Android local-folder selection through SAF; iOS Files-visible Documents container.
- Native export progress/cancellation, recovery journal and commit receipts.
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

**Development build, not store-ready.** The complete mobile app has not been compiled or run in this workspace. It lacks the mobile SDKs and normal SDK download hosts are restricted. The standalone Android PDF writer **was compiled and tested** with an independent PDF parser/renderer. Platform builds and physical-device qualification are still required. See the exact [implementation status](docs/IMPLEMENTATION.md).

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
