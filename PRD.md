# PDF Scanner — Product Requirements Document

**Version:** 1.0 · **Date:** 15 October 2026 · **Status:** Draft for review

**Platforms:** Android and iOS phones; adaptive tablet layouts where supported.

**Working product name:** PDF Scanner. Final name, store availability and application identifiers require confirmation.

**Companion:** [Lumen Design System](DESIGN_SYSTEM.md)

**Implementation:** [Current source and validation status](docs/IMPLEMENTATION.md). This PRD remains the proposed acceptance baseline; see that status for implemented scope, monitoring additions and unverified release gates.

> This is a proposed engineering specification, not a claim that an application has been implemented, benchmarked or approved. Personas are design hypotheses. Performance numbers are acceptance targets pending device measurements. No customer research, stakeholder sign-off or historical review is implied.

---

## Contents

1. Product definition
2. Goals and scope
3. User journeys and navigation
4. Technology recommendation
5. Architecture and processing pipeline
6. Local storage and platform constraints
7. Functional requirements
8. Data model and persistence
9. Export specification
10. Performance and reliability
11. Permissions, security and privacy
12. Accessibility and localisation
13. Failure and recovery behaviour
14. Quality strategy and release gates
15. Delivery roadmap and effort
16. Risks and decisions
17. Traceability and references

---

## 1. Product definition

### 1.1 User need

Turn photographs of paper documents into clean, correctly ordered, shareable PDFs without requiring an account or uploading document content. Save the PDFs **and page images locally in a folder named after the app**, with an understandable path the user can find again.

The core experience is:

**Scan or import → adjust pages → choose export settings → save locally → open or share.**

### 1.2 Proposed users

| User hypothesis | Primary need | Design implication |
|---|---|---|
| Student | Scan notes and assignments | Multi-page capture, reorder, readable B&W |
| Shop owner or independent worker | Send invoices and receipts | Fast save, naming, system share sheet |
| Person submitting an application | Scan ID and certificates | Crop control, quality/file-size trade-off |
| Household record keeper | Keep bills and medical papers | Local ownership, predictable folders, privacy |

Validate these hypotheses with a small user study before expanding the feature set. Do not treat them as market evidence.

### 1.3 Product principles

- **Document quality first:** legible text and correct page boundaries matter more than visual novelty.
- **Local ownership:** files remain usable outside the app; the database is not the only way to recover PDFs.
- **No false success:** “Saved” means the file is durably written, structurally verified and reachable at the displayed destination.
- **Non-destructive review:** preserve the unedited source until export and the selected retention policy are complete.
- **Explicit platform differences:** Android shared folders and iOS Files exposure are different implementations, not identical filesystem access.
- **Bounded resource use:** no unbounded decoded-image arrays and no base64 transport for images.

## 2. Goals and scope

### 2.1 MVP goals

1. Capture multiple paper pages using the camera or import images from the photo picker.
2. Correct perspective, crop, rotate and enhance images before PDF export.
3. Generate a multi-page image PDF with reliable ordering and configurable compression.
4. Create an app-named local folder containing `PDFs/` and `Images/`.
5. Provide an in-app library with open, rename, delete and share operations.
6. Complete the core workflow without accounts, advertisements or document uploads.
7. Handle permission denial, low storage, interruption and process death without corrupting existing documents.

### 2.2 MVP boundaries

| Included | Deferred |
|---|---|
| Native document capture, manual-camera fallback | OCR and searchable PDF text layers |
| JPEG/PNG and OS-decodable HEIC image import | Import/edit arbitrary existing PDFs |
| Multi-page review, reorder, rotate, crop | PDF merge, annotation, signatures and forms |
| Original, Enhanced, Greyscale and B&W filters | Automatic field extraction and translation |
| A4, Letter and image-fit PDF pages | PDF/A archival compliance and advanced print workflows |
| Three export quality presets | Password-protected PDFs and encrypted vaults |
| Local PDF and processed-image storage | Cloud sync, backup services and user accounts |
| File operations, settings, basic storage management | Monetisation, ads and subscriptions |
| Light/dark modes and accessibility | Web/desktop application |

**Initial supported limits:** 50 pages per document and 50 images per import, subject to qualification on low-memory devices. The supported document limit is separate from an individual native scanner's limit. A prototype must establish both; do not advertise a 200-page workflow without proving its memory and recovery behaviour.

### 2.3 Success criteria

These are proposed launch targets, not measured outcomes:

- At least 90% of recruited usability-test participants complete a three-page scan and find its saved PDF without help.
- At least 95% of supported test documents produce legible pages without clipped required content after automatic crop or an available manual correction.
- Every successful export passes the integrity and destination checks in §9.
- Zero known critical data-loss, privacy or accessibility-blocker defects at release.
- Core workflow passes airplane-mode tests after scanner provisioning; fresh-install offline behaviour has a tested fallback (§4.3).
- Performance budgets in §10 pass on named physical reference devices.

Retention and store-rating targets should be set only after a pilot establishes a baseline. No analytics service is required for MVP.

## 3. User journeys and navigation

### 3.1 Information architecture

```text
Application shell
├── Home: Scan document, Import images, Recent documents
├── Files: search, sort, list/grid, document actions
└── Settings: defaults, appearance, storage, privacy, about

Full-screen workflow
Capture / Import → Page review → Single-page editor
                         └── Export options → Progress → Saved document
```

Use one persistent scan shortcut in the shell. Hide it during capture, editing and export. Avoid duplicating filled primary actions on Home; the design system specifies the hierarchy.

### 3.2 Capture journey

