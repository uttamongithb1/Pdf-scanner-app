# Implementation status — 0.1.0

Updated **7 November 2026**. This is an Android/iOS development application. Implemented source, executed emulator tests and physical-device/store qualification are different claims; see [build evidence](BUILD_STATUS.md) for exact validated revisions.

## Implemented application

- Flutter Home, searchable/sortable list/grid library, Settings, theme/default preferences and onboarding.
- Android hosted ML Kit document scanner; iOS VisionKit; manual camera and photo-import alternatives. Android automatic scanning can require an initial Google component download. iOS hosted capture cannot enforce the page cap before returning; over-limit results do not overwrite the draft.
- File-backed image staging, EXIF normalisation, bounded decoding/thumbnails and a fifty-page document limit.
- Multiple persistent SQLite drafts with a saved-drafts chooser. Native returned-capture receipts are acknowledged only after draft persistence; replay deduplicates page IDs. Android re-emits pending-capture availability when the Dart event listener subscribes.
- Per-page rotation, four-corner crop, preview/reset, Original/Enhanced/Greyscale/B&W, apply-filter-to-all, drag ordering and explicit accessible move controls.
- Remove/undo and in-place manual-camera retake, including at fifty pages. Cancellation retains the original page. A durable camera-replacement intent lets Android lost-image recovery target the original draft/page rather than append a fifty-first page. An otherwise unplaceable recovered image goes into a separate draft, preserving the full original draft.
- A4/Letter/image-fit export, portrait/landscape, margins, quality presets, Unicode-safe names with filesystem byte bounds and optional processed/original image retention.
- Page-at-a-time native PDF/image pipeline: streaming JPEG PDF writer on Android and Core Graphics PDF context on iOS. Progress, cooperative cancellation and independent page-count/render checks.
- Android selected SAF folder containing `PDF Scanner/PDFs` and image subfolders, with an explicitly labelled app-private fallback. iOS Files-exposed app Documents container, labelled PDF Scanner. Share exports independent copies.
- Paged PDF viewer/zoom, share, details, rename and PDF-only/PDF-plus-images deletion.
- Durable export publication journals/receipts, mutation intents and deletion tombstones; startup/retry replay with a visible recovery status. Failed provider rollback and unreadable publication evidence are retained, not silently discarded. iOS Documents rename/delete use file coordination.
- Atomic SQLite document insertion plus corresponding draft deletion. Native files and SQLite remain separate systems: receipts reconcile the cross-system crash window, not a fictitious filesystem/SQL transaction.
- Conservative age-based cleanup of disposable previews and abandoned temporary work, protecting **all** saved-draft sources/thumbnails, capture receipts and unresolved operations. App-private backup exclusions and baseline iOS privacy manifest.
- Optional default-off Firebase diagnostics/analytics, separate build/user gates, lazy Dart initialisation, durable opt-out and failed-opt-in handling. No Firebase project is attached.
- Explicit production-signing guard; CI development signing requires an opt-in environment variable. Custom development icons, complete platform projects, locked dependencies, tests and CI.

## Validation and reproducibility

[GitHub Actions run 42335247077](https://github.com/uttamongithb1/Pdf-scanner-app/actions/runs/42335247077) passed **all five jobs** for application source `4a7ae5f73fb457ac953d3e04cbface22ee22d726`: strict analysis, **27 Flutter tests**, **8 Python tests**, Android debug/optimized development APKs, **5 Android native integration cases**, iOS simulator build with **4 native cases passed/1 Android-only case skipped**, unsigned iOS device release and PDF-writer validation. The [build report](BUILD_STATUS.md) records exact evidence, downloads and memory-sampling limitations. Documentation-only commits do not change that tested application source.

Local execution includes repository checks, eight Python regression tests, source formatting/parsing and the actual Kotlin PDF writer compiled on Java 17/Kotlin 2.1. Independent PyMuPDF checks cover three-/fifty-page output, ordering, page geometry, Unicode metadata, xref offsets and incomplete-output handling. Local source parsing is **not** Flutter type checking.

CI additionally runs Flutter analysis/unit/widget tests; Android native image/PDF/storage integration on API 35; an iPhone-simulator integration run; negative release-signing validation; iOS unsigned release compilation; and whole-app Android emulator PSS/RSS sampling. Integration scenarios include real SQLite rollback and retry, corrupt staging rollback, stale-preview protection, pixel-channel filter checks, rotation dimensions and invalid crops. Android-only intent replay is explicitly skipped on iOS. Each native case has a bounded timeout and the test command fails fast.

The workspace's network restrictions prevent installing a runnable Flutter/Android SDK here; Xcode requires macOS. Native builds execute on GitHub-hosted Linux/Mac runners. [BUILD.md](BUILD.md) explains reproducible commands, development artifacts and toolchain limits.

## Deliberate product/architecture boundaries

- Validated MethodChannels rather than generated Pigeon; `sqflite` versioned tables rather than Drift. Schema version 1 is not a historical migration qualification suite.
- Image-only PDF generation, not OCR/searchable PDFs, arbitrary PDF editing or encrypted-vault storage.
- Enhanced is contrast/brightness, not a shadow-removal model. Android Otsu and iOS Core Image B&W are not claimed perceptually identical; faint-writing/corpus validation remains open.
- iOS Core Graphics controls PDF image encoding; identical quality numbers do not promise the same file sizes as Android.
- iOS canonical storage is the Files-exposed app container, not an arbitrarily selected external tree/bookmark. Android provider capabilities vary.
- English-first interface. Full externalised localisation/Hindi, pseudo-localisation, complete RTL qualification, visual goldens and a full screen-reader audit remain unfinished product/QA work. A large-text/RTL review-layout regression test is not full localisation.
- Cleanup runs conservatively on startup and manually, not an OS-scheduled background retention service. Recoverable files are not disposable cache.
- Emulator memory samples are debug-build measurements, not a true peak or a physical-phone release benchmark. Hosted scanner process memory is outside that report.

## Release-owner and physical-device gates

1. Supply protected Android signing and Apple team/provisioning; approve bundle IDs, branding and store listings. No signed iPhone IPA or store-ready Android artifact is claimed.
2. Execute [DEVICE_TEST_PLAN.md](DEVICE_TEST_PLAN.md): physical camera, offline first-install fallback, SAF/Files provider behaviour, actual process death and low storage.
3. Measure fifty-page release/profile latency and total native memory on supported phones, including hosted scanning; exercise decoder/filter corpora and independent PDF readers.
4. Complete accessibility/layout audit and either accept/document English-first scope or implement the remaining localisation/golden suite before claiming those PRD criteria.
5. If optional monitoring is wanted, attach the owner's Firebase project, configure symbols, audit network/consent behaviour and complete disclosures. Default builds remain unconfigured.
6. Review current Play/App Store SDK requirements, third-party licences, privacy manifest reasons/collected data and OS backup/restore behaviour for the final enabled configuration.

**Do not confuse successful compilation or simulated crash-journal replay with physical-device/store release qualification.**
