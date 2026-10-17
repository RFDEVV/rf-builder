import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  /// Kalau true, splash tidak ditampilkan lagi.
  static bool get skipSplash => _p.getBool('skipSplash') ?? false;
  static set skipSplash(bool v) => _p.setBool('skipSplash', v);

  /// Tema terakhir (untuk warna splash & status bar sebelum web selesai dimuat).
  static bool get lastThemeLight => _p.getBool('lastThemeLight') ?? false;
  static set lastThemeLight(bool v) => _p.setBool('lastThemeLight', v);

  static int get lastBgColor => _p.getInt('lastBgColor') ?? 0xFF07070E;
  static set lastBgColor(int v) => _p.setInt('lastBgColor', v);
}
