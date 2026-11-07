# PDF Scanner 0.1.0 — public development preview

A local-first Android/iOS scanner with multi-page editing, four-corner cropping,
filters, persistent drafts, local PDF/image saving, a document library and recovery.

## Download and install

### Android phone — `pdf-scanner-v0.1.0-preview.1-android.apk`

Download the APK from **Assets** below, open it on Android **8.0 or later**, and
allow installation from your browser/file manager when Android asks. Never bypass
a malware warning. You can verify the download against `SHA256SUMS.txt`.

**This is an optimized, development/debug-signed preview, not a production-signed
Play release.** Future builds may have a different development certificate, so an
update may require uninstalling first. Uninstalling removes app-private drafts
and files: share/save important exports independently before uninstalling.
Do not use this preview as the only copy of important documents.

### iOS — `pdf-scanner-v0.1.0-preview.1-ios-simulator.tar.gz`

**Mac/iOS Simulator ONLY. This is NOT an IPA and cannot be installed on an iPhone
or iPad.** Downloading this asset in Safari on a phone will not install the app.
An installable iPhone release needs Apple signing/provisioning and an appropriate
distribution channel, such as TestFlight or the App Store. None is configured yet.

On a Mac with a compatible Xcode/iOS Simulator installed:

```sh
tar -xzf pdf-scanner-v0.1.0-preview.1-ios-simulator.tar.gz
# Start an iOS simulator in Xcode first, then:
xcrun simctl install booted Runner.app
xcrun simctl launch booted com.lumen.pdfscanner
```

Requires iOS **16.0+**. Simulator/runtime/CPU compatibility still applies. The
simulator cannot qualify physical-camera/VisionKit scanning; use photo import.

## Validation and provenance

The APK and simulator archive come from successful build **42335247077**,
application source `4a7ae5f73fb457ac953d3e04cbface22ee22d726`. The release tag points
to the merged main revision `d76898ec789501380f9e03df1cc755d3f8733cb9`; the publisher
verifies that all app/platform/dependency/test/build-script sources match the
validated build. Publication does not rebuild or modify those binaries.

- Strict Flutter analysis; 27 Flutter tests; 8 original Python regressions.
- Five Android native emulator cases passed.
- Four iPhone-simulator cases passed; one Android-only case skipped.
- Android debug/optimized APK and iOS simulator/unsigned-release compilation.
- Independent PDF generation and fifty-page synthetic-fixture checks.

See `BUILD_PROVENANCE.json` for immutable artifact IDs and original archive digests.
`SHA256SUMS.txt` hashes the actual downloadable release files, not the original
Actions ZIP wrappers. GitHub also includes automatic source-code archives; those
are source code, not installable applications.

## Known limits

- Physical-camera, SAF/Files-provider, accessibility, actual process-kill and
  high-resolution fifty-page release-performance qualification remain open.
- English-first UI; full localisation and visual-golden coverage are unfinished.
- Firebase reporting is unconfigured and off by default. No app-operated document
  uploads, accounts or ads are required.
- App-private data is removed on uninstall. A user-selected storage provider or
  shared copy has its own retention/privacy rules.

This release is deliberately marked **pre-release**, not production-ready.
