/// Semua nilai yang perlu kamu sesuaikan ada di file ini.
class AppConfig {
  /// Domain server RF Builder (dikunci).
  static const String baseUrl = 'https://rfweb2apk.rfdevv.com';

  /// Web Client ID Google (sama dengan GOOGLE_CLIENT_ID di server).
  /// Server memverifikasi `aud` token == nilai ini, jadi WAJIB sama.
  static const String googleWebClientId =
      '83573961859-s30l470pai2ksm7of42ss0ufr2q7pjjk.apps.googleusercontent.com';

  /// OneSignal App ID (pakai app OneSignal yang sama dengan ONESIGNAL_APP_ID di server).
  static const String oneSignalAppId = '51d5ec41-105b-4537-a6ce-b861d4edae8b';

  /// Video splash. Ganti file ini dengan videomu (mp4, H.264).
  /// Kalau file tidak ada / gagal diputar, dipakai splash bawaan (sama dengan web).
  static const String splashVideoAsset = 'assets/splash/splash.mp4';

  /// Batas maksimal splash tampil (detik) sebelum otomatis lanjut.
  static const int splashMaxSeconds = 15;

  static const String userAgentSuffix = 'RFBuilderApp/1.0';
}