1. User selects **Scan document**.
2. Explain camera access where the app's own camera requires it; request permission only at this point. A hosted scanner may manage access itself.
3. Present the native scanner where available, otherwise the manual capture/corner-adjustment flow.
4. Save returned page assets to an app-private session directory; review shows thumbnails, not full-resolution decoded images.
5. User adds pages, removes mistakes, changes order, rotates, crops or filters.
6. Export sheet shows name, page format, quality, image-retention policy and exact destination.
7. Export runs with progress and cancellation; the UI remains responsive.
8. Success shows **Open**, **Share**, and **Done**, plus the saved location and actual size.

### 3.3 Import journey

Use the system photo picker. Validate each selected source, normalise orientation and colour, and downsample during decode. Preserve the picker-provided order; if the platform does not supply a deterministic selection order, explicitly let the user review and reorder. Report skipped unsupported/corrupt images individually.

### 3.4 First-run storage journey

- Android: explain shared-folder access, open the system folder picker, and ask the user to choose or create `PDF Scanner` within a local directory. Create the subfolders after access is granted. Offer private local storage if declined, with an explicit visibility warning.
- iOS: create subfolders within the app's Documents directory, expose it in Files and show **On My iPhone → PDF Scanner** (or the equivalent iPad path).
- Explain that removing the app can remove sandbox-owned files. Offer system export to keep an independent copy.

### 3.5 Draft recovery

Persist an active session after every completed capture/import/edit. After process death, offer **Resume scan** or **Discard draft**. Drafts and final exports must be distinguishable in the index. Never silently discard a recoverable session as part of cache cleanup.

## 4. Technology recommendation

### 4.1 Recommended stack

**Flutter for shared UI and application logic; Kotlin and Swift for camera, image processing and platform storage.** This balances cross-platform delivery with native processing performance. If absolute platform-specific performance and unlimited staffing are the only criteria, two fully native apps are also a valid choice; no benchmark has established a universal winner here.

| Layer | Recommendation | Rationale / constraint |
|---|---|---|
| App UI | Flutter stable, Dart; pin exact SDK in implementation | Shared components, predictable rendering, adaptive UI |
| State/dependencies | Riverpod | Testable state and explicit lifecycles |
| Navigation | go_router | Workflow routes and platform back navigation |
| Native Android | Kotlin, structured concurrency | Camera, URI I/O, background-safe processing |
| Native iOS | Swift, structured concurrency | VisionKit, Core Image, coordinated file access |
| Capture | ML Kit Document Scanner on supported Android; VisionKit document camera on supported iOS | First-party capture and automatic correction; capability-dependent |
| Manual fallback | CameraX / AVFoundation plus manual quadrilateral correction | No Google-services dependency for basic scanning |
| Image processing | Core Image on iOS; evaluated OpenCV/platform operations on Android | Keep raster work off the UI thread; test perceptual parity |
| PDF generation | Evaluate native Android `PdfDocument` and iOS Core Graphics incremental page writing | File-backed output and page-at-a-time raster lifecycle |
| PDF preview | Android `PdfRenderer`; iOS PDFKit | Use supported OS parsers rather than a custom PDF parser |
| Metadata | SQLite; Drift for typed migrations if team accepts code generation | Durable drafts, ordering, reconciliation and migration tests |
| Preferences | Shared preferences equivalent; secure storage only for future secrets | No passwords or tokens needed for MVP |
| Boundary | Pigeon typed platform APIs; file paths/opaque asset IDs, not whole batches of bytes | Compile-time schema checks and lower copying costs |
| Quality automation | Flutter unit/widget/integration tests; JUnit and XCTest | Test both shared and native logic |
| Build/release | GitHub Actions, platform signing, TestFlight / Play testing tracks | Android toolchain and macOS/Xcode jobs required |

Do not put heavy image processing on the Flutter UI isolate. Native code is not automatically fast: profiling, decode sampling and explicit resource disposal remain necessary.

### 4.2 Alternatives and trade-offs

| Option | Strength | Trade-off for this product |
|---|---|---|
| SwiftUI + Jetpack Compose | Maximum direct platform control | Two presentation implementations and duplicated QA |
| React Native + native modules | Viable with an experienced TypeScript team | Must qualify camera/PDF module compatibility and bridge/lifecycle behaviour; performance depends on implementation |
| Kotlin Multiplatform | Shared Kotlin domain logic with native or shared UI | Good alternative for Kotlin-heavy teams; validate iOS integration/tooling cost |
| Flutter + native modules | Shared UI while native pipeline owns performance-critical work | Dart plus two native languages and bridge tests are still required |
| WebView/PWA | Easy web distribution | Not preferred for sustained camera processing and native local-storage workflows |

The recommendation is based on maintainability and integration needs, not unsupported claims that other frameworks cannot generate PDFs.

### 4.3 Capture capability constraints

- Hosted document scanners own their own camera UI. The app **cannot promise custom live quadrilateral callbacks, exact stability timers, shutter animations, flash controls or branded overlays** through APIs that do not expose them.
- Android ML Kit document-scanning components can require Google Play services and a first-use component/model download. “Works offline” must distinguish initial provisioning from subsequent use. Device RAM and service availability also affect eligibility.
- Do not assume omitting the app's network permission prevents Google Play services from downloading its own components.
- iOS must check `VNDocumentCameraViewController.isSupported`; simulators are not adequate camera qualification devices.
- The manual fallback is a release requirement: capture an image, let the user adjust four corners, correct perspective, then review. Automatic edge detection in this fallback is optional for MVP.
- Exact API capabilities, minimum OS versions, SDK artefact coordinates, SDK terms and availability must be verified against official documentation during the first engineering spike. No dependency version in this plan is a substitute for that verification.

### 4.4 Dependency and licence policy

Pin SDK/tool versions and commit the application lockfile when implementation begins. Review transitive dependencies, native binary size, supported ABIs, security advisories, licence obligations and SDK data practices.

