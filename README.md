# Surat Desa (APK)

Aplikasi Android untuk membuat surat (Surat Pengajuan Masyarakat & Surat Undangan) dengan UI mirip WhatsApp Business dan nuansa warna Instagram.

## Cara mendapatkan APK tanpa install tools di PC
1. Buat repo GitHub baru, upload semua isi folder ini.
2. Pastikan branch utama bernama `main`.
3. Buka tab **Actions** di repo -> jalankan workflow **Android APK CI** (atau push sekali).
4. Setelah selesai, buka **Actions** → pilih run terbaru → **Artifacts** → download `surat-debug-apk` → di dalamnya ada `app-debug.apk` yang bisa langsung diinstal di HP (aktifkan *Install unknown apps*).

## Fitur
- Dua jenis surat: Pengajuan Masyarakat & Undangan.
- Generate PDF ukuran F4, pratinjau via aplikasi pembuka PDF.
- QR Code otomatis dari `nomor_surat` → `https://srikandi-arsip.netlify.app/?hash=...`.
- Simpan file di folder aplikasi dan bagikan/print dengan *share sheet*.
- UI daftar “mirip chat” ala WhatsApp, topbar gradasi warna gaya Instagram.

## Catatan
- Integrasi Google Drive/Sheets dari script Python belum diaktifkan di sini karena memerlukan konfigurasi OAuth dan verifikasi. Jika ingin diaktifkan, kita bisa tambahkan modul khusus menggunakan Google Sign-In + Google Drive/Sheets API.
