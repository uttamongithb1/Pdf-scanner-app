# Physical-device acceptance plan

Run release/profile builds on a low-memory Android device, a mainstream Google-services Android device, an Android device without eligible scanner services, and the oldest supported iPhone. Simulators alone cannot qualify capture or folder-provider behaviour.

## Core workflow

- [ ] Fresh install → onboarding → automatic capture → 3 pages → review → save.
- [ ] First install offline → automatic capture unavailable → manual camera or photo import → crop → save.
- [ ] Select local Android folder → `PDF Scanner/PDFs` and `Images/Processed/<id>` visible in Files; decline → clearly private fallback.
- [ ] iOS Files → app container → PDFs/images; verify uninstall/backup explanation.
- [ ] Import JPEG/PNG/HEIC where OS supports it, rotated EXIF and large images; no full-resolution decode spike before sampling.
- [ ] Crop asymmetric printed corner labels; rotate all 4 directions; preview/output corner positions and orientation agree.
- [ ] Apply each filter per page and all pages; reset returns unedited app-available source.
- [ ] Move/remove/undo/retake; saved PDF and JPEG sequence match the final order.
- [ ] A4/Letter/Image-fit, portrait/landscape and margins; no stretched/clipped text or duplicated margins.
- [ ] Save processed images/originals on/off combinations; confirm actual bytes and requested folders.
- [ ] Open every page, zoom, rename, collision, share, cancel sharing, delete PDF-only/PDF+images.

## Persistence and failures

- [ ] Relaunch draft; edit order/filter/crop persists. Explicit discard affects no final documents.
- [ ] Kill at import/capture return, render, image publish, PDF write, PDF publish and before/after SQLite commit.
- [ ] Completed receipt reindexes once; no duplicate PDF on retry. Incomplete outputs roll back or are explicitly reported.
- [ ] Fill storage mid-export; keep source draft and readable error.
- [ ] Revoke Android URI grant/remove SD card, then reconnect/reselect; never report a false success or silently switch destinations.
- [ ] Cancel during every export phase; reconcile any already-published files. Keep draft.
- [ ] Modify/delete PDFs externally; preview reports unavailable instead of crashing.
- [ ] Providers that cannot atomically rename/move; verify collision handling and rollback failure behaviour.
- [ ] Cache cleanup retains active-draft sources and edited thumbnails.
- [ ] Incoming call/background expiration does not leave a falsely complete library row.

## Accessibility, privacy and performance

- [ ] TalkBack and VoiceOver through capture alternatives, reorder, corner nudges, export and share.
- [ ] 200% text; smallest supported screen, landscape, keyboard and tablet split view; essential controls remain reachable.
- [ ] Light/dark, contrast on actual images, reduced motion and optional haptics.
- [ ] Network inspection with reporting off, Firebase absent, Firebase present and consent switches on/off.
- [ ] Do not send filenames/URIs/content as crash messages or analytics parameters.
- [ ] Verify Firebase receipt and symbolication using a dedicated internal build, not a production crash.
- [ ] Ten-/fifty-page RSS and latency, including native scanner, transforms, encoders and PDF parser. Record exact device/OS/build.
- [ ] Validate exported PDFs with multiple independent readers, actual fonts/text stamps and image qualities; tiny/large and faint-pencil pages included.

Store the report outside source control if it contains real document content. Prefer synthetic fixtures for all repeatable tests.