Prefer OS frameworks and permissively licensed libraries where suitable. Commercial SDKs may be evaluated with an explicit budget and legal review; they are not assumed free. ML Kit is a Google SDK subject to its applicable terms, not simply an Apache-licensed open-source library.

**PDF gate:** prove memory bounds, page geometry, PDF-reader compatibility, metadata and cancellation before selecting an engine. A Dart `pdf` implementation is an alternative only if profiling shows its object/image/output buffering meets the supported limits. Iterating pages in a loop does not make a buffered writer streaming.

## 5. Architecture and processing pipeline

### 5.1 Layers

```text
Flutter presentation: Home / Review / Export / Files / Settings
              ↓ application commands and state
Shared domain: Document, Page, EditSpec, ExportJob, failure types
              ↓ repository interfaces
Infrastructure: SQLite, session store, platform adapters
              ↓ typed APIs: asset IDs, edit instructions, destination handles
Native workers: capture / decode / transform / JPEG / PDF / file provider
              ↓
Private staging + user-selected local folder / iOS Documents
```

Domain code should not depend on widgets, platform channels or filesystem APIs. Shared geometry and edits use serialisable value objects. Feature modules communicate through application services, not each other's UI state.

### 5.2 Page lifecycle

1. Capture/import provides a source URI or file.
2. Copy into a bounded, app-private staging asset; persist its ID and source metadata.
3. Read dimensions without full decode; downsample as needed during decode.
4. Apply EXIF orientation and convert to the chosen colour space.
5. Keep a private unedited normalised source and generate a small thumbnail.
6. Store crop quadrilateral, rotation and filter as instructions; regenerate previews asynchronously.
7. At export, load one page, apply edits, encode PDF/image output, release raster resources and continue.
8. Validate final outputs, publish them, and reconcile the metadata transaction.

Original camera sensor/RAW data is not promised. “Original” means the unedited image available to the app, which may already have been corrected by the hosted scanner.

### 5.3 Coordinate contract

Store the four crop corners normalised to `[0,1]` in the EXIF-normalised source orientation. Validate finite values, convexity and minimum area. Apply perspective correction first, then quarter-turn rotation, then filter and resampling. A rectangle alone cannot describe perspective correction.

The editor may display a transformed preview, but it must invert that display transform before persisting corners. Unit tests must cover all EXIF orientations and rotations so preview and export use the same mapping.

### 5.4 Worker and cancellation contract

- One active export per session; use idempotent job IDs and prevent conflicting rename/delete actions.
- Native worker concurrency starts at one raster job; increase only if memory measurements permit it.
- Expose phase/page-count progress through events: preparing, rendering, writing, verifying, publishing, complete.
- User-driven scanning has no arbitrary 30-second timeout. Machine operations have bounded timeouts with cancellation, not an indefinitely pending bridge result.
- Cancel cooperatively between stages and pages. Close streams and remove unpublished outputs, retaining the draft.
- When backgrounded, persist progress. iOS background execution is limited; expiration cancels or suspends safely. Do not promise uninterrupted long exports in the background.

### 5.5 Proposed platform API surface

| API | Key contract |
|---|---|
| `capabilities()` | Scanner availability, provisioning state if observable, OS/fallback capability |
| `capture(sessionId, remainingPages)` | Returns asset descriptors; user cancellation is not an error dialog |
| `importImages(sessionId, limit)` | Stable order, per-image failures and opaque asset handles |
| `renderPreview(assetId, edit, maxEdge)` | Small cached preview, stale requests cancellable |
| `startExport(jobId, manifest, destination)` | File-backed work; emits progress and completion |
| `cancelExport(jobId)` | Idempotent cancellation request |
| `storageAccess()` / `chooseFolder()` | Access status, persistent permission handle, readable location label |
| `openDocument()` / `shareDocument()` | Temporary read access, no unrestricted filesystem exposure |
| `reconcileLibrary()` | Missing/modified files without destructive assumptions |

All APIs return typed failure codes. Validate manifest size, page count, IDs, path containment and destination permission on the native side as well as the shared side.

## 6. Local storage and platform constraints

### 6.1 Logical user-visible structure

```text
PDF Scanner/
├── PDFs/
│   └── Invoice_2026-10-15_143205.pdf
└── Images/
    ├── Processed/
    │   └── <document-id>/page-001.jpg
    └── Originals/                  # only when Keep originals is enabled
        └── <document-id>/page-001.jpg
```

The processed images are saved by default because local storage of **both PDFs and images** is part of the requested product. Disabling their retention is an explicit user preference, not a silent implementation optimisation. Explain the additional space usage.

Private implementation data lives elsewhere:

```text
App-private support storage/
├── index.sqlite
├── drafts/<session-id>/sources + edit manifest
├── jobs/<job-id>/temporary outputs + recovery journal
├── thumbnails/                    # evictable cache
└── trash/                         # optional recovery data, quota-limited
```

Do not expose temporary scans in a shared folder or treat a recoverable draft as an evictable thumbnail.

### 6.2 Android

**Preferred shared-library strategy: Storage Access Framework (SAF).**

1. Ask the user to select/create a local `PDF Scanner` folder through `ACTION_OPEN_DOCUMENT_TREE`.
2. Persist the granted URI permission with `takePersistableUriPermission` where granted.
3. Create `PDFs` and `Images` using document-provider APIs. Store document URIs, not guessed absolute paths.
4. Recheck access on launch/resume and before export. A grant may be revoked and a removable volume may disappear.
5. Display the provider/location. The local-only product should guide users to internal storage or local removable media; cloud providers can appear in the picker and must not be described as on-device storage.

**Important:** scoped storage does not permit arbitrary path-based writes to `Documents/PDF Scanner`. `MediaStore` is not a universal replacement for a SAF document-tree grant; accepted collections/directories and file types have restrictions. Do not base the general PDF-folder design on unrestricted `MediaStore.Files` insertion into Documents.

