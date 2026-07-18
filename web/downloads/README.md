# Android release download

Cloudflare Pages limits each uploaded file to 25 MB. Build split APKs with
`flutter build apk --release --split-per-abi`, then copy the ARM64 release into
this directory as `rental-facility-manager.apk` before creating the deployment
package. Keep the universal APK separately for manual distribution. The APK
itself is ignored by Git.
