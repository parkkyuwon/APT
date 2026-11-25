# APT EV Charging 개발 안내

현재 앱은 인증, 게스트 조회, 주차 등록·해제, 회원·관리자 화면과 API 계층을 갖추고 있습니다. 초기 단계별 체크리스트 대신 실제 코드와 아래 절차를 기준으로 수정하세요. 기능 구현과 서버·실기기 검증은 별도로 확인해야 합니다.

## 작업 시작

1. `git status --short`로 기존 변경을 확인하고 보존합니다.
2. [프로젝트 분석](docs/architecture/PROJECT_ANALYSIS.md), [Mermaid 구조도](docs/architecture/project-diagram.mmd), [JSON 색인](docs/architecture/project-diagram.index.json)에서 변경 대상과 직접 연결된 구성요소를 찾습니다.
3. 실제 소스, 모델 변환 함수와 서비스의 요청·응답 계약을 읽습니다. 서버 구현은 이 저장소에 없습니다.
4. 실행 가능한 Flutter SDK 경로와 대상 API 서버를 확인합니다. CI 기준 Flutter는 `3.41.6`입니다.

```powershell
git status --short
Get-Command flutter
flutter --version
flutter doctor -v
flutter pub get
```

Flutter가 PATH에 없으면 설치된 SDK의 `bin/flutter.bat` 경로를 확인해 사용하세요. 기존 빌드 결과물이나 `.dart_tool`의 경로는 현재 SDK가 실행된다는 근거가 아닙니다. SDK 설치·복구 스크립트는 기존 설치를 제거하는지 먼저 확인합니다.

Android SDK 라이선스가 미수락 상태면 `flutter doctor -v`로 필요한 패키지를 확인한 뒤 `flutter doctor --android-licenses`를 대화형으로 실행해 검토·수락하세요. 라이선스가 남아 있으면 Android toolchain 빌드 검증은 완료되지 않은 상태입니다.

## 구현 기준

| 영역 | 수정할 때 확인할 코드와 계약 |
| --- | --- |
| 앱 시작·인증 | `lib/main.dart`, `AuthProvider`, `AuthApi`, `SessionInfo`, 온보딩 화면. `AuthStage`에 따라 루트가 바뀜 |
| 주차·입출차 | `AppStateProvider`, `StateApi`, `AppState`, `ParkingSlot`, 슬롯 위젯. 성공 응답은 서버 상태를 사용하고 낙관적 변경의 실패 롤백을 보존 |
| 게스트 | `GuestShellScreen`, `startGuest()`, `PublicDashboardApi`. `/api/public-dashboard` 흐름과 회원 상태·캐시를 구분 |
| API | `lib/core/api_client.dart`와 `lib/services/`. 공용 Dio의 쿠키, ETag, 오류 변환을 재사용 |
| 지도·BLE | 지도 편집 화면, `lib/core/bluetooth_permissions.dart`, `console_beacon_scan.dart`, 비콘 목록·위치 편집 화면, `AppStateProvider`, Android `MainActivity.kt` |
| QR·링크 | `lib/core/qr_payload.dart`, `deep_link.dart`, 회원 홈, Android manifest와 iOS SceneDelegate. 콜드·웜 링크 진입 처리가 구현됨 |
| 공통 화면 | `lib/theme.dart`, `lib/widgets/`, 기존 모델 변환과 assets를 우선 재사용 |

공용 HTTP 계층은 15초 타임아웃과 특정 GET 응답의 ETag/304 복원을 제공합니다. 일시적인 GET 네트워크 오류는 최대 2회 재시도하며, 변경 요청은 자동 재시도하지 않습니다. 새 API도 기존 서비스 구성과 `ApiServices.from()`을 따르고 서버가 제공하는 계약을 먼저 확인하세요.

로그인은 Google ID 토큰을 서버에 전달한 뒤 쿠키 세션을 사용합니다. 새 토큰 갱신 방식이나 서버 엔드포인트를 모바일 변경만으로 추가했다고 가정하지 않습니다. 로그아웃·계정 변경·게스트 전환에서는 진행 중 요청, 폴링, 회원 캐시와 화면 수명을 함께 검토합니다.

구조·의존성·주요 데이터 흐름을 바꾸면 Mermaid와 JSON 색인을 함께 갱신합니다. 다른 언어용 프로젝트 구조를 Flutter에 적용하지 않습니다.

