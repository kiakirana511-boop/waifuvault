# WaifuVault V8.10.1 Ultra Light Route

V8.10.1 keeps the V8.10 smooth tab idea, but makes profile/menu route transitions much lighter for 60Hz/low-end Android phones.

Update files:
- pubspec.yaml
- README.md
- lib/main.dart
- .github/workflows/build-apk.yml

## Changes
- Profile -> Storage Mode transition reduced to ultra-light fade.
- Back transition reduced so it does not feel like dropped FPS.
- Tab animation stays PageView-based but a little faster.
- Clean home, dual DCM Waifu paths, SD/internal scan, and advanced gallery remain intact.
