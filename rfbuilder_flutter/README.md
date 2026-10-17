# RFBuilder App (Flutter)

Aplikasi Android untuk RF Builder: UI & fungsi **sama persis dengan website**
(`https://rfweb2apk.rfdevv.com`) karena memuat UI web aslinya, dibungkus shell native:

| Fitur | Cara kerja |
|---|---|
| Login Google | Native (`google_sign_in`) -> `POST /api/auth/google/android` (endpoint sudah ada di server). Google memblokir login OAuth di dalam WebView, jadi wajib native. |
| Push notif | OneSignal. Server sudah memanggil `sendUserPush()` (mis. "APK Selesai Dibuild!") dengan `include_external_user_ids = id user`; app memanggil `OneSignal.login(userId)` setelah login. |
| Riwayat build di HP | SQLite (`sqflite`). Tiap build sukses disimpan lokal, lalu digabung ke halaman **Histori Build APK** milik web (tampilan tidak berubah, tetap tampil walau offline). |
| Splash custom + skip | Video `assets/splash/splash.mp4` (kalau tidak ada: splash bawaan yang meniru splash web). Tombol **Lewati** + centang **Jangan tampilkan lagi**. |
| Icon custom | Ganti `assets/branding/icon.png` lalu `dart run flutter_launcher_icons`. |
| Unduhan APK/file | Diunduh ke folder app, lalu tombol **Install / Buka / Simpan-Bagikan**. |
| Lain-lain | Upload file/kamera/mikrofon, tombol Back, link eksternal (WA/Telegram) dibuka di app luar, layar error + Coba lagi, status bar mengikuti tema (dark/light/rgb/preset). |

## Setup (sekali)
```bash
cd rfbuilder_flutter
./tool/setup.sh        # flutter create (android) + izin manifest + minSdk 23 + icon + splash native
flutter run
```
Butuh Flutter SDK >= 3.24. Kode ini belum saya compile (SDK tidak ada di lingkunganku);
kalau `flutter pub get` / `flutter run` error, kirim lognya.

## WAJIB: agar Login Google tidak error
Server memakai Web Client ID `83573961859-…apps.googleusercontent.com`. Di Google Cloud Console
(project yang sama dengan client itu) -> APIs & Services -> Credentials -> **Create Credentials -> OAuth client ID -> Android**:
- Package name: `my.id.rfproject.rfbuilder_app` (atau yang kamu ubah di `setup.sh`)
- SHA-1: debug -> `cd android && ./gradlew signingReport`; release -> SHA-1 keystore rilismu
  (+ SHA-1 dari Play App Signing kalau lewat Play Store)

Tanpa client Android ini muncul error kode 10 (`DEVELOPER_ERROR`). Jangan hapus/ubah Web Client ID di `lib/core/config.dart`:
server mengecek `aud` token harus sama dengan itu.

## Push notif
Pakai app OneSignal yang sama dengan `ONESIGNAL_APP_ID` di `.env` server (sudah dipakai app admin).
Pastikan di dashboard OneSignal platform Android sudah dikonfigurasi (kredensial FCM). Atur ID di `lib/core/config.dart`.

## Ganti splash / icon
- Splash video: taruh `assets/splash/splash.mp4` (H.264, disarankan <10 MB) lalu rebuild.
- Icon: ganti `assets/branding/icon.png` (1024x1024) -> `dart run flutter_launcher_icons`.

## Rilis
```bash
flutter build apk --release        # atau: flutter build appbundle --release
```
Tanda tangani dengan keystore milikmu (jangan commit keystore).

## Keamanan (penting, dari zip server)
- `webServer.js` baris ~119-120 punya **GOOGLE_CLIENT_SECRET default tertulis di kode**; `.env.example` berisi `ONESIGNAL_REST_API_KEY` yang terlihat asli. Pindahkan ke `.env`, hapus dari kode, dan **regenerate** keduanya.

## Rencana: native bertahap
Struktur ini memungkinkan halaman diganti widget Flutter satu per satu (Fase 2+), mis. Histori, Profil, Download.
Sampai halaman itu selesai, WebView memastikan tampilan tetap 100% sama dengan web.
