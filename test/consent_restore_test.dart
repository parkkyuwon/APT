import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/session_info_cache.dart';
import 'package:apt_ev_charging/models/session.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> resident({bool consent = true}) => {
        'email': 'resident@example.invalid',
        'name': 'Resident',
        'role': 'user',
        'status': 'pending',
        'approved': false,
        'profileComplete': false,
        'needsConsent': consent,
      };
  test('nested consent from auth restore survives session cache roundtrip', () {
    final bootstrap = AuthBootstrap.fromJson({'session': resident()});
    expect(bootstrap.needsConsent, isTrue);
    final restored = SessionInfo.fromJson(bootstrap.session!.toJson());
    expect(resolveAuthStage(restored), AuthStage.needsConsent);
  });
  test('explicit top-level consent flag overrides outdated nested value', () {
    final bootstrap =
        AuthBootstrap.fromJson({'needsConsent': false, 'session': resident()});
    expect(bootstrap.needsConsent, isFalse);
    expect(resolveAuthStage(SessionInfo.fromJson(bootstrap.session!.toJson())),
        AuthStage.needsProfileSetup);
    final required = AuthBootstrap.fromJson(
        {'needsConsent': true, 'session': resident(consent: false)});
    expect(resolveAuthStage(SessionInfo.fromJson(required.session!.toJson())),
        AuthStage.needsConsent);
  });
  test(
      'cached consent remains required before and after failed session refresh',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final client = await ApiClient.init();
    await client.clearSession();
    final adapter = ControlledApi();
    client.dio.httpClientAdapter = adapter;
    addTearDown(adapter.close);
    await SessionInfoCache.save(SessionInfo.fromJson(resident()));
    final auth = AuthProvider(ApiServices.from(client));
    addTearDown(auth.dispose);
    final refresh = auth.bootstrap();
    final request = await adapter.next();
    expect(auth.stage, AuthStage.needsConsent);
    request.reply(
        status: 403,
        body: {'ok': false, 'error': 'Session refresh unavailable'});
    await refresh;
    expect(auth.stage, AuthStage.needsConsent);
    await SessionInfoCache.clear();
  });
}
