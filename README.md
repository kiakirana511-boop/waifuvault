# WaifuVault

WaifuVault adalah starter APK Flutter untuk galeri anime pribadi dengan UI dark neon, dukungan gambar/video, kategori, favorit, preview media, dan adaptive accent color untuk gambar.

## Fitur V1

- Beranda/gallery grid
- Import foto dari galeri HP
- Import video dari galeri HP
- Kategori: Hoshino, Blue Archive, Video JJ, Wallpaper, Lainnya
- Favorit
- Preview foto dengan warna UI mengikuti warna dominan gambar
- Preview video dengan player sederhana
- Add media screen
- Profile/settings screen
- Mode privat demo PIN `1234`

## Build APK via GitHub Actions

1. Upload semua file project ini ke repo GitHub.
2. Buka tab **Actions**.
3. Jalankan workflow **Build WaifuVault APK**.
4. Download artifact **WaifuVault-APK**.
5. Ekstrak zip artifact, install `app-release.apk`.

## Catatan

V1 menyimpan path file dari galeri HP. Kalau file asli dihapus/dipindah, preview bisa rusak. V2 bisa dibuat supaya file dicopy ke storage app sendiri.
