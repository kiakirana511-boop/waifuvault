# WaifuVault V8.5.2 - Dual Folder Auto Scan

Upgrade dari V8.3:

- Bisa scan dua folder utama sekaligus:

```text
/storage/emulated/0/DCM Waifu/
/storage/4394-15F8/DCM Waifu/
```

- Kalau foto/video dipindah manual ke salah satu folder itu, WaifuVault bisa memasukkannya ke koleksi tanpa import picker.
- App melakukan auto-scan ringan saat dibuka.
- Di Storage Mode ada tombol **Scan Semua DCM Waifu** buat scan ulang manual.
- File internal tetap di folder publik internal.
- File SD tetap di SD, tidak dicopy ke internal.
- Delete tetap mengikuti jalur:
  - item internal -> hapus file internal DCM Waifu
  - item SD -> hapus file SD DCM Waifu
- Fitur V8 lain tetap ada: sort, multi-select, batch delete, edit judul/kategori, adaptive video color, icon/splash.

Upload/timpa file biasa:

```text
pubspec.yaml
README.md
lib/main.dart
.github/workflows/build-apk.yml
```

Assets branding dari V5 boleh dibiarkan.


V8.5.2 Clean Home Menu build fix.
