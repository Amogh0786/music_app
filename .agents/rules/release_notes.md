# Release Documentation Rule

Whenever a new version of the app is compiled (`flutter build apk --release`) or a release is created:
1. Always bump the version and build number in `pubspec.yaml` (e.g. `1.1.0+4`).
2. Provide the user with the exact GitHub Release details ready to copy-paste:
   - **Tag**: e.g. `v1.1.0`
   - **Release Title**: A clear, compelling title summarizing the update.
   - **Release Notes / Changelog**: A polished markdown changelog highlighting new features, UI enhancements, fixes, and APK installation instructions.
   - **APK Path**: Direct path to the generated `app-release.apk` for uploading to the GitHub Release.
