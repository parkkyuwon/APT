/// 빌드 시점에 --dart-define 으로 주입되는 환경 설정.
///
/// 예:
/// flutter run \
///   --dart-define=API_BASE_URL=https://apt-ev-charging.vercel.app \
///   --dart-define=GOOGLE_CLIENT_ID=838650325157-...
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://apt-ev-charging.vercel.app',
  );

  /// 웹 클라이언트 ID — 백엔드의 GOOGLE_CLIENT_ID 와 동일해야 한다.
  /// Flutter google_sign_in 초기화 시 serverClientId 로 사용하면
  /// idToken aud 가 웹 클라이언트 ID 로 발급되어 백엔드 수정 불요.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0.apps.googleusercontent.com',
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'prod',
  );

  static bool get isDev => appEnv == 'dev';
  static bool get isProd => appEnv == 'prod';
}
