import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'config.dart';

/// Push notif via OneSignal. Server sudah mengirim lewat sendUserPush()
/// dengan include_external_user_ids = id user, jadi cukup OneSignal.login(userId).
class PushService {
  static bool _ready = false;
  static String? _currentUser;

  static Future<void> init() async {
    try {
      OneSignal.initialize(AppConfig.oneSignalAppId);
      _ready = true;
      OneSignal.Notifications.requestPermission(true);
    } catch (_) {
      _ready = false; // jangan sampai app crash kalau push gagal
    }
  }

  static Future<void> setUser(String userId) async {
    if (!_ready || _currentUser == userId) return;
    try {
      if (userId.isEmpty) {
        await OneSignal.logout();
      } else {
        await OneSignal.login(userId);
      }
      _currentUser = userId;
    } catch (_) {}
  }
}
