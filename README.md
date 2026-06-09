# WaifuVault V3

WaifuVault adalah galeri anime pribadi berbasis Flutter.

## V2 upgrade

- Import foto dan video
- Salin media ke storage aplikasi agar koleksi lebih aman
- Thumbnail video otomatis dari frame video
- Dynamic color preview untuk foto dan video
- Search berdasarkan judul/kategori
- Counter kategori real-time
- Delete item dari koleksi + hapus salinan file app
- UI dark neon futuristik

## Build APK

Upload isi folder ini ke repo GitHub, lalu buka tab Actions dan jalankan workflow `Build WaifuVault APK`.

APK akan muncul sebagai artifact `WaifuVault-APK`.


## V3 Update
- Adaptive video color: preview video now samples several frames and changes the glow/background color while the video plays.
- Video preview background can switch between sampled frame blurs for a more dynamic feel.
- Version: 1.2.0+3


## V3.1 Hotfix
- Fixed adaptive video colors for old videos imported before V3 by generating missing frame colors when the video preview opens.
- Video thumbnails/frame samples are now saved as unique files so multiple sampled frames do not collapse into one thumbnail.
- Version: 1.2.1+4


## V4.1 Clean UI Hotfix Upgrade
- Dashboard hero premium di Beranda
- Stat card foto/video/favorit
- Media tile lebih rapi dengan title + category overlay
- Bottom navigation lebih neon/glass
- Versi app: 1.3.0+5


## V4.1 Clean UI Hotfix
- Grid kategori/koleksi dibuat 2 kolom agar thumbnail tidak gepeng/kecil.
- Text overlay card dibuat lebih bersih dan tidak ramai.
- Empty state kategori diperbaiki agar tulisan tidak terlalu besar.
- Semua fitur V3.1 adaptive video color tetap ada.
