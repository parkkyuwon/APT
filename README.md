# APT EV Charging Mobile App

아파트 주차·EV 충전 현황을 관리하는 Flutter/Dart Android·iOS 앱입니다. 회원은 입출차 정보와 충전 시간을 등록하고, 관리자는 회원 승인과 주차면·운영 정보를 관리합니다. 백엔드 구현은 이 저장소에 없으며, 모바일 앱은 별도 서버의 API를 사용합니다.

## 구현된 기능

| 사용자 | 기능 |
| --- | --- |
| 게스트 | 로그인 없이 공개 주차 현황, 목록, 지도, 이용 안내 조회 |
| 회원 | Google 로그인, 가입 단계 안내, 주차 등록·해제, 충전 시간 입력, 대화방, 프로필·차량 사진·입출차 이력 |
| 관리자 | 회원 승인·차단, 차량 사진 인증, 공지·운영 설정, 주차 정보 수정, QR 생성, 입출차·활동 이력 조회, 지도 좌표 편집, BLE 비콘 스캔·위치 관리 |

QR URL의 슬롯 정보는 앱 시작 시 또는 실행 중 딥링크로 받아 회원 홈에서 처리합니다. 앱 내부 카메라 QR 스캐너는 구현되어 있지 않습니다. iOS Universal Links를 운영하려면 Associated Domains 및 서버의 apple-app-site-association 설정도 필요합니다. BLE 위치 추정은 Android 버전에 맞춰 Bluetooth와 위치 권한을 요청합니다. BLE, Google 로그인, 링크 진입과 플랫폼 권한은 Android·iOS 실기기에서 확인해야 합니다.

## 기술과 구조

- 상태 관리: Provider와 ChangeNotifier
- 화면 전환: `AuthStage`에 따른 루트 화면 선택과 Navigator/MaterialPageRoute
- HTTP: 공용 Dio, 쿠키 세션, 특정 GET 경로의 ETag 캐시, 네트워크 오류 시 GET 재시도
- 저장소: flutter_secure_storage의 쿠키·세션 캐시, SharedPreferences의 회원 주차 상태 캐시
- 외부 기능: google_sign_in, image_picker, qr_flutter, flutter_blue_plus, permission_handler

```text
lib/
  main.dart       앱 초기화와 Provider 등록
  config/         dart-define 환경과 저장소 설정
  core/           HTTP, 오류, 캐시, 세션, QR와 딥링크
  data/           기본 슬롯 정의
  models/         서버 데이터 모델과 변환
  services/       기능별 API 서비스와 ApiServices
  providers/      인증, 주차 상태, 연결 상태
  screens/        로그인, 온보딩, 회원·게스트, 관리자 화면
  widgets/        슬롯 타일과 상세 다이얼로그
  theme.dart      공통 테마
test/             모델, Provider, 필터, 캐시, 위젯 테스트
```

수정 위치와 데이터 흐름은 [프로젝트 분석](docs/architecture/PROJECT_ANALYSIS.md), [구조도](docs/architecture/project-diagram.mmd), [파일 색인](docs/architecture/project-diagram.index.json)을 먼저 확인하세요. 개발 절차는 [DEVELOPMENT.md](DEVELOPMENT.md)에 정리되어 있습니다.

## 개발 환경과 실행

Android 대상 SDK는 API 36이며 현재 버전은 `1.1.0+15`입니다. Google Play API 갱신 대응과 새 AAB의 테스트·게시 절차는 [API36 릴리스 안내](docs/ANDROID_API36_RELEASE.md)를 참고하세요.

CI는 Flutter `3.41.6`을 지정하고, `pubspec.yaml`의 Dart SDK 제약은 `^3.0.0`입니다. 의존성의 SDK 요구사항도 적용되므로 CI와 같은 Flutter 버전을 기준으로 준비하세요. Android에는 Android SDK와 JDK 17, iOS에는 macOS와 Xcode가 필요합니다. Android 빌드 도구를 처음 준비했다면 `flutter doctor -v`에서 Android toolchain 상태를 확인하고 필요한 SDK 라이선스를 대화형으로 검토·수락하세요. 라이선스가 남아 있으면 Android 빌드 검증을 완료할 수 없습니다.

저장소 루트에서 실행합니다.

```powershell
flutter --version
flutter doctor -v
flutter pub get
flutter devices
```

환경은 `lib/config/env.dart`에서 `--dart-define`으로 읽습니다.

| 이름 | 용도 |
| --- | --- |
| `API_BASE_URL` | 대상 백엔드의 기본 URL |
| `GOOGLE_CLIENT_ID` | Google 로그인 `serverClientId`로 전달할 웹 클라이언트 ID. 대상 서버의 설정과 일치해야 함 |
| `APP_ENV` | 환경 구분. 개발은 `dev`, 운영은 `prod` |

기본값은 운영 서버와 `APP_ENV=prod`입니다. 개발·수동 검증 전 테스트 서버를 확인하고 다음 예시의 주소와 클라이언트 ID를 해당 환경 값으로 바꾸세요. `APP_ENV=dev`만 지정해도 서버 주소가 바뀌지는 않습니다.

```powershell
flutter run --dart-define=API_BASE_URL=https://test-api.example.invalid --dart-define=GOOGLE_CLIENT_ID=TEST_WEB_CLIENT_ID --dart-define=APP_ENV=dev
```

위 주소와 ID는 실행 가능한 서버 설정이 아닌 자리표시자입니다. `--dart-define` 값은 앱 빌드에 포함되므로 비밀 키나 관리자 비밀번호를 넣지 마세요. QR URL의 기본 주소와 Android 딥링크 호스트는 별도 설정이며 API 주소 변경만으로 함께 변경되지 않습니다.

Google 로그인 설정은 `lib/providers/auth_provider.dart`, Android 앱 식별자·서명 설정, iOS URL scheme과 `Info.plist`를 함께 확인하세요. 모바일 설정 변경만으로 서버의 인증 계약이 변경되지는 않습니다.

## 검증

```powershell
flutter analyze --no-fatal-infos
flutter test
flutter test test/slot_filter_test.dart
```

마지막 명령은 실제 존재하는 특정 테스트의 실행 예시입니다. 변경 기능에 맞는 테스트와 서버·기기 검증 범위는 [개발 안내](DEVELOPMENT.md#검증-절차)를 참고하세요.

Android 빌드 검증에는 확인된 테스트 환경을 주입합니다.

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://test-api.example.invalid --dart-define=GOOGLE_CLIENT_ID=TEST_WEB_CLIENT_ID --dart-define=APP_ENV=dev
```

iOS 빌드는 macOS에서 같은 환경 값을 지정해 `flutter build ios --no-codesign`으로 확인할 수 있습니다. 설치·배포용 빌드에는 별도 서명과 프로비저닝 설정이 필요합니다.

`.github/workflows/flutter-ci.yml`은 분석·테스트 후 Android debug APK와 서명 없는 iOS 빌드를 수행하도록 구성되어 있습니다. CI 빌드의 API 환경은 운영으로 설정되어 있으므로 생성된 앱을 실행하기 전에 대상 서버를 확인하세요. 게시·버전 변경을 수행할 수 있는 배포 스크립트는 일반 검증 명령으로 실행하지 않습니다.