If the user declines shared access, allow private local storage with the same logical folder tree and label it **App storage — use Export to save elsewhere**. App-specific external directories are not reliably browsable by ordinary file managers on recent Android versions and can be deleted at uninstall.

Do not request `MANAGE_EXTERNAL_STORAGE`. Use SAF for shared PDFs and user-chosen folders, and the photo picker for imports. Qualify older Android photo-picker/backport behaviour; use `ACTION_OPEN_DOCUMENT` as a permission-minimal fallback.

### 6.3 iOS / iPadOS

Use the app's Documents directory as the app-named Files container:

```text
Files → On My iPhone → PDF Scanner → PDFs / Images
```

Set and test `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`. Do not add a second nested `PDF Scanner` directory unless product testing shows a reason; the Files container already uses the display name. Keep private drafts, thumbnails and the database under Application Support/Caches, not Documents.

Use coordinated access for files that Files or external editors may modify. Offer the system document picker/export sheet for saving an independent copy elsewhere. Arbitrary writes to a global device root are not supported.

Sandbox-owned files can disappear when the app is deleted. Do not imply app lock protects files opened directly through Files. OS backup and user-selected iCloud destinations are separate from app-operated cloud sync; privacy copy must explain that distinction.

### 6.4 Single library authority

The selected destination contains the canonical exported PDFs. Avoid maintaining an invisible private PDF plus a public duplicate without a documented sync model. The private database indexes destination handles, but external files are authoritative for existence and bytes.

On refresh, mark missing files as unavailable and offer relink/remove; do not silently delete page assets. Import discovery of externally added PDFs is deferred unless the engine supports metadata/thumbnail extraction. A change of library location must be explicit: keep old documents linked or perform a verified migration; never silently move or delete them.

### 6.5 Retention and cleanup

| Asset | Default policy |
|---|---|
| Final PDFs | Retain until explicit deletion |
| Final processed images | Retain by default; user may opt out or delete image copies after export |
| Original images | Retain only if Keep originals is enabled; default off after verified export to reduce duplicates |
| Active/recoverable drafts | Retain until resume/discard; offer stale-draft review after 7 days |
| Failed export remnants | Remove after recovery classification; never remove a possibly committed PDF blindly |
| Thumbnails | LRU cache, proposed 32 MiB disk budget |
| Disposable temporary files | Cleanup on launch and opportunistically after 72 hours, excluding active jobs/drafts |
| Deleted documents | Undo when feasible; disclose when provider deletion is permanent |

Background cleanup scheduling on both OS families is opportunistic, not an exact timer. Manual **Clean up** must be available. Require confirmation before deleting originals or processed image copies, listing the consequences. Never auto-disable a retention preference based on page count.

## 7. Functional requirements

**Priority:** M = MVP release requirement; L = later. Requirement IDs are stable for implementation and QA traceability.

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| CAP-01 | M | Capture paper through a supported scanner or manual fallback | Supported-device path works; unavailable/provisioning-failed scanner has a usable fallback |
| CAP-02 | M | Request permissions at intent | No permission wall at launch; denial offers import or Settings where appropriate |
| CAP-03 | M | Capture multiple pages | Session count is visible in review; adding pages preserves existing order/edits and enforces the qualified limit |
| CAP-04 | M | Retake an individual page | Replacement affects only the selected page and can be cancelled without losing it |
| IMP-01 | M | Import multiple images | JPEG/PNG and supported HEIC decode; orientation and picker order are correct; failures identify affected items |
| IMP-02 | M | Bound import resource use | Oversized inputs are sampled during decode; malformed/unsupported files cannot crash the workflow |
| EDT-01 | M | Reorder and remove pages | PDF and saved-image sequence match review order; removal offers undo and accessible move actions |
| EDT-02 | M | Rotate by 90° and correct perspective | Four-corner edit produces the same crop in preview and output; reset restores the available source |
| EDT-03 | M | Apply Original/Enhanced/Greyscale/B&W per page or all pages | Preview identifies selected filter; output is consistent; switching filters does not repeatedly recompress source |
| EDT-04 | M | Provide zoom for inspection | Pinch and accessible zoom controls; no full-resolution bitmap for every grid tile |
| EXP-01 | M | Export a multi-page PDF | Non-empty PDF opens in independent readers, page count and order match, required content is not clipped |
| EXP-02 | M | Configure page format, quality and margins | Geometry matches §9; preview explains image-fit versus standard sheets |
| EXP-03 | M | Name files safely | Unicode names supported, traversal/illegal characters rejected or sanitised with feedback; collision never overwrites silently |
| EXP-04 | M | Show progress and support cancellation | Distinct render/write/verify phases; cancel retains draft and removes unpublished output |
| EXP-05 | M | Handle publication transactionally | Full success only after mandatory PDF/image outputs and index commit; partial failures offer retry without duplication |
| STO-01 | M | Create an app-named local library | Exact paths and permission behaviour follow §6 on both OS families |
| STO-02 | M | Save page images with PDFs | `Images/Processed/<id>/page-NNN.jpg` matches the PDF page order; retention opt-out is explicit |
| STO-03 | M | Explain retention and storage use | Settings show PDF/image/cache usage, destination, clean-up actions and uninstall implications |
| STO-04 | M | Support revoked/missing storage | No false success, draft retained, reselect/relink offered |
| LIB-01 | M | Show library | Name, thumbnail/placeholder, page count, size, modified date, search and sort; list/grid selection persists |
| LIB-02 | M | Open and share | Preview and system share work; recipients get temporary read access and correct `application/pdf` MIME type |
| LIB-03 | M | Rename and delete | File and index stay consistent; filename collisions checked; delete scope explicitly says PDF only or PDF plus saved images |
| LIB-04 | M | Reconcile external changes | Missing/changed files do not crash preview; refresh/resume rechecks destination access and metadata |
| CFG-01 | M | Persist defaults | Page format, quality, filter, image retention and theme survive restart and are actually applied to new sessions |
| CFG-02 | M | Use system/light/dark theme | All app-owned screens respond; hosted scanner exceptions are documented |
| RCV-01 | M | Recover interrupted sessions | Relaunch resumes or discards the last recoverable draft without damaging final documents |
| PRV-01 | M | Avoid content uploads | No app-operated upload in capture/export; inspect dependencies and network traffic; disclose provisioning and OS backup exceptions |
| ACC-01 | M | Accessible core workflow | Screen-reader labels/order, scalable text, non-colour status and alternative reorder/crop actions pass §12 tests |
| LTR-01 | L | OCR/searchable PDF | Separate quality, language, model download and file-format requirements before implementation |
| LTR-02 | L | Password protection / vault | Separate standards-compliant PDF encryption and threat-model review; app lock alone is not file encryption |

