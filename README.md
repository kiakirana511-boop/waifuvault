# WaifuVault V7.4.1 Fixed SD Import

WaifuVault V7.4.1 skips V6 private mode and focuses on fixed SD import plus UI polish.

## V7 Upgrade

- App title on Home is centered.
- Dashboard badge updated to V7 Storage Mode.
- Storage Mode page added in Profile.
- Internal app storage info and stats.
- Backup JSON export.
- Scan missing media files.
- Clean broken/missing media entries.
- V5 icon and splash remain.
- V3.1 adaptive video color remains.
- V4.1 clean premium UI remains.

## Upload / Replace

Upload all files/folders to the same paths in GitHub:

```text
pubspec.yaml
README.md
lib/main.dart
.github/workflows/build-apk.yml
assets/branding/...
```

Version: 1.6.2+10


## V7.2 Hotfix
- Tombol kanan atas preview foto/video sekarang aktif.
- Menu titik tiga berisi favorit, path file, refresh warna video, dan hapus.
- SD Card Mode bisa ditekan untuk simpan path SD Card.
- Version: 1.6.2+10.


## V7.2 SD Scan Import
- SD Card Path sekarang bisa dipakai buat scan folder.
- Foto/video yang ditaruh manual di folder SD bisa diimport ke koleksi.
- Media tetap dicopy ke internal app storage supaya aman di Android.
- Duplikat dari source path yang sama akan dilewati.


## V7.4.1 Fixed SD Import

- SD Card path is fixed to `/storage/4394-15F8/DCM Waifu/`.
- Removed the need to type/select SD path from the main Storage Mode flow.
- Storage Mode card directly scans and imports media from the fixed folder.
- Keeps copy-to-internal behavior for safe playback and thumbnails.
- Version: 1.6.4+11.


## V7.4.1 SD Permission Fix
- Adds Android storage/all-files permissions in the generated manifest.
- Requests storage access before scanning fixed SD Card folder.
- Keeps fixed path import: /storage/4394-15F8/DCM Waifu/.
- Adds extra supported image extensions and clearer scan messages.
