import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'config.dart';

class GoogleAuthResult {
  final bool ok;
  final String? error;
  final String? token;
  final Map<String, dynamic>? user;
  GoogleAuthResult.ok(this.token, this.user) : ok = true, error = null;
  GoogleAuthResult.fail(this.error) : ok = false, token = null, user = null;
}

/// Login Google native -> kirim idToken ke POST /api/auth/google/android
/// (endpoint itu sudah ada di server dan memverifikasi token ke Google).
class GoogleAuth {
  static final _gsi = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: AppConfig.googleWebClientId,
  );
  static final _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    validateStatus: (_) => true,
  ));

  static Future<GoogleAuthResult> signIn() async {
    try {
      await _gsi.signOut(); // paksa pilih akun tiap kali
      final acc = await _gsi.signIn();
      if (acc == null) return GoogleAuthResult.fail('Login Google dibatalkan');
      final auth = await acc.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return GoogleAuthResult.fail(
            'Google tidak mengirim ID token. Cek serverClientId & SHA-1 di Google Cloud.');
      }
      final res = await _dio.post('/api/auth/google/android', data: {'idToken': idToken});
      final data = res.data;
      if (data is Map && data['success'] == true && data['token'] != null) {
        return GoogleAuthResult.ok(
            data['token'].toString(), Map<String, dynamic>.from(data['user'] ?? {}));
      }
      final msg = (data is Map ? data['error'] : null) ?? 'Login gagal (HTTP ${res.statusCode})';
      return GoogleAuthResult.fail(msg.toString());
    } on DioException catch (e) {
      return GoogleAuthResult.fail('Koneksi gagal: ${e.message}');
    } catch (e) {
      final s = e.toString();
      if (s.contains('sign_in_failed') || s.contains('10:')) {
        return GoogleAuthResult.fail(
            'Google Sign-In ditolak (kode 10): SHA-1 aplikasi belum didaftarkan di Google Cloud. Lihat README.');
      }
      return GoogleAuthResult.fail('Login Google error: $s');
    }
  }

  static Future<void> signOut() async {
    try { await _gsi.signOut(); } catch (_) {}
  }
}
