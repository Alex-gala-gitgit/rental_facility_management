# Android update release process

The first update-enabled build is `0.1.1+2`. Install it manually once over the
existing APK. Builds after that can read the Cloudflare update manifest and
prompt the user when a higher `versionCode` is available.

## Publish a future update

1. Increase the version in `pubspec.yaml`, for example `0.1.2+3`.
2. Update `web/updates/version.json` with the same version name and code.
3. Build the APK with `flutter build apk --release`.
4. Copy `build/app/outputs/flutter-apk/app-release.apk` to
   `web/downloads/rental-facility-manager.apk`.
5. Build the web app with `flutter build web --release`.
6. Deploy the contents of `build/web` to Cloudflare Pages.

The update is accepted only when the Android application ID and signing key
match the installed app and the new version code is higher.

## Production signing migration

The current transitional APK uses the same debug signing key as the APK already
installed on the test phone. This keeps the first update install-compatible.
Before distributing broadly, create a private release keystore, change the
temporary `com.example.rental_facility_management` application ID, and perform
one controlled uninstall/reinstall. Keep the final keystore backed up securely;
all later releases must use that same key.
