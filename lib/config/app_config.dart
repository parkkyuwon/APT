import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'env.dart';

/// 앱 전역 설정 싱글톤. main() 에서 init() 필수 호출.
class AppConfig {
  AppConfig._();

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static late SharedPreferences _prefs;

  static const String appName = 'APT EV 충전';
  static const Duration apiTimeout = Duration(seconds: 15);

  static String get apiBaseUrl => Env.apiBaseUrl;
  static String get googleWebClientId => Env.googleWebClientId;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs => _prefs;
  static FlutterSecureStorage get secureStorage => _secure;
}