## 8. Data model and persistence

### 8.1 Entities

| Entity | Important fields |
|---|---|
| `Document` | UUID, title, destination handle/URI, filename, page count, size, created/modified timestamps, export profile, state |
| `Page` | UUID, session/document ID, position, source asset ID, edit specification, pixel dimensions, optional processed asset ID |
| `Asset` | UUID, storage scope, relative path or opaque URI, MIME type, dimensions, size, optional SHA-256, retention status |
| `ScanSession` | UUID, created/updated timestamps, ordered page IDs, capture/import source, draft state |
| `ExportJob` | UUID, session ID, destination, requested profile, manifest version, phase, completed pages, published handles, last failure |
| `StorageLocation` | UUID, platform kind, persistent grant/bookmark when applicable, display label, last access result |
| `Preferences` | Defaults, theme, retention, onboarding completion; versioned schema |

Use UUIDs for identity; store UTC timestamps for records and format them locally in the UI. UUIDs and time-based IDs are not protection against clock changes. Use explicit page positions and job state, not timestamp ordering, for correctness.

### 8.2 Constraints and migrations

- Unique `(session_id, position)` within a persisted ordering transaction; use a safe two-phase reorder update where necessary.
- Foreign keys enabled; delete related metadata intentionally, not by accidental cross-document cascade.
- Distinguish `draft`, `exporting`, `ready`, `partial`, `unavailable` and `deleting` states.
- SQLite transactions cannot atomically commit SAF/filesystem writes. Use the export recovery journal to reconcile the two resources.
- All migrations are versioned and tested from each previously released schema. No destructive migration of the user's files.
- Do not store absolute iOS sandbox paths; container locations can change. Resolve relative paths at runtime.
- No speculative OCR table is required in MVP; future OCR can be an additive schema migration keyed by page ID.

## 9. Export specification

### 9.1 Page geometry

PDF user units are points: `1 pt = 1/72 inch`, `1 mm = 72/25.4 pt`.

| Format | Dimensions | Points, portrait |
|---|---|---|
| A4 | 210 × 297 mm | 595.28 × 841.89 |
| Letter | 8.5 × 11 in | 612 × 792 |
| Image-fit | Preserve cropped image aspect ratio | Derive from oriented image pixels and chosen nominal DPI |

Standard-sheet orientation is user-selectable; default portrait. Fit with aspect preservation inside the printable area, never stretch. White letterbox space is acceptable; clipping content is not. Margins: None (0 mm), Small (5 mm), Large (10 mm). Landscape swaps sheet dimensions.

Apply margins **once**, in PDF layout, rather than baking them into the JPEG and applying them again to the page.

### 9.2 Initial quality presets

| Preset | Nominal raster target | JPEG quality starting point | Intended use |
|---|---|---|---|
| Small | 150 DPI equivalent | 70 | Submission portals and text with normal print |
| Balanced (default) | 200 DPI equivalent | 85 | General documents |
| High | 300 DPI equivalent | 92 | Small print, detailed stamps |

Quality numbers are encoder parameters, not comparable guarantees across libraries. Never upscale to imply recovered detail. Set a qualified decode/render ceiling (initially 4096 px long edge) and warn or adapt when a format would exceed it. Label size as **Estimated** until final bytes exist; calibrate from representative pages rather than claiming an exact universal KB/page bound.

Original preserves source colours; normalise to sRGB for predictable rendering. Greyscale removes chroma. B&W should perform actual binarisation with readable text, not merely increase RGB contrast. Enhanced uses tested white-point/contrast/shadow treatment and must preserve faint writing and stamps. Test a common reference corpus on both platforms.

### 9.3 Naming

Default: `Scan_yyyy-MM-dd_HHmmss.pdf` using local display time. Sanitise separators, traversal names, control characters, reserved names and invalid suffixes. Normalise Unicode to NFC and enforce a safe filename budget including extension and collision suffix.

A user-supplied title replaces the default stem; do not append a second timestamp to a title that already contains one. If a name exists, add `_2`, `_3`, etc., using exclusive creation or provider-confirmed naming to handle races. Never overwrite without an explicit user choice.

Saved page names are zero-padded and remain associated through immutable document IDs, not PDF display titles. Renaming a PDF does not require rewriting all image paths.

### 9.4 Publish and recovery protocol

1. Persist job intent, requested filename, page sequence and destination.
2. Preflight permission and estimated space. When free space is unknown, continue cautiously; preflight cannot eliminate write-time failures.
3. Render one page at a time to private temporary outputs and feed the qualified PDF writer. Retain only bounded raster data.
4. Close and flush the staged PDF. Reopen it with an independent platform parser; validate nonzero pages, expected count, page geometry and renderability. Test ordering using labelled fixture pages.
5. Save required processed images and, if selected, originals. Journal each published handle.
6. Publish the PDF using a temporary name and rename where the destination provider supports it. **SAF providers do not universally guarantee atomic rename/move**; retain private staging and journal incomplete publication for retry/cleanup.
7. Commit the database ready-state and size/handles. Only now display full success.
8. Remove disposable staging after the recovery/retention policy is satisfied.

