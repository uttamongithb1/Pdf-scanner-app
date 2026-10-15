# Optional post-launch monitoring

The user requested post-launch visibility after the original local-only proposal. This implementation adds **optional Firebase Crashlytics and Firebase Analytics**, with both collection switches off by default. Documents are never intentionally uploaded by app code.

## Two switches, not one

1. **Developer setup/build gate:** Firebase config belongs to your project, and the app starts Firebase only with `--dart-define=FIREBASE_ENABLED=true`.
2. **User choice:** crash diagnostics and usage events are separate, default-off Settings switches. Native auto-collection flags are false before SDK initialisation. App code also gates explicit reports/events by consent.

Without your configuration, the app remains usable; Settings shows monitoring as not connected. No project credentials, project IDs or configuration files have been invented.

## Register your apps

1. Create your own Firebase project in the Firebase console.
2. Register Android and iOS applications using the final package/bundle IDs.
3. Download Android `google-services.json` into `android/app/`. Conditional Gradle integration applies Google Services and Crashlytics only when this file exists.
4. Download `GoogleService-Info.plist` into `ios/Runner/`. Add it to the Runner target's resources using Xcode (copying it into the directory alone is not sufficient).
5. Follow Firebase's current iOS Crashlytics instructions for the run script/build settings and **dSYM upload**. Without matching symbols, native stack traces may be incomplete. Android mapping/symbol uploads also need verification for release/obfuscated builds.
6. Build/run with:

```sh
flutter run --dart-define=FIREBASE_ENABLED=true
```

Enable the desired reporting switch in the app. Test consent before/after restart, opt-out and deletion of unsent reports. Verify delivery on an internal test build. Do not deliberately crash production users to test it.

These config files are ignored by Git. Keep CI/service-account/upload credentials in protected secrets, not app code or chat. Firebase mobile configuration itself is not a replacement for proper project restrictions and security settings.

## Approved app events

- `scan_started`
- `scan_completed`
- `pdf_export_succeeded`
- `pdf_export_failed`
- `share_opened` — this is NOT proof a document was sent.

No event parameters include file names, paths, document titles, images, OCR text or content. Technical reports use sanitised error labels instead of raw platform exceptions. Do not add user IDs or identifiers derived from documents.

Analytics SDKs can use installation identifiers and collect standard technical/event data. Do not market this as absolutely unidentifiable/zero-data analytics. Review Firebase's current collection/retention practices, consent requirements and store disclosures for the actual resolved SDK versions before enabling it.

## Dashboards

- Play Console / App Store Connect: distribution, ratings, platform stability information.
- Firebase Crashlytics: stack traces, affected app versions/devices and issue trends, with user-enabled diagnostics and correct symbol setup.
- Firebase Analytics: consented usage events and funnels.

No custom backend is necessary. Firebase is not configured or receiving data from this repository yet.
