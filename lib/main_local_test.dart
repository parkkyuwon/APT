import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'config/env.dart';
import 'core/api_client.dart';
import 'core/deep_link.dart';
import 'core/session_info_cache.dart';
import 'core/state_cache.dart';
import 'local_test/local_api_adapter.dart';
import 'main.dart' show AptEvApp;
import 'services/services.dart';

/// Separate debug entrypoint; normal main.dart never imports local fixtures.
Future<void> main() async {
  if (!kDebugMode ||
      !const bool.fromEnvironment('LOCAL_MEMBER_TEST') ||
      Env.apiBaseUrl != 'https://local-test.invalid') {
    throw StateError('Local member tests require an isolated debug build');
  }
  WidgetsFlutterBinding.ensureInitialized();
  DeepLink.start();
  await AppConfig.init();
  final api = await ApiClient.init();
  api.dio.httpClientAdapter = LocalApiAdapter(
    admin: const bool.fromEnvironment('LOCAL_ADMIN_TEST'),
  );
  await api.clearSession();
  await SessionInfoCache.clear();
  await StateCache.clear();
  runApp(Banner(
    message: 'LOCAL TEST',
    location: BannerLocation.topEnd,
    textDirection: TextDirection.ltr,
    layoutDirection: TextDirection.ltr,
    child: AptEvApp(services: ApiServices.from(api)),
  ));
}