## 환경 설정

`API_BASE_URL`, `GOOGLE_CLIENT_ID`, `APP_ENV`는 `--dart-define`으로 주입합니다. `Env`의 기본값은 운영 서버이므로 개발 실행에 사용할 테스트 서버와 웹 클라이언트 ID를 확인하세요.

```powershell
flutter run --dart-define=API_BASE_URL=https://test-api.example.invalid --dart-define=GOOGLE_CLIENT_ID=TEST_WEB_CLIENT_ID --dart-define=APP_ENV=dev
```

주소와 ID는 자리표시자이며 실제 테스트 환경 값으로 교체해야 합니다. `APP_ENV`는 환경 구분 값으로, 서버 주소를 자동 전환하지 않습니다. QR 기본 URL과 플랫폼 링크 설정도 따로 확인하세요. iOS Universal Links 운영에는 Associated Domains capability와 서버의 apple-app-site-association 파일 배포가 별도로 필요합니다. 비밀 키·비밀번호는 빌드 값, 문서, 로그에 넣지 않습니다.

## 검증 절차

모든 변경은 정적 분석과 변경 범위에 맞는 테스트를 실행합니다. 테스트를 추가하거나 의존성을 바꾸면 전체 테스트도 확인합니다.

```powershell
flutter analyze --no-fatal-infos
flutter test
```

| 변경 범위 | 기존 테스트 |
| --- | --- |
| 모델 변환 | `test/app_state_test.dart` |
| 주차 목록 필터 | `test/slot_filter_test.dart` |
| 충전 시간 | `test/duration_presets_test.dart` |
| HTTP 오류·캐시 | `test/errors_test.dart`, `test/etag_cache_test.dart` |
| 인증·게스트·주차 모드 | `test/auth_provider_guest_test.dart`, `test/app_state_provider_guest_test.dart`, `test/guest_shell_screen_test.dart` |
| 세션·화면 수명 | `test/session_lifecycle_test.dart`, `test/secure_session_storage_test.dart`, `test/auth_navigation_test.dart` |
| 딥링크·자동 주차 등록 | `test/deep_link_test.dart`, `test/home_deep_link_test.dart` |
| 비콘 helper·권한 정책 | `test/console_beacon_scan_helpers_test.dart`, `test/bluetooth_permissions_test.dart` |

예를 들어 필터 변경은 `flutter test test/slot_filter_test.dart`로 확인합니다. 실제 서버 응답·권한·저장 실패와 롤백은 테스트 서버에서 추가 확인하세요. 단위 테스트만으로 Google 로그인, 사진 선택, BLE 스캔, QR/딥링크와 Android·iOS 권한 동작을 보증할 수 없습니다.

실기기에서는 해당 변경에 따라 다음을 확인합니다.

- 로그인·로그아웃, 승인 단계와 계정 변경 시 이전 회원 정보 정리
- 게스트에서 회원 전환, 네트워크 지연·실패 중 화면 전환과 재시도
- 입출차 저장 성공·실패, 지도·비콘 좌표 저장 후 재조회
- Bluetooth 권한 허용·거부와 실제 스캔, 플랫폼별 설정
- 앱 종료 상태·실행 중 링크 진입, 점유·차단·중복 주차 등록
- 수정 화면의 작은 화면·큰 글자·키보드·사진 선택 흐름

SDK·서버·기기를 사용할 수 없으면 실행하지 못한 명령, 이유와 미검증 범위를 결과에 명시합니다.

## 빌드와 배포 구분

검증용 Android 빌드는 확인된 테스트 환경 값으로 `flutter build apk --debug`를 실행합니다. iOS는 macOS에서 `flutter build ios --no-codesign`을 사용합니다. 두 명령에도 실행 예시와 같은 dart-define을 전달하세요.

CI는 정적 분석과 테스트, Android debug APK, 서명 없는 iOS 빌드로 구성되어 있습니다. CI 빌드의 기본 대상은 운영 API이며 CI 구성 존재만으로 최근 빌드 통과나 실기기 정상 동작을 의미하지 않습니다.

앱 게시·버전 변경·서명 작업은 검증과 구분합니다. 배포 스크립트를 테스트 대신 실행하지 말고, 배포 요청이 있을 때 대상 채널·환경·버전·서명 설정을 확인하세요. 자격증명 파일은 내용과 키를 문서·로그에 복사하지 않습니다.