On partial image publication, do not claim both PDFs and images were fully saved. Offer retry or an explicit **Keep PDF only** choice. On DB failure after a PDF was published, recover/index the existing file rather than writing a duplicate. On user cancellation during publication, reconcile committed files before declaring cancellation complete.

### 9.5 Format claims

MVP produces image-based PDFs, not searchable text. Declare the actual PDF version generated by the selected engine after validation; do not promise PDF 1.7, AES-256, PDF/A or a specific compression filter without verifying implementation support. Populate only necessary metadata (title, creation timestamp, app/version); do not leak source photo GPS/EXIF into exported files.

## 10. Performance and reliability

### 10.1 Proposed qualification budgets

Measure release/profile builds on physical devices; debug performance is not a release benchmark. Choose named devices during the prototype (at least one 3 GB Android phone, one mainstream Android phone and the oldest supported iPhone).

| Metric | Proposed target | Measurement boundary |
|---|---|---|
| Cold launch to interactive Home | p95 ≤ 2 seconds | Process launch to usable app-owned UI; storage reconciliation is deferred |
| Page-editor interaction | 60 Hz on 60 Hz hardware; p95 frame time ≤ 16.7 ms | Zoom, scroll and editing with cached thumbnails |
| One-page filter preview | p95 ≤ 500 ms | Normalised source available, bounded preview size |
| Ten-page Balanced export | p95 ≤ 10 seconds on mainstream devices | Local sources ready to verified PDF/image save in a local destination; exclude user dialogs |
| Low-end ten-page export | p95 ≤ 20 seconds | Same boundary, qualified low-end device |
| Peak process RSS | Initial target ≤ 300 MiB at 50-page Balanced export | Native + Flutter memory, not Dart heap alone |
| Draft recovery | No loss of completed staged pages | Force-stop/kill between every durable transition |
| Release reliability | ≥ 99.5% crash-free sessions in an instrumented, consenting pilot | If telemetry is absent, use lab/user reports and state that production rate is unknown |

These are engineering budgets to revise openly if prototype evidence disagrees. They are not promises of OS scanner FPS or cloud-provider write latency, which the app cannot control.

### 10.2 Memory invariants

- Full-resolution assets live on disk, not in a list of bridge byte arrays.
- Decode using sampling/subsampling before allocation; scaling after full decode is too late.
- Start with one active raster worker. At 4096 × 2896 RGBA, one image alone is about 45 MiB; transformations can temporarily require additional buffers.
- Release native buffers explicitly; use autorelease pools around iOS page work and bounded Flutter image caches.
- Test decoder + transform + encoder + PDF writer + verification together. A file-backed API can still retain internal objects and must be profiled.
- PDF compressed-object bookkeeping may grow with pages; the requirement is bounded **large raster memory**, not an unjustified claim of mathematically constant total process memory.
- Cache 256 px thumbnails with a bounded LRU; cancel obsolete preview work.

### 10.3 Reliability invariants

Existing PDFs are never modified by a failed new export. A successful job is idempotent by job ID. Externally removed/revoked files produce unavailable states, not crashes. Every active stream/resource closes on success, failure or cancellation. No background execution guarantee exceeds the OS lifecycle contract.

Battery, thermal behaviour, package size and long-document timing must be measured in the device qualification report. Do not invent validated limits before that report exists.

## 11. Permissions, security and privacy

### 11.1 Permissions

| Capability | Android | iOS |
|---|---|---|
| App-owned camera | Contextual camera permission | `NSCameraUsageDescription` and contextual authorisation |
| Hosted scanner | Follow verified SDK permission contract | VisionKit and camera authorisation behaviour verified on device |
| Photo import | System picker or SAF fallback; avoid broad photo-library access | PHPicker; no full-library authorisation needed for basic picker use |
| Shared PDF/image folder | Persistent SAF tree grant | Documents/Files exposure or explicit document export |
| Sharing | Temporary content-URI read grant, narrow FileProvider scope if used | System share sheet, properly anchored on iPad |

Do not request microphone, contacts, location or all-files access. Do not request photo-add permission to save a PDF into Documents; saving PDFs to a photo library is not this product's workflow.

### 11.2 Data protection

- App-owned processing and PDF generation operate locally; no content analytics, advertising SDKs or automatic upload.
- Treat native SDK downloads, platform services, user-initiated shares and OS backup as distinct data paths and disclose them accurately.
- Do not log titles, source URIs, page content, GPS data or shared filenames. Diagnostics use opaque IDs and scrubbed error codes.
- Validate file type by decoder as well as extension; cap dimensions, page counts and input size, with failure before dangerous allocations where possible.
- Defend against path traversal and malicious bridge inputs. Use opaque asset IDs, not arbitrary caller-provided paths.
- Shared PDFs/images are user-accessible by design. The app is **not an encrypted vault**, and an app lock would not protect independently exposed copies.
- Thumbnail caches stay private. Do not promise secure forensic erasure on flash storage; deletion follows OS/provider semantics and cannot remove recipient copies or all backups.
- Device encryption/sandboxing is platform-provided protection, not evidence of custom per-file encryption.

### 11.3 Backup and store disclosures

Document iOS and Android backup inclusion/exclusion separately. Exclude disposable cache/drafts where appropriate; explain whether canonical files may be included in OS backup. Do not claim “nothing ever leaves your phone” when the OS/user may back up or share it.

Review applicable SDK privacy manifests, required-reason APIs, App Store privacy disclosures and Play Data Safety for the actual dependency graph. Legal/privacy claims require review; this document does not establish automatic GDPR/CCPA compliance.

