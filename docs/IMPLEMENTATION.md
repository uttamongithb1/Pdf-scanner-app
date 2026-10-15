# Implementation status — 0.1.0

This status is deliberately separate from the proposed PRD. Implemented source is not equivalent to a physical-device-qualified feature.

## Source implemented

- Flutter application shell: Home, searchable/sortable list/grid library, Settings, onboarding explanation.
- Native document capture: Android ML Kit (`16.0.0-beta1`, checked against Google's sample dependency); iOS VisionKit, with camera/image-picker fallback offered from the capture menu. iOS's hosted UI cannot enforce a custom page cap while capturing; over-limit results are rejected with the existing draft retained.
- File-backed import with decode sampling, EXIF normalisation, processed-source re-encoding and bounded thumbnails.
- Draft persistence in SQLite, ordered pages, resume/discard and Android image-picker lost-result retrieval.
- Per-page editing: rotation, four-corner perspective correction, preview, reset, Original/Enhanced/Greyscale/B&W.
- Accessible corner selection/nudges, explicit page move commands, delete with draft undo, manual retake, add pages.
- Export options: A4, Letter, image-fit, orientation, margins, raster-quality presets, editable collision-safe names, image retention.
- Native PDF writing: Android file-streaming JPEG-only PDF writer; iOS Core Graphics PDF context.
- Native export progress, cooperative cancellation, independent page-count/render validation, PDF + selected image copies.
- Android SAF-selected app-named folder and app-specific private fallback; iOS Documents container exposed in Files.
- Private staging, published-file recovery journal, commit receipts and idempotency by session ID. SQLite receipt recovery after interrupted index commits.
- In-app paged PDF rendering, zoom, system sharing, rename/delete/details.
- Theme/default/retention preferences; basic private/library usage and cache cleanup.
- Optional Firebase integration with build-level configuration gate plus default-off user reporting choices.
- Platform project files, domain/channel/widget tests, native PDF smoke test and CI definitions.

## Tests actually executed in this workspace

- `python3 scripts/check_repository.py`: passed.
- Tree-sitter parsing of all app/test Dart, Kotlin and Swift source: passed at the time of the final check.
- Dart source formatting with the `dart_style` WASM formatter: applied.
- **Actual Kotlin JPEG PDF writer compiled and executed on Java 17/Kotlin 2.1.0.** Independent PyMuPDF parsing/rendering verified 3-page order, A4/landscape/image-fit geometry, Unicode title metadata, xref offsets, 50-page writer output and incomplete-output handling.

## Not executed here

Flutter dependency resolution, Flutter static/type analysis, Flutter unit/widget tests, Android app compilation, Xcode compilation, platform integration tests, camera/SAF/Files tests and physical-device performance tests. The workspace initially had none of the mobile toolchains, and its outbound host policy prevents downloading the normal Flutter/Android SDK artefacts. Syntax parsing is not type checking. A JRE/Kotlin compiler was obtained from allowed package registries solely for the independent PDF writer test.

## Deliberate implementation differences from the proposal

- Uses an explicit validated MethodChannel contract rather than generated Pigeon APIs for this first slice. A Pigeon migration remains desirable as the bridge grows.
- Uses `sqflite` with versioned SQLite tables rather than Drift code generation. Records/manifests are serialised JSON; schema version 1 is an initial baseline, not a historical migration suite.
- Android uses a narrow JPEG-only PDF writer instead of retaining Android `PdfDocument` pages. It supports this app's image-PDF output only, not arbitrary PDF editing. The actual writer has an independent smoke test.
- Enhanced is a basic contrast/brightness treatment, not a claimed adaptive shadow-removal model. B&W uses Otsu on Android and Core Image threshold on iOS; perceptual cross-platform parity and faint-writing qualification remain open.
- Quality controls choose raster decode ceilings; encoded JPEG quality is applied to saved processed images and Android PDF JPEG streams. iOS Core Graphics controls its own PDF image encoding, so identical quality numbers do not guarantee equivalent PDF sizes.
- Sharing and Files exposure are implemented; a canonical externally selected iOS document-tree library is not.
- Source strings are currently English, not extracted ARB translations. Other languages/full RTL qualification are not claimed.
- Explicit move actions implement ordering; drag-and-drop ordering is not yet implemented.
- Cache cleanup is manual. Scheduled background cleanup and full crash-safe transactional rename/delete are not complete.

## Release-blocking follow-up

1. Resolve packages, commit the resulting lockfiles, compile both native apps, run Flutter analyzer/tests and address any toolchain/API findings.
2. Execute [DEVICE_TEST_PLAN.md](DEVICE_TEST_PLAN.md), including first-install offline fallback, low storage, provider disconnect and process death.
3. Qualify 50-page limits and total native-process memory. Image raster work is page-at-a-time; iOS PDF internals and OS scanner memory are not proven constant-memory.
4. Coordinate iOS Documents writes with external editors; qualify SAF providers, partial provider writes and rename/collision semantics. Add recoverable delete/rename transactions and retry/cleanup UI for provider rollback failures.
5. Improve recovery when the OS kills hosted Android document capture itself (the separate image-picker fallback already has lost-result handling). Verify interrupted iOS capture behaviour.
6. Add durable save-before-publication cleanup classification, stale-draft review, orphan temporary-file cleanup and limited storage retention. Do not delete recoverable sources as ordinary cache.
7. Add page-drag controls, full localisation/pseudo-localisation, screen-reader audit, goldens and full large-text/small-device layout qualification.
8. Extend decoder fuzz/error tests and B&W/Enhanced filter corpus checks. Shared PDF/image files are not encrypted vault content.
9. Configure Firebase, consent/disclosures and symbol uploads if monitoring is enabled. Current builds have no developer Firebase project attached.
10. Replace provisional branding/icons and development signing; check current store SDK requirements, SDK licences, privacy manifests and OS backup behaviour.

**Do not publish this development build as a production release without these checks.**
