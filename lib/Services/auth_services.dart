import 'package:url_launcher/url_launcher.dart';
import 'package:HPGM/api/farmer_api.dart';
import 'package:HPGM/Services/cache_service.dart';
import '../Services/token_storage.dart';

/// Session helpers used across the app. Network calls go through [FarmerApi].
class AuthService {
  // LOGOUT METHOD
  // Revokes the token on the server and wipes the local session and cache.
  static Future<bool> logout() async {
    await FarmerApi.instance.logout();
    await CacheService.clearCache();
    return true;
  }

  // GET TOKEN
  static Future<String> getToken() async => await TokenStorage.getToken() ?? '';

  // GET USER DATA
  static Future<Map<String, dynamic>?> getUserData() =>
      TokenStorage.getStoredProfile();

  // CHECK IF LOGGED IN (token stored and not expired)
  static Future<bool> isLoggedIn() => TokenStorage.hasValidSession();

  // LAUNCH SUPPORT URL
  static Future<void> launchSupportUrl() async {
    final Uri url = Uri.parse('http://wa.me/+256755088321');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
}