## 12. Accessibility and localisation

- App-owned controls have a 48 logical-pixel minimum touch area, meaningful labels and logical focus order.
- Normal text contrast ≥ 4.5:1; large text and meaningful non-text controls ≥ 3:1.
- Support at least 200% text scaling without inaccessible content; controls and sheets grow/scroll rather than clip.
- Support TalkBack/VoiceOver through save and share. Announce capture completion and progress milestones without constantly interrupting speech.
- Provide move-left/right/up/down or **Move to position** actions for reordering; dragging is not the only option.
- Provide labelled corner selection/nudge controls and reset for manual crop. Evaluate hosted scanner accessibility separately and keep an import/manual alternative where needed.
- Honour reduced motion and use haptics only as optional supplementary feedback.
- Externalise all strings from the start. English first; Hindi is the proposed second locale. Add RTL layout tests before shipping Arabic/Urdu rather than claiming untranslated locale support.
- Use plural/localised date/size formatting; do not concatenate English fragments. Filenames retain a filesystem-safe pattern regardless of locale.

## 13. Failure and recovery behaviour

| Case | Expected behaviour |
|---|---|
| Camera denied or unavailable | Explain the condition, offer Settings when actionable, offer image import |
| Scanner not provisioned/no Google services | Explain availability without claiming document upload; launch manual fallback |
| Low contrast, glare, blur or incomplete crop | Hint to improve capture; allow inspection, retake and manual correction; do not promise automatic quality detection unless implemented |
| Corrupt/unsupported image | Skip with item-specific explanation; preserve other pages |
| Import exceeds qualified limits | Explain the limit before processing; allow a smaller selection |
| Storage fills mid-export | Close streams, retain draft, remove/reconcile partial outputs, offer storage management and retry |
| Library access revoked/volume removed | Retain private draft, explain reconnect/reselect; do not silently switch destinations |
| Same filename appears concurrently | Use provider-confirmed collision resolution, never blind overwrite |
| App backgrounds or OS kills it | Persist job state; resume/retry from last verified stage without duplicate final files |
| User cancels | No frightening error; retain draft and confirm status after publication reconciliation |
| File externally renamed/deleted | Mark unavailable and allow refresh/relink/remove index entry |
| Rename/delete provider failure | Preserve or restore prior index state; report partial state honestly |
| Share sheet cancelled | Remain on saved document; no error toast |
| No receiving app or corrupt PDF | Offer another open/export action; keep the saved file |
| App uninstalled | Warn beforehand through storage help that private/iOS sandbox files may be removed; independent shared copies follow provider rules |

Errors use **what happened + a next step**. Debug codes may appear in an optional copied diagnostic, never as the only user explanation.

## 14. Quality strategy and release gates

### 14.1 Test layers

| Layer | Required coverage |
|---|---|
| Domain unit tests | Naming, collision budgets, geometry, coordinate transforms, page ordering, state transitions and error mapping |
| Repository/migration tests | Draft persistence, transactional reorder, schema upgrades, index reconciliation, export idempotency |
| Native tests | Decode sampling, EXIF, HEIC eligibility, perspective/filter output, PDF write/read, permission and URI handling |
| Widget/golden tests | Light/dark, loading/empty/error, large text, compact/tablet, RTL fixtures |
| Integration | Capture/import → edit → save both outputs → find in Files → open/share |
| Fault injection | Process kill, permission revocation, provider disconnect, storage full, DB failure and cancellation at each export phase |
| Performance | Release/profile RSS, frame timing, export latency and thermal behaviour on physical devices |
| Privacy/security | Network inspection fresh-install and provisioned; dependency audit; filename/path traversal; scrubbed logs |

Use synthetic/public-domain fixtures with clear rights. Do not commit private IDs, medical records, huge datasets or real credentials. Maintain a versioned benchmark manifest with lighting, paper, script, angle and source labels; separate evaluation images from tuning examples.

For each fixture, verify clipped content, corner correction, text readability and filter artifacts. Automatic detection metrics are scored per capture backend/device/model version where output is observable; do not claim an opaque Play services model runs reproducibly in a headless unit test.

### 14.2 Essential end-to-end scenarios

1. First install → storage consent → three-page scan → reorder → save PDF and images → open from system Files.
2. First install without network → native scanner unavailable → manual capture → successful local save.
3. Import rotated JPEG/PNG/supported HEIC → crop/filter → correct preview and PDF.
4. Decline camera and shared folder → use import/private destination → clear visibility/uninstall explanation.
5. Export at supported maximum → cancel → draft intact and no falsely complete output.
6. Force-stop during write, publish and DB commit → recovery without duplicates or damaged existing files.
7. Rename/delete/share → correct destination bytes and library state; external deletion handled gracefully.
8. TalkBack/VoiceOver and 200% text → complete the workflow, including accessible reorder.

### 14.3 Release checklist

- [ ] All M requirements linked to passing tests and reviewed UI states.
- [ ] No P0/P1 data-loss, security or core-workflow defects.
- [ ] Local folder visibility and uninstall implications verified on both platforms.
- [ ] Native SDK terms, permission flows, provisioning and offline fallback verified.
- [ ] Exported fixtures open in Android/iOS native viewers, Acrobat and a browser PDF viewer.
- [ ] Geometry, page counts/order, saved images and cancellation tested independently.
- [ ] Memory and latency budgets qualified at the advertised limits.
- [ ] Accessibility review complete; hosted scanner limitations documented.
- [ ] Store target-SDK/Xcode/privacy requirements checked at submission time, not copied from an old plan.
- [ ] Signing secrets held in CI/store tooling, never the repository.
- [ ] Support/privacy copy and recovery instructions match actual behaviour.

