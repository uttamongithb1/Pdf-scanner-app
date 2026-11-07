# Third-party notices / provenance

- Android/iOS shell templates: Flutter 3.35.7, BSD-3-Clause. Licence in `FLUTTER_TEMPLATE_LICENSE`.
- Gradle wrapper: Gradle 8.11.1, retrieved from the Gradle repository. Licence in `GRADLE_LICENSE`.
- App launcher icon: generated specifically for this implementation using geometric shapes; not the Flutter template logo. Valid launch PNGs are derived from that icon.
- Cupertino icon font: `cupertino_icons` 1.0.8, matching Flutter 3.35.7's template baseline. The pinned entry/checksum came from the official Flutter workspace lock and was subsequently verified and re-emitted by application CI resolution.
- Dart and native dependencies are declared in `pubspec.yaml`, the Android Gradle project and CocoaPods integration. Audit the resolved lockfiles and native SDK terms before release; no claim is made that every SDK is open source.
- ML Kit document scanner coordinate/version was checked against Google's official `googlesamples/mlkit/android/documentscanner` example. It may require Google services and initial component downloads.
- Firebase is optional/configuration-dependent; its service terms, privacy disclosures and SDK behaviours require review before enablement.
- Tree-sitter grammar packages and the Dart WASM formatter are development checks, not mobile runtime assets.
- Pillow/PyMuPDF and the temporary JVM/Kotlin installation used for PDF verification are test tools, not bundled app SDKs. In particular, PyMuPDF's AGPL/commercial licensing must be considered if reused for other purposes.

No real customer document, signing credential, Firebase project configuration or monitoring upload token is checked in.