CI should enforce formatting, static analysis, tests and applicable native builds; macOS is required for iOS compilation. Device-based checks may be nightly/pre-release. CI workflows are planned deliverables, not existing infrastructure.

## 15. Delivery roadmap and effort

### 15.1 Phases

| Phase | Indicative duration | Exit evidence |
|---|---|---|
| Technical qualification | 1–2 weeks | Capture/fallback, SAF/Documents, PDF memory and permission prototypes on real devices |
| Foundations | 1–2 weeks | Shared shell, design tokens, repository/migrations, durable drafts |
| Capture and editing | 2–3 weeks | Both capture paths, import, crop/rotate/filter/reorder, accessibility alternatives |
| Export and library | 2–3 weeks | Verified PDF/image publication, recovery journal, file operations, settings |
| Hardening and beta | 2–3 weeks | Performance, failure injection, accessibility, privacy and device qualification |
| Store preparation | 1–2 weeks, partly overlapping | Listings, disclosures, signed builds, test-track feedback |

A first production-quality MVP is provisionally **10–15 calendar weeks** with experienced cross-platform/native support and overlapping work. This is not a committed delivery date. A solo implementation takes longer, especially if it includes learning native APIs.

### 15.2 Staffing and cost model

Suggested core team: one experienced Flutter/mobile lead, one cross-platform engineer, part-time Android/iOS specialists, QA and design support. A smaller team may combine roles but must retain native-platform expertise.

Estimate cost only after the qualification phase: **person-weeks × agreed loaded weekly rate + devices + store accounts + CI/macOS/device testing + contingency**. No location-specific salary assumption or funding budget is approved here. Allow contingency for provider behaviour, fallback camera implementation and store review.

The core application needs no backend. That does **not** make delivery/operation cost zero: developer accounts, CI, hardware, testing, maintenance, support and security updates remain.

## 16. Risks and decisions

### 16.1 Risk register

| Risk | Impact | Mitigation / proposed owner |
|---|---|---|
| Native scanner needs first-use download or is unavailable | Offline promise breaks | Manual fallback, provisioning tests — mobile lead |
| Custom camera UX assumed over hosted UI | Unimplementable design | Separate hosted/custom components, capability inventory — design + native lead |
| PDF engine buffers all images | OOM at long-document limits | Early physical-device profiling; file-backed writer; conservative ceiling — native lead |
| SAF grant/provider behaviour varies | Invisible, partial or orphaned exports | Durable URI access, journal/reconcile, local-provider tests — Android owner |
| iOS Files/backup/uninstall misunderstood | User loses expected files or privacy trust | Clear destination and backup copy, independent export — product owner |
| Filters erase faint writing | Unusable documents | Corpus comparisons, reversible edits, Original option — imaging owner |
| Large scope before core loop is reliable | Delay and data-loss defects | MVP boundary; change review for OCR/cloud/vault — product owner |
| Metadata and files disagree after interruption | Duplicates or missing library rows | Explicit states, idempotency and fault injection — data owner |

Owners are roles to assign, not people who have already approved this document.

### 16.2 Decisions awaiting confirmation

| Decision | Proposed default | When to settle |
|---|---|---|
| Product/store name | PDF Scanner (working) | Before identifiers and store branding |
| Supported OS floor | Android 8/API 26; iOS 16, subject to audience/device study | Qualification; may change with required APIs/SDK support |
| Play target SDK/Xcode versions | Current store-required versions at submission | Release planning and each release |
| Page ceiling | 50, after memory qualification | Prototype |
| Android canonical location | Local SAF folder, explicit private fallback | Prototype and usability test |
| Processed images | Retain by default | Product review; requirement is to store images as well as PDFs |
| Original-image retention | Off after verified export unless enabled | Product/privacy review |
| Native versus Dart PDF engine | File-backed native engine first to evaluate | Memory/compatibility gate |
| Launch languages | English; Hindi next | Product/content review |
| Monetisation | None for MVP | Separate business decision |
| OS backup of canonical documents | Disclose and test platform defaults; determine any exclusions | Privacy/data-loss review |

## 17. Traceability and references

### 17.1 Requirement-to-design mapping

| Requirement group | Design system section | Validation |
|---|---|---|
| CAP / IMP | §5 Capture and import | Physical-device capture/import scenarios |
| EDT | §5 Review and editor | Transform tests, fixture comparisons, accessible reorder |
| EXP | §5 Export | Geometry/reader tests, progress/cancellation fault injection |
| STO | §5 Storage settings | Android SAF / iOS Files verification |
| LIB | §5 Library | External file changes and share tests |
| ACC / CFG | §6–7 accessibility/adaptation | Screen readers, scaling, theme and localisation tests |

### 17.2 Authoritative implementation references

These are reference entry points to verify during implementation, not a claim they have been freshly audited for this draft:

- [Flutter platform integration](https://docs.flutter.dev/platform-integration/platform-channels)
- [Pigeon typed platform APIs](https://pub.dev/packages/pigeon)
- [ML Kit document scanner](https://developers.google.com/ml-kit/vision/doc-scanner)
- [VisionKit document camera](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller)
- [Android shared-document storage / SAF](https://developer.android.com/training/data-storage/shared/documents-files)
- [Android photo picker](https://developer.android.com/training/data-storage/shared/photopicker)
- [Android PDF writer](https://developer.android.com/reference/android/graphics/pdf/PdfDocument)
- [Apple Core Graphics PDF context](https://developer.apple.com/documentation/coregraphics/cgcontext)
- [Apple Files document-sharing configuration](https://developer.apple.com/documentation/bundleresources/information-property-list/uifilesharingenabled)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — design baseline supplemented by native-platform accessibility guidance.

---

**Next approval gate:** confirm naming, storage defaults, supported devices and MVP scope; then run the qualification prototypes before committing to versions, schedule or advertised performance.
